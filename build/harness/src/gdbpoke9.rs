//! gdbpoke9.rs — poke guest memory through qemu's gdbstub with a raw RSP
//! (gdb remote serial protocol) client (port of gdbpoke9.py).
//!
//! Written for the boot harness: qemu 11.1.2's GICv3 model resets
//! GICR_WAKER.ProcessorSleep=1 (spec-accurate) and the pinned 9front donor's
//! gic.c never clears it. With the redistributor asleep, PPI interrupts (the
//! CNTV timer, INTID 27) never fire: no ticks, so devuart's uartclock()
//! never flushes staged console input and the boot parks forever at the
//! bootargs prompt. The poke writes 0 to GICR0 WAKER through the guest's own
//! kernel VA mapping (VIRTIO=0xFFFFFFFFB0000000 + 0xA0000 GICR + 0x14).
//!
//! usage: harness gdbpoke9 --sock PATH --watch-file LOG [--watch-str STR]
//!        [--addr HEX] [--value HEX] [--bytes N] [--deadline SECS]
//! exits 0 once the write lands, 1 on timeout/error, 2 on bad args.

use std::io::Write;

pub const DEFAULT_ADDR: u64 = 0xFFFFFFFF_B00A_0014; // VIRTIO + GICR0 + WAKER
pub const DEFAULT_WATCH: &str = "bootargs is";

/// RED-phase stub: parses args (the exit-2 surface is real), then reports
/// success without doing anything — the GREEN commit implements the RSP
/// client and the watch-file gating.
pub fn run(args: &[String]) -> i32 {
    let mut err = std::io::stderr();
    run_io(args, &mut err)
}

