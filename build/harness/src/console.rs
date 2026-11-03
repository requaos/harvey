//! console.rs — shared serial-console machinery for drive9 and
//! trace-syscalls: the bounded Log (ring window + file capture), the reader
//! thread, the QMP "cont" handshake, the bootargs/auth/shell/prompt boot
//! drive, paced sends, and echo-verified command delivery.
//!
//! Capture-before-start discipline (Phase 1 build/mm/boot-9k10cpu.sh, ported
//! by drive9.py): the caller launches qemu PAUSED (-S) with serial on a
//! chardev unix socket (server=on,wait=off); the capture attaches BEFORE the
//! guest runs, then QMP resumes.
//!
//! Shell-liveness proof (WR-04): the marker is probed with rc's ^
//! concatenation (`echo __GSD_SHELL_^OK__`) so the echoed command line never
//! contains the contiguous marker; the prompt proof is anchored (^term% $)
//! and order-dependent (searched only after the recorded base).

use std::io::{Read, Write};
use std::os::unix::net::UnixStream;
use std::path::Path;
use std::sync::{Arc, Mutex};
use std::time::{Duration, Instant};

use crate::regex::{Match, Regex};

pub const SHELL_MARKER: &str = "__GSD_SHELL_OK__";
pub const SHELL_PROBE: &[u8] = b"echo __GSD_SHELL_^OK__\r";

// The crate is std-only (D-02) — build the shared patterns at each call site
// (compilation is microseconds) instead of a lazy-static registry.
pub fn panic_re() -> Regex {
    Regex::new_ci("panic|trap:").unwrap()
}
pub fn bootargs_re() -> Regex {
    Regex::new("bootargs is \\(tcp").unwrap()
}
pub fn auth_re() -> Regex {
    Regex::new("auth address is\\?").unwrap()
}
pub fn shell_re() -> Regex {
    Regex::new("^__GSD_SHELL_OK__\r?$").unwrap()
}
pub fn prompt_re() -> Regex {
    Regex::new("^term% $").unwrap()
}
pub fn prompt_set_re() -> Regex {
    Regex::new("^__GSD_PROMPT_SET__\r?$").unwrap()
}

/// Bounded capture: every byte goes to the file unbuffered; the searchable
/// ring trims from `window` down to `trim` bytes (drive9: 512KiB/256KiB;
/// trace-syscalls: 256MiB/128MiB — effectively never, so offset bases stay
/// valid: a base captured before a trim silently points past reality, the
/// 05-03 wedge).
pub struct Log {
    inner: Mutex<Inner>,
    window: usize,
    trim: usize,
}

struct Inner {
    buf: Vec<u8>,
    file: std::fs::File,
}

impl Log {
    pub fn new(path: &Path, window: usize, trim: usize) -> std::io::Result<Arc<Log>> {
        Ok(Arc::new(Log {
            inner: Mutex::new(Inner {
                buf: Vec::new(),
                file: std::fs::File::create(path)?,
            }),
            window,
            trim,
        }))
    }
    pub fn write(&self, data: &[u8]) {
        let mut g = self.inner.lock().unwrap();
        let _ = g.file.write_all(data);
        g.buf.extend_from_slice(data);
        if g.buf.len() > self.window {
            let keep_from = g.buf.len() - self.trim;
            g.buf.drain(..keep_from);
        }
    }
    pub fn tail(&self, n: usize) -> Vec<u8> {
        let g = self.inner.lock().unwrap();
        let start = g.buf.len().saturating_sub(n);
        g.buf[start..].to_vec()
    }
    pub fn search(&self, rx: &Regex) -> bool {
        let g = self.inner.lock().unwrap();
        rx.is_match(&g.buf)
    }
    pub fn search_from(&self, rx: &Regex, base: usize) -> bool {
        let g = self.inner.lock().unwrap();
        if base > g.buf.len() {
            return false;
        }
        rx.is_match_at(&g.buf, base)
    }
    pub fn find_from(&self, rx: &Regex, base: usize) -> Option<Match> {
        let g = self.inner.lock().unwrap();
        if base > g.buf.len() {
            return None;
        }
        rx.find_at(&g.buf, base)
    }
    /// Ring-relative length (matches the .py's len(buf) — bases are
    /// ring-relative by design).
    pub fn len(&self) -> usize {
        self.inner.lock().unwrap().buf.len()
    }
    /// A snapshot of the whole ring (trace.rs harvests the capture this way).
    pub fn snapshot(&self) -> Vec<u8> {
        self.inner.lock().unwrap().buf.clone()
    }
}

