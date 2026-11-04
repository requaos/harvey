//! mkfs9.rs — host-side replacement for the donor's disk/mkfs (port of
//! mkfs9.py), installed as disk/mkfs in the guest scratch bin by
//! donor-ns-build.sh (via the harness-pkg wrapper).
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
//! preserved.  A bare `d` mode (strips to empty) falls back to copying
//! the source mode instead of crashing.

use std::fs;
use std::io::Write;
use std::path::{Path, PathBuf};

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

struct ProtoEntry {
    depth: usize,
    name: String,
    mode: Option<String>,
    src: Option<String>,
}

/// Parse one proto file (donor libdisk/proto.c grammar):
/// indent (tab=8, space=1) tree; fields: name [mode uid gid source];
/// `$env` name expansion; '#' comments; blank lines skipped.
fn parse_proto(fname: &Path, err: &mut dyn Write) -> Result<Vec<ProtoEntry>, std::io::Error> {
    let text = fs::read_to_string(fname)?;
    let mut entries = Vec::new();
    for line in text.lines() {
        if line.is_empty() {
            continue;
        }
        let mut depth = 0usize;
        let bytes = line.as_bytes();
        let mut i = 0usize;
        while i < bytes.len() && (bytes[i] == b' ' || bytes[i] == b'\t') {
            depth += if bytes[i] == b'\t' { 8 } else { 1 };
            i += 1;
        }
        let body = &line[i..];
        if body.is_empty() || body.starts_with('#') {
            continue;
        }
        let fields: Vec<&str> = body.split_whitespace().collect();
        let mut name = fields[0].to_string();
        if let Some(var) = name.strip_prefix('$') {
            match std::env::var(var) {
                Ok(v) if !v.is_empty() => name = v,
                _ => {
                    let _ = writeln!(err, "mkfs9: {}: can't read environment variable", fname.display());
                    continue;
                }
            }
        }
        let rest = &fields[1..];
        let mut mode: Option<String> = None;
        if let Some(first) = rest.first() {
            if *first != "-" && first.chars().all(|c| "01234567dal".contains(c)) {
                mode = Some(first.to_string());
            }
        }
        // fields: mode uid gid [source]; source is the 5th field overall
        let src = fields.get(4).map(|s| s.to_string());
        entries.push(ProtoEntry {
            depth,
            name,
            mode,
            src,
        });
    }
    Ok(entries)
}

/// Resolve an entry's source path: implicit (oldroot + proto path),
/// oldroot-rooted absolute, or cwd-relative.
fn sourcepath(oldroot: &str, cwd: &Path, pp: &str, src: Option<&str>) -> String {
    match src {
        None | Some("-") => cleanname(&format!("{}/{}", oldroot, pp)),
        Some(s) if s.starts_with('/') => cleanname(&format!("{}{}", oldroot, s)),
        Some(s) => cleanname(&cwd.join(s).to_string_lossy()),
    }
}

/// chmod with a proto mode string (strip the d/a/l letters, parse octal);
/// a bare 'd' (or 'dal' letters only) strips to empty — fall back to
/// copying the source mode instead of crashing.
fn apply_mode(mode: &Option<String>, src: &Path, dest: &Path) -> std::io::Result<()> {
    use std::os::unix::fs::PermissionsExt;
    match mode {
        Some(m) => {
            let digits: String = m.chars().filter(|c| *c != 'd' && *c != 'a' && *c != 'l').collect();
            if digits.is_empty() {
                copymode(src, dest)
            } else {
                let v = u32::from_str_radix(&digits, 8)
                    .map_err(|e| std::io::Error::new(std::io::ErrorKind::InvalidInput, e))?;
                fs::set_permissions(dest, fs::Permissions::from_mode(v))
            }
        }
        None => copymode(src, dest),
    }
}

fn copymode(src: &Path, dest: &Path) -> std::io::Result<()> {
    use std::os::unix::fs::PermissionsExt;
    let m = fs::metadata(src)?.permissions().mode() & 0o7777;
    fs::set_permissions(dest, fs::Permissions::from_mode(m))
}

