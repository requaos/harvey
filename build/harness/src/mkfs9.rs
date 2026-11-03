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

#[cfg(test)]
mod tests {
    use super::*;
    use std::fs;
    use std::os::unix::fs::PermissionsExt;
    use std::path::PathBuf;

    struct TempDir(PathBuf);
    impl TempDir {
        fn new(tag: &str) -> TempDir {
            let mut p = std::env::temp_dir();
            p.push(format!(
                "mkfs9test.{}.{}.{}",
                std::process::id(),
                tag,
                std::time::SystemTime::now()
                    .duration_since(std::time::UNIX_EPOCH)
                    .unwrap()
                    .as_nanos()
            ));
            fs::create_dir_all(&p).unwrap();
            TempDir(p)
        }
    }
    impl Drop for TempDir {
        fn drop(&mut self) {
            let _ = fs::remove_dir_all(&self.0);
        }
    }

    fn mode_of(p: &std::path::Path) -> u32 {
        fs::metadata(p).unwrap().permissions().mode() & 0o7777
    }

    /// oldroot fixture:
    ///   bin/ (0755)  cat(0755 "CAT\n") echo(0644 "ECHO\n")
    ///   lib/ (0700)  foo.a ("LIB\n")
    ///   mydir/       inner.txt ("INNER\n")
    ///   srcdir/      top.txt, sub/deep.txt
    fn fixture(tag: &str) -> (TempDir, PathBuf) {
        let td = TempDir::new(tag);
        let old = td.0.join("oldroot");
        fs::create_dir_all(old.join("bin")).unwrap();
        fs::create_dir_all(old.join("lib")).unwrap();
        fs::create_dir_all(old.join("mydir")).unwrap();
        fs::create_dir_all(old.join("srcdir/sub")).unwrap();
        fs::write(old.join("bin/cat"), b"CAT\n").unwrap();
        fs::write(old.join("bin/echo"), b"ECHO\n").unwrap();
        fs::write(old.join("lib/foo.a"), b"LIB\n").unwrap();
        fs::write(old.join("mydir/inner.txt"), b"INNER\n").unwrap();
        fs::write(old.join("srcdir/top.txt"), b"TOP\n").unwrap();
        fs::write(old.join("srcdir/sub/deep.txt"), b"DEEP\n").unwrap();
        fs::set_permissions(old.join("bin"), fs::Permissions::from_mode(0o755)).unwrap();
        fs::set_permissions(old.join("bin/cat"), fs::Permissions::from_mode(0o755)).unwrap();
        fs::set_permissions(old.join("bin/echo"), fs::Permissions::from_mode(0o644)).unwrap();
        fs::set_permissions(old.join("lib"), fs::Permissions::from_mode(0o700)).unwrap();
        (td, old)
    }

    fn write_proto(td: &TempDir, name: &str, text: &str) -> PathBuf {
        let p = td.0.join(name);
        fs::write(&p, text).unwrap();
        p
    }

    fn run(args: &[String]) -> (i32, String, String) {
        let mut out = Vec::new();
        let mut err = Vec::new();
        let rc = run_io(args, &mut out, &mut err);
        (rc, String::from_utf8(out).unwrap(), String::from_utf8(err).unwrap())
    }

    const PROTO_BASIC: &str = "# a comment line\nbin\td755\t0\t0\n\tcat\t755\t0\t0\n\techo\nlib\n\tfoo.a\t644\n";

    #[test]
    fn list_mode_prints_only_source_paths_on_stdout() {
        let (td, old) = fixture("list");
        let proto = write_proto(&td, "p.proto", PROTO_BASIC);
        let (rc, out, err) = run(&[
            "-aos".to_string(),
            old.to_string_lossy().into_owned(),
            proto.to_string_lossy().into_owned(),
        ]);
        assert_eq!(rc, 0);
        let lines: Vec<&str> = out.lines().collect();
        assert_eq!(
            lines,
            vec![
                format!("{}/bin/cat", old.display()),
                format!("{}/bin/echo", old.display()),
                format!("{}/lib/foo.a", old.display()),
            ],
            "list mode prints cleanname'd source paths in proto order"
        );
        assert_eq!(err, format!("processing {}\n", proto.display()));
    }