/// The reader thread: move bytes from the serial socket into the Log until
/// EOF/error.
pub fn spawn_reader(mut stream: UnixStream, log: Arc<Log>) -> std::thread::JoinHandle<()> {
    std::thread::spawn(move || {
        let mut b = [0u8; 4096];
        loop {
            match stream.read(&mut b) {
                Ok(0) => return,
                Ok(n) => log.write(&b[..n]),
                Err(_) => return,
            }
        }
    })
}

/// QMP handshake + cont: greeting → qmp_capabilities → cont.
pub fn qmp_cont(path: &Path) -> std::io::Result<()> {
    let s = UnixStream::connect(path)?;
    s.set_read_timeout(Some(Duration::from_secs(15)))?;
    let mut r = std::io::BufReader::new(s.try_clone()?);
    let mut line = String::new();
    // greeting
    line.clear();
    read_line_crlf(&mut r, &mut line)?;
    {
        let mut w = &s;
        w.write_all(b"{\"execute\":\"qmp_capabilities\"}\r\n")?;
        w.flush()?;
    }
    line.clear();
    read_line_crlf(&mut r, &mut line)?;
    {
        let mut w = &s;
        w.write_all(b"{\"execute\":\"cont\"}\r\n")?;
        w.flush()?;
    }
    std::thread::sleep(Duration::from_millis(200));
    Ok(())
}

fn read_line_crlf(r: &mut std::io::BufReader<UnixStream>, out: &mut String) -> std::io::Result<()> {
    let mut b = [0u8; 1];
    loop {
        match r.read(&mut b) {
            Ok(0) => return Ok(()),
            Ok(_) => {
                out.push(b[0] as char);
                if b[0] == b'\n' {
                    return Ok(());
                }
            }
            Err(e) => return Err(e),
        }
    }
}

/// Human-typing-speed send: one byte per 50ms (the guest console input path
/// drops burst-leading bytes while kbdfs's cooked-mode discipline is busy).
pub fn paced_send(s: &UnixStream, cmd: &[u8]) {
    for &b in cmd {
        let _ = (&*s).write_all(&[b]);
        std::thread::sleep(Duration::from_millis(50));
    }
}

/// fail: print the message + the log tail to stderr; the caller returns 1.
pub fn fail(log: &Log, who: &str, msg: &str, err: &mut dyn Write) {
    let _ = writeln!(err, "{}: {}", who, msg);
    let _ = writeln!(err, "{}: last log lines:", who);
    let tail = log.tail(2048);
    let _ = writeln!(err, "{}", String::from_utf8_lossy(&tail));
}

/// Which prompt-proof variant to drive after the shell marker: drive9.py and
/// the gatedrive9/subsetdrive9 heredocs send `echo __GSD_PROMPT_SET__` and
/// wait for its output line first; trace-syscalls.py sends a paced
/// `echo __GSD_SHELL_^OK__` and waits only for the anchored prompt.
pub enum PromptProbe {
    Marker,
    ShellOk,
}