/// `+` recursion: copy the current entry's source dir contents, os.walk
/// order (dirs and files of each level handled before descending; symlinked
/// dirs are created but not descended, python followlinks=False).
fn recurse_copy(
    spath: &Path,
    pp: &str,
    dest: Option<&Path>,
    listonly: bool,
    out: &mut dyn Write,
) {
    fn rec(
        sroot: &Path,
        cur: &Path,
        pp: &str,
        dest: Option<&Path>,
        listonly: bool,
        out: &mut dyn Write,
    ) {
        let mut dirs: Vec<PathBuf> = Vec::new();
        let mut files: Vec<PathBuf> = Vec::new();
        if let Ok(rd) = fs::read_dir(cur) {
            for e in rd.flatten() {
                let p = e.path();
                // is_dir follows symlinks, like python's scandir default
                if p.is_dir() {
                    dirs.push(p);
                } else {
                    files.push(p);
                }
            }
        }
        for d in &dirs {
            if let Some(dest) = dest {
                let rel = d.strip_prefix(sroot).unwrap();
                let dd = dest.join(pp).join(rel);
                let _ = fs::create_dir_all(&dd);
                let _ = copymode(d, &dd);
            }
        }
        for f in &files {
            if listonly {
                let _ = writeln!(out, "{}", cleanname(&f.to_string_lossy()));
            } else if let Some(dest) = dest {
                let rel = f.strip_prefix(sroot).unwrap();
                let dd = dest.join(pp).join(rel);
                if let Some(par) = dd.parent() {
                    let _ = fs::create_dir_all(par);
                }
                let _ = fs::copy(f, &dd);
                let _ = copymode(f, &dd);
            }
        }
        for d in &dirs {
            // followlinks=False: do not descend into symlinked dirs
            if !d.is_symlink() {
                rec(sroot, d, pp, dest, listonly, out);
            }
        }
    }
    rec(spath, spath, pp, dest, listonly, out);
}

/// Drive the proto entries; print sources (list mode) or materialize.
fn walk(
    protos: &[String],
    oldroot: &str,
    dest: Option<&Path>,
    listonly: bool,
    out: &mut dyn Write,
    err: &mut dyn Write,
) {
    let cwd = std::env::current_dir().unwrap_or_else(|_| PathBuf::from("/"));
    for pr in protos {
        let prpath = Path::new(pr);
        let entries = match parse_proto(prpath, err) {
            Ok(e) => e,
            Err(e) => {
                let _ = writeln!(err, "mkfs9: {}: {}", pr, e);
                continue;
            }
        };
        // stack of (depth, proto_path, resolved_src, alive)
        let mut stack: Vec<(usize, String, String, bool)> = Vec::new();
        for e in entries {
            while let Some(top) = stack.last() {
                if top.0 >= e.depth {
                    stack.pop();
                } else {
                    break;
                }
            }
            if let Some(top) = stack.last() {
                if !top.3 {
                    continue; // inside a skipped subtree
                }
            }
            if e.name == "+" {
                // recurse: copy the current entry's source dir contents
                let Some((_, pp, spath, _)) = stack.last().cloned() else {
                    continue;
                };
                if !Path::new(&spath).is_dir() {
                    let _ = writeln!(
                        err,
                        "mkfs9: {}: can't recurse {}: not a directory",
                        pr, spath
                    );
                    continue;
                }
                recurse_copy(Path::new(&spath), &pp, dest, listonly, out);
                continue;
            }
            let pp = match stack.last() {
                Some(top) => format!("{}/{}", top.1, e.name),
                None => e.name.clone(),
            };
            let spath = sourcepath(oldroot, &cwd, &pp, e.src.as_deref());
            let sp = Path::new(&spath);
            if sp.is_dir() {
                if let Some(dest) = dest {
                    let dd = dest.join(&pp);
                    let _ = fs::create_dir_all(&dd);
                    let _ = apply_mode(&e.mode, sp, &dd);
                }
                stack.push((e.depth, pp, spath, true));
            } else if sp.exists() {
                if listonly {
                    let _ = writeln!(out, "{}", cleanname(&spath));
                } else if let Some(dest) = dest {
                    let dd = dest.join(&pp);
                    if let Some(par) = dd.parent() {
                        let _ = fs::create_dir_all(par);
                    }
                    let _ = fs::copy(sp, &dd);
                    let _ = apply_mode(&e.mode, sp, &dd);
                }
                stack.push((e.depth, pp, spath, true));
            } else {
                let _ = writeln!(
                    err,
                    "mkfs9: {}: can't stat file {}: No such file or directory",
                    pr, spath
                );
                stack.push((e.depth, pp, spath, false));
            }
        }
    }
}

pub fn run(args: &[String]) -> i32 {
    let mut out = std::io::stdout();
    let mut err = std::io::stderr();
    run_io(args, &mut out, &mut err)
}

pub fn run_io(args: &[String], out: &mut dyn Write, err: &mut dyn Write) -> i32 {
    let mut listonly = false;
    let mut oldroot = "/".to_string();
    let mut dest: Option<String> = None;
    let mut protos: Vec<String> = Vec::new();
    let mut i = 0;
    while i < args.len() {
        let a = &args[i];
        let bytes = a.as_bytes();
        if bytes.len() > 1 && bytes[0] == b'-' {
            // ARGBEGIN-style flag clustering: -aos == -a -o -s
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
    for pr in &protos {
        let _ = writeln!(err, "processing {}", pr);
    }
    walk(&protos, &oldroot, dest.as_deref().map(Path::new), listonly, out, err);
    if !listonly {
        let _ = writeln!(err, "file system made");
    }
    0
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
        // 'd' strips to an empty octal string — must not crash;
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