    #[test]
    fn materialize_builds_tree_with_modes() {
        let (td, old) = fixture("mat");
        let proto = write_proto(&td, "p.proto", PROTO_BASIC);
        let dest = td.0.join("dest");
        fs::create_dir_all(&dest).unwrap();
        let (rc, _out, err) = run(&[
            "-s".to_string(),
            old.to_string_lossy().into_owned(),
            "-d".to_string(),
            dest.to_string_lossy().into_owned(),
            proto.to_string_lossy().into_owned(),
        ]);
        assert_eq!(rc, 0);
        assert!(err.ends_with("file system made\n"), "stderr: {}", err);
        assert_eq!(fs::read(dest.join("bin/cat")).unwrap(), b"CAT\n");
        assert_eq!(fs::read(dest.join("bin/echo")).unwrap(), b"ECHO\n");
        assert_eq!(fs::read(dest.join("lib/foo.a")).unwrap(), b"LIB\n");
        assert_eq!(mode_of(&dest.join("bin")), 0o755, "explicit d755 mode");
        assert_eq!(mode_of(&dest.join("bin/cat")), 0o755, "explicit 755 mode");
        assert_eq!(mode_of(&dest.join("bin/echo")), 0o644, "source mode preserved");
        assert_eq!(mode_of(&dest.join("lib")), 0o700, "dir source mode preserved");
        assert_eq!(mode_of(&dest.join("lib/foo.a")), 0o644);
    }

    #[test]
    fn argbegin_clustering_equivalence() {
        let (td, old) = fixture("clu");
        let proto = write_proto(&td, "p.proto", PROTO_BASIC);
        let a = run(&[
            "-a".to_string(),
            "-o".to_string(),
            "-s".to_string(),
            old.to_string_lossy().into_owned(),
            proto.to_string_lossy().into_owned(),
        ]);
        let b = run(&[
            "-aos".to_string(),
            old.to_string_lossy().into_owned(),
            proto.to_string_lossy().into_owned(),
        ]);
        assert_eq!(a, b, "-a -o -s == -aos");
    }

    #[test]
    fn env_expansion_and_unset_warning() {
        let (td, old) = fixture("env");
        let proto = write_proto(
            &td,
            "p.proto",
            "$MKFS9_TEST_MYVAR\td755\n\tinner.txt\n$MKFS9_TEST_DEFINITELY_UNSET\n",
        );
        std::env::set_var("MKFS9_TEST_MYVAR", "mydir");
        std::env::remove_var("MKFS9_TEST_DEFINITELY_UNSET");
        let dest = td.0.join("dest");
        fs::create_dir_all(&dest).unwrap();
        let (rc, _out, err) = run(&[
            "-s".to_string(),
            old.to_string_lossy().into_owned(),
            "-d".to_string(),
            dest.to_string_lossy().into_owned(),
            proto.to_string_lossy().into_owned(),
        ]);
        assert_eq!(rc, 0);
        assert_eq!(fs::read(dest.join("mydir/inner.txt")).unwrap(), b"INNER\n");
        assert!(
            err.contains("can't read environment variable"),
            "stderr: {}",
            err
        );
    }

    #[test]
    fn missing_source_warns_and_skips_subtree() {
        let (td, old) = fixture("miss");
        let proto = write_proto(
            &td,
            "p.proto",
            "gone\n\tchild.txt\nbin\n\tcat\n",
        );
        let dest = td.0.join("dest");
        fs::create_dir_all(&dest).unwrap();
        let (rc, _out, err) = run(&[
            "-s".to_string(),
            old.to_string_lossy().into_owned(),
            "-d".to_string(),
            dest.to_string_lossy().into_owned(),
            proto.to_string_lossy().into_owned(),
        ]);
        assert_eq!(rc, 0);
        assert!(
            err.contains(&format!(
                "mkfs9: {}: can't stat file {}/gone: No such file or directory",
                proto.display(),
                old.display()
            )),
            "stderr: {}",
            err
        );
        assert!(dest.join("bin/cat").exists());
        assert!(!dest.join("gone").exists(), "missing subtree skipped");
        assert!(!dest.join("gone/child.txt").exists());
    }