/// The shared boot drive: answer the bootargs prompt (CR), the confignet
/// auth prompt (CR, once), probe for the interactive rc shell, set the
/// documented term% prompt and prove it was evaluated (anchored,
/// order-dependent). Panic/trap fast-fail throughout.
pub fn drive_boot(
    s: &UnixStream,
    log: &Log,
    deadline: Instant,
    budget_secs: u64,
    who: &str,
    probe: PromptProbe,
    err: &mut dyn Write,
) -> Result<(), ()> {
    let panic_re = panic_re();
    let bootargs_re = bootargs_re();
    let auth_re = auth_re();
    let shell_re = shell_re();
    let prompt_re = prompt_re();

    // answer the bootargs prompt
    loop {
        if Instant::now() >= deadline {
            fail(log, who, "no bootargs prompt within budget", err);
            return Err(());
        }
        if panic_re.is_match(&log.tail(8192)) {
            fail(log, who, "kernel panic/trap during early boot", err);
            return Err(());
        }
        if log.search(&bootargs_re) {
            break;
        }
        std::thread::sleep(Duration::from_secs(1));
    }
    let _ = writeln!(err, "{}: bootargs prompt seen; answering default (tcp)", who);
    let _ = (&*s).write_all(b"\r");

    // wait for the interactive shell via echo probes; answer the confignet
    // auth prompt if it appears (net.rc `ask auth`)
    let mut answered_auth = false;
    let mut nextprobe = Instant::now() + Duration::from_secs(10);
    loop {
        if Instant::now() >= deadline {
            fail(
                log,
                who,
                &format!("no interactive rc shell within {}s budget", budget_secs),
                err,
            );
            return Err(());
        }
        if panic_re.is_match(&log.tail(8192)) {
            fail(log, who, "kernel panic/trap during boot", err);
            return Err(());
        }
        if !answered_auth && log.search(&auth_re) {
            let _ = writeln!(err, "{}: auth-address prompt seen; answering default", who);
            let _ = (&*s).write_all(b"\r");
            answered_auth = true;
            continue;
        }
        if log.search(&shell_re) {
            break;
        }
        if Instant::now() >= nextprobe {
            if (&*s).write_all(SHELL_PROBE).is_err() {
                fail(log, who, "serial socket closed during boot", err);
                return Err(());
            }
            nextprobe = Instant::now() + Duration::from_secs(5);
        }
        std::thread::sleep(Duration::from_secs(1));
    }
    let _ = writeln!(err, "{}: rc shell reached (marker executed)", who);

    // set the documented prompt signature and prove it was evaluated.
    // Order-dependent: wait for the probe's OUTPUT line first (rc provably
    // executing), then accept the anchored bare prompt only in the buffer
    // region after the base recorded here.
    let base = log.len();
    let _ = (&*s).write_all(b"prompt='term% '\r");
    std::thread::sleep(Duration::from_secs(1));
    let pdeadline = Instant::now() + Duration::from_secs(60);
    match probe {
        PromptProbe::Marker => {
            let _ = (&*s).write_all(b"echo __GSD_PROMPT_SET__\r");
            let prompt_set_re = prompt_set_re();
            loop {
                if Instant::now() >= pdeadline {
                    fail(log, who, "shell did not execute the prompt probe", err);
                    return Err(());
                }
                if panic_re.is_match(&log.tail(8192)) {
                    fail(log, who, "kernel fault at the shell", err);
                    return Err(());
                }
                if log.search_from(&prompt_set_re, base) {
                    break;
                }
                std::thread::sleep(Duration::from_millis(500));
            }
        }
        PromptProbe::ShellOk => {
            paced_send(s, SHELL_PROBE);
        }
    }
    loop {
        if Instant::now() >= pdeadline {
            fail(log, who, "shell did not emit the term% prompt after assignment", err);
            return Err(());
        }
        if panic_re.is_match(&log.tail(8192)) {
            fail(log, who, "kernel fault at the shell", err);
            return Err(());
        }
        if log.search_from(&prompt_re, base) {
            break;
        }
        std::thread::sleep(Duration::from_millis(500));
    }
    let _ = writeln!(err, "{}: rc printed the term% prompt — shell is live", who);
    Ok(())
}