pub fn run_io(args: &[String], err: &mut dyn Write) -> i32 {
    let mut sock: Option<String> = None;
    let mut watch_file: Option<String> = None;
    let mut i = 0;
    while i < args.len() {
        let a = args[i].as_str();
        match a {
            "--sock" | "--addr" | "--value" | "--bytes" | "--watch-file" | "--watch-str"
            | "--deadline" => {
                if a == "--sock" {
                    sock = args.get(i + 1).cloned();
                }
                if a == "--watch-file" {
                    watch_file = args.get(i + 1).cloned();
                }
                i += 2;
            }
            _ => {
                let _ = writeln!(err, "gdbpoke9: unknown arg {}", a);
                return 2;
            }
        }
    }
    if sock.is_none() || watch_file.is_none() {
        let _ = writeln!(err, "gdbpoke9: --sock and --watch-file are required");
        return 2;
    }
    0 // RED stub: claims success without poking
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::io::{Read, Write};
    use std::os::unix::net::UnixListener;
    use std::sync::{Arc, Mutex};
    use std::thread;
    use std::time::Duration;

    struct TmpPath(std::path::PathBuf);
    impl TmpPath {
        fn new(tag: &str) -> TmpPath {
            let mut p = std::env::temp_dir();
            p.push(format!(
                "gdbpoke9test.{}.{}.{}",
                std::process::id(),
                tag,
                std::time::SystemTime::now()
                    .duration_since(std::time::UNIX_EPOCH)
                    .unwrap()
                    .as_nanos()
            ));
            TmpPath(p)
        }
    }
    impl Drop for TmpPath {
        fn drop(&mut self) {
            let _ = std::fs::remove_file(&self.0);
        }
    }

    fn checksum(data: &[u8]) -> String {
        format!("{:02x}", data.iter().map(|b| *b as u32).sum::<u32>() & 0xFF)
    }
    fn pkt(data: &[u8]) -> Vec<u8> {
        let mut out = vec![b'$'];
        out.extend_from_slice(data);
        out.push(b'#');
        out.extend_from_slice(checksum(data).as_bytes());
        out
    }

    /// Mock RSP peer: per connection, read '$..#cs' packets (verifying the
    /// checksum), ACK with '+', and answer '?' with the configured state
    /// reply, 'M...' with OK (recording the payload), 'D' recorded silently.
    struct Peer {
        received: Arc<Mutex<Vec<String>>>,
    }

    fn spawn_peer(path: &std::path::Path, drop_first: bool, state_reply: &str) -> Peer {
        let listener = UnixListener::bind(path).unwrap();
        let received: Arc<Mutex<Vec<String>>> = Arc::new(Mutex::new(Vec::new()));
        let rec = received.clone();
        let state_reply = state_reply.to_string();
        thread::spawn(move || {
            let mut first = true;
            for conn in listener.incoming() {
                let Ok(mut c) = conn else { continue };
                if drop_first && first {
                    first = false;
                    drop(c); // force the client to retry the whole connect
                    continue;
                }
                first = false;
                let rec = rec.clone();
                let state_reply = state_reply.clone();
                thread::spawn(move || loop {
                    // read one packet: '+' keepalives skipped, '$'.. '#'+2cs
                    let mut ch = [0u8; 1];
                    match c.read_exact(&mut ch) {
                        Ok(()) => {}
                        Err(_) => return,
                    }
                    if ch[0] == b'+' {
                        continue;
                    }
                    if ch[0] != b'$' {
                        return;
                    }
                    let mut payload = Vec::new();
                    loop {
                        match c.read_exact(&mut ch) {
                            Ok(()) => {}
                            Err(_) => return,
                        }
                        if ch[0] == b'#' {
                            break;
                        }
                        payload.push(ch[0]);
                    }
                    let mut cs = [0u8; 2];
                    if c.read_exact(&mut cs).is_err() {
                        return;
                    }
                    // verify the client-side checksum discipline
                    assert_eq!(
                        std::str::from_utf8(&cs).unwrap(),
                        checksum(&payload),
                        "client checksum"
                    );
                    if c.write_all(b"+").is_err() {
                        return;
                    }
                    let text = String::from_utf8_lossy(&payload).into_owned();
                    match payload.first() {
                        Some(b'?') => {
                            rec.lock().unwrap().push(text);
                            if c.write_all(&pkt(state_reply.as_bytes())).is_err() {
                                return;
                            }
                        }
                        Some(b'M') => {
                            rec.lock().unwrap().push(text);
                            if c.write_all(&pkt(b"OK")).is_err() {
                                return;
                            }
                        }
                        Some(b'D') => {
                            rec.lock().unwrap().push(text);
                            // detach: the client does not wait for a reply
                        }
                        _ => {
                            rec.lock().unwrap().push(text);
                        }
                    }
                });
            }
        });
        Peer { received }
    }

    fn args(sock: &TmpPath, wf: &TmpPath, extra: &[&str]) -> Vec<String> {
        let mut v = vec![
            "--sock".to_string(),
            sock.0.to_string_lossy().into_owned(),
            "--watch-file".to_string(),
            wf.0.to_string_lossy().into_owned(),
        ];
        v.extend(extra.iter().map(|s| s.to_string()));
        v
    }

    #[test]
    fn happy_path_pokes_and_detaches() {
        let sock = TmpPath::new("s1");
        let wf = TmpPath::new("w1");
        std::fs::write(&wf.0, b"noise... bootargs is (tcp) ...\n").unwrap();
        let peer = spawn_peer(&sock.0, false, "T05");
        let mut err = Vec::new();
        let rc = run_io(&args(&sock, &wf, &["--deadline", "30"]), &mut err);
        assert_eq!(rc, 0);
        let err = String::from_utf8(err).unwrap();
        assert!(
            err.contains("gdbpoke9: poked 0xffffffffb00a0014=0x0 after 1 attempt(s) (watch 'bootargs is' seen)"),
            "stderr was: {}",
            err
        );
        let got = peer.received.lock().unwrap().clone();
        assert_eq!(got, vec!["?", "Mffffffffb00a0014,4:00000000", "D"]);
    }

    #[test]
    fn retries_the_whole_connect_after_a_dropped_conn() {
        let sock = TmpPath::new("s2");
        let wf = TmpPath::new("w2");
        std::fs::write(&wf.0, b"bootargs is here\n").unwrap();
        let peer = spawn_peer(&sock.0, true, "S05");
        let mut err = Vec::new();
        let rc = run_io(&args(&sock, &wf, &["--deadline", "30"]), &mut err);
        assert_eq!(rc, 0);
        let err = String::from_utf8(err).unwrap();
        assert!(err.contains("attempt 1:"), "stderr was: {}", err);
        assert!(err.contains("after 2 attempt(s)"), "stderr was: {}", err);
        // the second connection carried the full sequence
        let got = peer.received.lock().unwrap().clone();
        assert_eq!(got, vec!["?", "Mffffffffb00a0014,4:00000000", "D"]);
    }

    #[test]
    fn custom_addr_value_bytes() {
        let sock = TmpPath::new("s3");
        let wf = TmpPath::new("w3");
        std::fs::write(&wf.0, b"bootargs is\n").unwrap();
        let peer = spawn_peer(&sock.0, false, "T05");
        let mut err = Vec::new();
        let rc = run_io(
            &args(
                &sock,
                &wf,
                &[
                    "--addr", "40000000", "--value", "deadbeef", "--bytes", "2", "--deadline", "30",
                ],
            ),
            &mut err,
        );
        assert_eq!(rc, 0);
        // 2 bytes LE of 0xdeadbeef = ef be → hex 'efbe'
        let got = peer.received.lock().unwrap().clone();
        assert_eq!(got, vec!["?", "M40000000,2:efbe", "D"]);
        let err = String::from_utf8(err).unwrap();
        assert!(err.contains("poked 0x40000000=0xdeadbeef"), "stderr: {}", err);
    }

    #[test]
    fn watch_string_never_appears_exits_1() {
        let sock = TmpPath::new("s4");
        let wf = TmpPath::new("w4");
        std::fs::write(&wf.0, b"nothing useful\n").unwrap();
        let mut err = Vec::new();
        let rc = run_io(&args(&sock, &wf, &["--deadline", "1"]), &mut err);
        assert_eq!(rc, 1);
        let err = String::from_utf8(err).unwrap();
        assert!(
            err.contains("gdbpoke9: watch string 'bootargs is' never appeared"),
            "stderr: {}",
            err
        );
    }

    #[test]
    fn bad_state_reply_retries_until_deadline() {
        let sock = TmpPath::new("s5");
        let wf = TmpPath::new("w5");
        std::fs::write(&wf.0, b"bootargs is\n").unwrap();
        let _peer = spawn_peer(&sock.0, false, "E01"); // not T../S..
        let mut err = Vec::new();
        let rc = run_io(&args(&sock, &wf, &["--deadline", "2"]), &mut err);
        assert_eq!(rc, 1);
        let err = String::from_utf8(err).unwrap();
        assert!(err.contains("state query got b'E01'"), "stderr: {}", err);
        assert!(err.contains("poke never landed within deadline"), "stderr: {}", err);
    }

    #[test]
    fn usage_errors_exit_2() {
        let mut err = Vec::new();
        assert_eq!(run_io(&["--bogus".to_string(), "x".to_string()], &mut err), 2);
        let mut err = Vec::new();
        assert_eq!(run_io(&["--sock".to_string(), "/x".to_string()], &mut err), 2);
        let e = String::from_utf8(err).unwrap();
        assert!(e.contains("--sock and --watch-file are required"));
    }

    #[test]
    fn watch_str_override() {
        let sock = TmpPath::new("s6");
        let wf = TmpPath::new("w6");
        let peer = spawn_peer(&sock.0, false, "T05");
        // the watch string arrives LATE — the poll must gate the connect
        let wfp = wf.0.clone();
        thread::spawn(move || {
            thread::sleep(Duration::from_millis(700));
            std::fs::write(&wfp, b"now the custom-marker appears\n").unwrap();
        });
        let mut err = Vec::new();
        let rc = run_io(
            &args(&sock, &wf, &["--watch-str", "custom-marker", "--deadline", "30"]),
            &mut err,
        );
        assert_eq!(rc, 0);
        let err = String::from_utf8(err).unwrap();
        assert!(err.contains("(watch 'custom-marker' seen)"), "stderr: {}", err);
        let got = peer.received.lock().unwrap().clone();
        assert_eq!(got.len(), 3);
    }
}
