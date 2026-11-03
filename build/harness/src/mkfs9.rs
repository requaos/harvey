//! mkfs9.rs — host-side replacement for the donor's disk/mkfs (port of
//! mkfs9.py), installed as disk/mkfs in the guest scratch bin by
//! donor-ns-build.sh (via the D-05 harness-pkg wrapper after this quick
//! task).
//!
//! Implements the exact semantics the CONF=qemu boot needs from the pinned
//! protos (bootfs.proto + disk.proto + devusb.proto):
//!   disk/mkfs -aos / PROTOS   → print the source path of every non-dir
//!                               entry (mk's prerequisite list), stdout only
//!   disk/mkfs -s / -d DIR PROTOS → materialize the tree at DIR
//! Proto grammar (donor libdisk/proto.c + cmd/disk/mkfs.c):
//!   indent (tab=8, space=1) tree; fields: name [mode owner group source]
//!   `+` as a name → recursively copy the current source dir's contents
//!   `$objtype` → environment expansion; `#` comment; blank skipped
//!   missing source → warn to stderr, skip the entry's subtree
//! Modes: explicit proto mode wins; otherwise the source's mode is
//! preserved. IN-08: a bare `d` mode (strips to empty) falls back to copying
//! the source mode instead of crashing.

use std::io::Write;

pub const USAGE: &str = "usage: mkfs9 [-a] [-s oldroot] [-d dest] proto ...\n";

/// Plan 9 cleanname(1): lexical . and .. resolution.
pub fn cleanname(p: &str) -> String {
    let mut out: Vec<&str> = Vec::new();
    for part in p.split('/') {
        match part {
            "" | "." => continue,
            ".." => {
                out.pop();
            }
            _ => out.push(part),
        }
    }
    let mut r = String::new();
    if p.starts_with('/') {
        r.push('/');
    }
    r.push_str(&out.join("/"));
    r
}

pub fn run(args: &[String]) -> i32 {
    let mut out = std::io::stdout();
    let mut err = std::io::stderr();
    run_io(args, &mut out, &mut err)
}

/// RED-phase stub: the arg/usage/exit-2 surface is real; the walk is not.
pub fn run_io(args: &[String], out: &mut dyn Write, err: &mut dyn Write) -> i32 {
    let mut listonly = false;
    let mut oldroot = "/".to_string();
    let mut dest: Option<String> = None;
    let mut protos: Vec<String> = Vec::new();
    let _ = (&mut oldroot, &mut dest, out); // silence unused in the stub
    let mut i = 0;
    while i < args.len() {
        let a = &args[i];
        let bytes = a.as_bytes();
        if bytes.len() > 1 && bytes[0] == b'-' {
            for &c in &bytes[1..] {
                match c {
                    b'a' => listonly = true,
                    b'o' | b'x' | b'p' | b'v' | b'D' | b'r' | b'U' => {}
                    b's' | b'd' => {
                        i += 1;
                        match args.get(i) {
                            Some(v) => {
                                if c == b's' {
                                    oldroot = v.clone();
                                } else {
                                    dest = Some(v.clone());
                                }
                            }
                            None => {
                                let _ = writeln!(err, "mkfs9: flag -{} requires a value", c as char);
                                return 2;
                            }
                        }
                    }
                    _ => {
                        let _ = writeln!(err, "mkfs9: unsupported flag -{}", c as char);
                        return 2;
                    }
                }
            }
        } else {
            protos.push(a.clone());
        }
        i += 1;
    }
    if protos.is_empty() {
        let _ = write!(err, "{}", USAGE);
        return 2;
    }
    if !listonly && dest.is_none() {
        let _ = writeln!(err, "mkfs9: -d required in materialize mode");
        return 2;
    }
    let _ = listonly;
    0 // RED stub: claims success without walking
}