/// Echo-verified delivery (gatedrive9/subsetdrive9 discipline): paced send,
/// then wait for the console ECHO (kbdfs echoes exactly the runes its line
/// discipline received) — a mangled or missing echo is harness noise →
/// retry (3 attempts). A clean echo without the expected output is a
/// GENUINE failure → no retry. Panic fast-fail throughout.
pub fn send_verified(
    s: &UnixStream,
    log: &Log,
    cmd: &[u8],
    echo_re: &Regex,
    out_re: &Regex,
    out_timeout: Duration,
    base: usize,
    what: &str,
    who: &str,
    err: &mut dyn Write,
) -> bool {
    let panic_re = panic_re();
    for _attempt in 0..3 {
        paced_send(s, cmd);
        let edl = Instant::now() + Duration::from_secs(30);
        let mut got_echo = false;
        loop {
            if Instant::now() >= edl {
                break;
            }
            if panic_re.is_match(&log.tail(8192)) {
                fail(log, who, &format!("kernel fault while sending {}", what), err);
                return false;
            }
            if log.search_from(echo_re, base) {
                got_echo = true;
                break;
            }
            std::thread::sleep(Duration::from_millis(500));
        }
        if !got_echo {
            continue;
        }
        let odl = Instant::now() + out_timeout;
        loop {
            if Instant::now() >= odl {
                break;
            }
            if panic_re.is_match(&log.tail(8192)) {
                fail(log, who, &format!("kernel fault after {}", what), err);
                return false;
            }
            if log.search_from(out_re, base) {
                return true;
            }
            std::thread::sleep(Duration::from_millis(500));
        }
        fail(
            log,
            who,
            &format!("{} delivered but produced no expected output", what),
            err,
        );
        return false;
    }
    fail(
        log,
        who,
        &format!("{} could not be delivered intact after 3 attempts", what),
        err,
    );
    false
}

#[cfg(test)]
mod tests {
    use super::*;

    struct TempDir(std::path::PathBuf);
    impl TempDir {
        fn new(tag: &str) -> TempDir {
            let mut p = std::env::temp_dir();
            p.push(format!(
                "consoletest.{}.{}.{}",
                std::process::id(),
                tag,
                std::time::SystemTime::now()
                    .duration_since(std::time::UNIX_EPOCH)
                    .unwrap()
                    .as_nanos()
            ));
            std::fs::create_dir_all(&p).unwrap();
            TempDir(p)
        }
    }
    impl Drop for TempDir {
        fn drop(&mut self) {
            let _ = std::fs::remove_dir_all(&self.0);
        }
    }

    #[test]
    fn log_writes_to_file_and_searches_ring() {
        let td = TempDir::new("log");
        let path = td.0.join("cap.log");
        let log = Log::new(&path, 512 * 1024, 256 * 1024).unwrap();
        log.write(b"line one\r\n");
        log.write(b"term% echo hi\r\n");
        assert_eq!(log.len(), 25);
        let rx = crate::regex::Regex::new("^term% ").unwrap();
        assert!(log.search(&rx));
        let tail = log.tail(9);
        assert_eq!(tail, b"echo hi\r\n");
        // the file has every byte even before any trim
        assert_eq!(std::fs::read(&path).unwrap(), b"line one\r\nterm% echo hi\r\n");
    }

    #[test]
    fn log_trims_ring_but_not_file() {
        let td = TempDir::new("trim");
        let path = td.0.join("cap.log");
        let log = Log::new(&path, 1024, 512).unwrap(); // tiny window for the test
        log.write(&vec![b'a'; 700]);
        log.write(&vec![b'b'; 700]); // crosses the 1024 window → trim to 512
        assert_eq!(log.len(), 512, "ring trimmed to the trim size");
        let tail = log.tail(4);
        assert_eq!(tail, b"bbbb");
        let rx = crate::regex::Regex::new("aaaa").unwrap();
        assert!(!log.search(&rx), "old bytes fell out of the ring");
        assert_eq!(std::fs::read(&path).unwrap().len(), 1400, "file keeps everything");
    }

    #[test]
    fn log_search_from_and_find_from_respect_base() {
        let td = TempDir::new("base");
        let path = td.0.join("cap.log");
        let log = Log::new(&path, 512 * 1024, 256 * 1024).unwrap();
        log.write(b"term% first\r\njunk\r\nterm% second\r\n");
        let rx = crate::regex::Regex::new("^term% ").unwrap();
        let base = 14; // after the first prompt line
        assert!(log.search_from(&rx, base));
        let m = log.find_from(&rx, base).unwrap();
        assert_eq!(m.span.start, 19);
        assert!(log.find_from(&rx, m.span.end).is_none());
    }
}