    #[test]
    fn plus_recurses_current_source_dir() {
        let (td, old) = fixture("plus");
        let proto = write_proto(&td, "p.proto", "srcdir\n\t+\n");
        let dest = td.0.join("dest");
        fs::create_dir_all(&dest).unwrap();
        let (rc, _out, _err) = run(&[
            "-s".to_string(),
            old.to_string_lossy().into_owned(),
            "-d".to_string(),
            dest.to_string_lossy().into_owned(),
            proto.to_string_lossy().into_owned(),
        ]);
        assert_eq!(rc, 0);
        assert_eq!(fs::read(dest.join("srcdir/top.txt")).unwrap(), b"TOP\n");
        assert_eq!(fs::read(dest.join("srcdir/sub/deep.txt")).unwrap(), b"DEEP\n");

        // list mode prints the recursed files (cleanname'd)
        let (rc, out, _err) = run(&[
            "-a".to_string(),
            "-s".to_string(),
            old.to_string_lossy().into_owned(),
            proto.to_string_lossy().into_owned(),
        ]);
        assert_eq!(rc, 0);
        assert!(out.contains(&format!("{}/srcdir/top.txt", old.display())));
        assert!(out.contains(&format!("{}/srcdir/sub/deep.txt", old.display())));

        // '+' with an empty stack is a silent no-op
        let proto2 = write_proto(&td, "p2.proto", "+\nbin\n\tcat\n");
        let dest2 = td.0.join("dest2");
        fs::create_dir_all(&dest2).unwrap();
        let (rc, _o, _e) = run(&[
            "-s".to_string(),
            old.to_string_lossy().into_owned(),
            "-d".to_string(),
            dest2.to_string_lossy().into_owned(),
            proto2.to_string_lossy().into_owned(),
        ]);
        assert_eq!(rc, 0);
        assert!(dest2.join("bin/cat").exists());
    }

    #[test]
    fn bare_d_mode_falls_back_to_source_mode() {
        // IN-08: 'd' strips to an empty octal string — must not crash;
        // falls back to copying the source mode.
        let (td, old) = fixture("bared");
        let proto = write_proto(&td, "p.proto", "lib\td\n\tfoo.a\n");
        let dest = td.0.join("dest");
        fs::create_dir_all(&dest).unwrap();
        let (rc, _out, _err) = run(&[
            "-s".to_string(),
            old.to_string_lossy().into_owned(),
            "-d".to_string(),
            dest.to_string_lossy().into_owned(),
            proto.to_string_lossy().into_owned(),
        ]);
        assert_eq!(rc, 0, "bare d mode must not crash");
        assert_eq!(mode_of(&dest.join("lib")), 0o700, "source mode copied");
    }

    #[test]
    fn cleanname_plan9() {
        assert_eq!(cleanname("/a/b/../c"), "/a/c");
        assert_eq!(cleanname("/a/./b"), "/a/b");
        assert_eq!(cleanname("a/b/.."), "a");
        assert_eq!(cleanname("/.."), "/");
        assert_eq!(cleanname("//a//b"), "/a/b");
    }

    #[test]
    fn usage_and_flag_errors() {
        let (rc, _o, e) = run(&[]);
        assert_eq!(rc, 2);
        assert_eq!(e, USAGE);
        let (rc, _o, e) = run(&["-Z".to_string(), "p.proto".to_string()]);
        assert_eq!(rc, 2);
        assert!(e.contains("mkfs9: unsupported flag -Z"), "stderr: {}", e);
        // materialize without -d
        let (td, old) = fixture("usage");
        let proto = write_proto(&td, "p.proto", PROTO_BASIC);
        let (rc, _o, e) = run(&[
            "-s".to_string(),
            old.to_string_lossy().into_owned(),
            proto.to_string_lossy().into_owned(),
        ]);
        assert_eq!(rc, 2);
        assert!(e.contains("-d required"), "stderr: {}", e);
    }
}
