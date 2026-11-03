//! srv9.rs — minimal 9P2000 file server over TCP (port of srv9.py).
//!
//! Serves a host directory tree so the 9front donor kernel (CONF=qemu) can
//! boot to an rc shell: the guest runs bootrc with bootargs=tcp and mounts
//! this tree as its root via `srv -q tcp!$fs!564 boot` + `mount /srv/boot
//! /root`. Read-only by default; --writable-prefix PATH (repeatable) lifts
//! the read-only Rerror for guest-visible absolute prefixes (e.g. /tmp and
//! /usr/glenda/tmp).
//!
//! Porting-fidelity notes (02-REVIEW-DISPOSITION, preserved deliberately):
//!   - IN-05: Twstat rename DELETES an existing target before os.rename —
//!     harness semantics the subset gate may rely on.
//!   - IN-04: the fid table is per-connection here (the .py shared it
//!     across connections with a global lock); strictly more correct and
//!     behavior-identical under the gates' single-active-connection use.
//!
//! Wire format: all fields little-endian (Harvey sys/src/libc/9sys/convD2M.c,
//! convS2M.c, sys/include/fcall.h). MAXMSIZE 65536. Threat T-GIQ-01: frames
//! with size < 7 or > MAXMSIZE+24 drop the connection; every integer read is
//! bounds-checked. Threat T-GIQ-02: every walked path is canonicalized and
//! must equal-or-be-under the served root ('..' clamped at root). Threat
//! T-GIQ-03: writable ops pass the canonicalized-path writable check, else
//! Rerror "read only".

use std::collections::HashMap;
use std::fs;
use std::io::{Read, Write};
use std::net::{TcpListener, TcpStream};
use std::os::unix::ffi::OsStrExt;
use std::os::unix::fs::MetadataExt;
use std::path::{Path, PathBuf};
use std::sync::{Arc, Mutex};
use std::thread;

pub const MAXMSIZE: u32 = 65536;
const VERSION: &[u8] = b"9P2000";

// message types (sys/include/fcall.h)
pub const TVERSION: u8 = 100;
pub const RVERSION: u8 = 101;
pub const TAUTH: u8 = 102;
#[allow(dead_code)]
pub const RAUTH: u8 = 103;
pub const TATTACH: u8 = 104;
pub const RATTACH: u8 = 105;
pub const RERROR: u8 = 107;
pub const TFLUSH: u8 = 108;
pub const RFLUSH: u8 = 109;
pub const TWALK: u8 = 110;
pub const RWALK: u8 = 111;
pub const TOPEN: u8 = 112;
pub const ROPEN: u8 = 113;
pub const TCREATE: u8 = 114;
pub const RCREATE: u8 = 115;
pub const TREAD: u8 = 116;
pub const RREAD: u8 = 117;
pub const TWRITE: u8 = 118;
pub const RWRITE: u8 = 119;
pub const TCLUNK: u8 = 120;
pub const RCLUNK: u8 = 121;
pub const TREMOVE: u8 = 122;
pub const RREMOVE: u8 = 123;
pub const TSTAT: u8 = 124;
pub const RSTAT: u8 = 125;
pub const TWSTAT: u8 = 126;
pub const RWSTAT: u8 = 127;

pub const QTDIR: u8 = 0x80;
pub const DMDIR: u32 = 0x8000_0000;

pub fn p16(v: u16) -> [u8; 2] {
    v.to_le_bytes()
}
pub fn p32(v: u32) -> [u8; 4] {
    v.to_le_bytes()
}
pub fn p64(v: u64) -> [u8; 8] {
    v.to_le_bytes()
}
pub fn pstr(s: &[u8]) -> Vec<u8> {
    let mut out = Vec::with_capacity(2 + s.len());
    out.extend_from_slice(&p16(s.len() as u16));
    out.extend_from_slice(s);
    out
}

/// Byte-exact startup line the shell callers poll for ('srv9: serving').
pub fn serving_line(root: &Path, host: &str, port: u16, writable: &[String]) -> String {
    let mode = if writable.is_empty() {
        "read-only".to_string()
    } else {
        format!("writable prefixes: {}", writable.join(", "))
    };
    format!(
        "srv9: serving {} on {}:{} (9P2000, {})",
        realpath(root).display(),
        host,
        port,
        mode
    )
}

/// os.path.realpath equivalent that tolerates non-existent tails
/// (fs::canonicalize requires existence; Python's realpath does not).
pub fn realpath(p: &Path) -> PathBuf {
    match std::fs::canonicalize(p) {
        Ok(c) => c,
        Err(_) => match (p.parent(), p.file_name()) {
            (Some(par), Some(name)) if par != p => realpath(par).join(name),
            _ => p.to_path_buf(),
        },
    }
}

/// Serve connections on `listener` forever (one thread per connection).
pub fn serve(listener: TcpListener, root: &Path, writable: &[String]) -> std::io::Result<()> {
    let srv = Arc::new(Shared::new(root, writable));
    for conn in listener.incoming() {
        match conn {
            Ok(c) => {
                let srv = srv.clone();
                thread::spawn(move || serveconn(srv, c));
            }
            Err(_) => continue,
        }
    }
    Ok(())
}

struct Shared {
    root: PathBuf,      // canonicalized served root
    wr: Vec<PathBuf>,   // canonicalized writable prefixes (host-side)
    vmap: Mutex<HashMap<PathBuf, u32>>, // realpath -> qid version (bumps on mutation)
}

impl Shared {
    fn new(root: &Path, writable: &[String]) -> Shared {
        let root = realpath(root);
        let wr = writable
            .iter()
            .map(|p| realpath(&root.join(p.trim_start_matches('/'))))
            .collect();
        Shared {
            root,
            wr,
            vmap: Mutex::new(HashMap::new()),
        }
    }

    fn writable(&self, path: &Path) -> bool {
        let real = realpath(path);
        self.wr.iter().any(|p| real == *p || real.starts_with(p))
    }

    fn bump(&self, path: &Path) {
        let real = realpath(path);
        let mut vmap = self.vmap.lock().unwrap();
        *vmap.entry(real).or_insert(0) += 1;
    }

    fn qidfor(&self, path: &Path) -> Qid {
        let real = realpath(path);
        let vers = self.vmap.lock().unwrap().get(&real).copied().unwrap_or(0);
        match fs::metadata(path) {
            Ok(md) => {
                let mut ino = md.ino();
                if ino == 0 {
                    ino = hash_path(path);
                }
                Qid {
                    qtype: if md.is_dir() { QTDIR } else { 0 },
                    vers,
                    path: ino,
                }
            }
            Err(_) => Qid {
                qtype: 0,
                vers,
                path: hash_path(path),
            },
        }
    }

    /// stat(5) bytes for `path` (with the stat's own u16 size prefix).
    /// Writable paths report honest 0777/0666 modes (dirstat honesty so a
    /// -C cached mount sees reality); read-only paths report 0555.
    fn statbytes(&self, path: &Path, name: Option<&str>) -> Result<Vec<u8>, P9Error> {
        let st = fs::symlink_metadata(path).map_err(|_| P9Error("file does not exist".into()))?;
        let name = match name {
            Some(n) => n.to_string(),
            None => path
                .file_name()
                .map(|n| n.to_string_lossy().into_owned())
                .unwrap_or_else(|| "/".to_string()),
        };
        let isdir = st.is_dir();
        let q = self.qidfor(path);
        let mode = if self.writable(path) {
            if isdir {
                DMDIR | 0o777
            } else {
                0o666
            }
        } else {
            if isdir {
                DMDIR | 0o555
            } else {
                0o555
            }
        };
        let length = if isdir { 0 } else { st.len() };
        let mtime = st.mtime() as u32;
        let mut body = Vec::new();
        body.extend_from_slice(&p16(0)); // type (dev type — unused)
        body.extend_from_slice(&p32(0)); // dev
        body.extend_from_slice(&q.encode());
        body.extend_from_slice(&p32(mode));
        body.extend_from_slice(&p32(mtime)); // atime
        body.extend_from_slice(&p32(mtime)); // mtime
        body.extend_from_slice(&p64(length));
        body.extend_from_slice(&pstr(name.as_bytes()));
        body.extend_from_slice(&pstr(b"glenda")); // uid
        body.extend_from_slice(&pstr(b"glenda")); // gid
        body.extend_from_slice(&pstr(b"glenda")); // muid
        let mut out = Vec::with_capacity(2 + body.len());
        out.extend_from_slice(&p16(body.len() as u16));
        out.extend_from_slice(&body);
        Ok(out)
    }
}

/// FNV-1a fallback qid path when st_ino is unavailable (mirrors the .py's
/// abs(hash(path)) fallback — stable within a process run).
fn hash_path(p: &Path) -> u64 {
    let mut h: u64 = 0xcbf2_9ce4_8422_2325;
    for &b in p.as_os_str().as_bytes() {
        h ^= b as u64;
        h = h.wrapping_mul(0x100_0000_01b3);
    }
    h
}

pub struct Qid {
    pub qtype: u8,
    pub vers: u32,
    pub path: u64,
}

impl Qid {
    pub fn encode(&self) -> [u8; 13] {
        let mut out = [0u8; 13];
        out[0] = self.qtype;
        out[1..5].copy_from_slice(&self.vers.to_le_bytes());
        out[5..13].copy_from_slice(&self.path.to_le_bytes());
        out
    }
}

struct Fid {
    path: PathBuf,
    #[allow(dead_code)]
    open: bool,
    dirbuf: Option<Vec<u8>>,
    dirents: Option<Vec<usize>>,
}

impl Fid {
    fn new(path: PathBuf) -> Fid {
        Fid {
            path,
            open: false,
            dirbuf: None,
            dirents: None,
        }
    }
}

struct P9Error(String);

/// Bounds-checked little-endian payload reader (T-GIQ-01: no panic paths on
/// malformed frames — short reads become Rerror).
struct Rd<'a> {
    b: &'a [u8],
    off: usize,
}

impl<'a> Rd<'a> {
    fn new(b: &'a [u8]) -> Rd<'a> {
        Rd { b, off: 0 }
    }
    fn g16(&mut self) -> Result<u16, P9Error> {
        if self.off + 2 > self.b.len() {
            return Err(P9Error("malformed message".into()));
        }
        let v = u16::from_le_bytes([self.b[self.off], self.b[self.off + 1]]);
        self.off += 2;
        Ok(v)
    }
    fn g32(&mut self) -> Result<u32, P9Error> {
        if self.off + 4 > self.b.len() {
            return Err(P9Error("malformed message".into()));
        }
        let v = u32::from_le_bytes([
            self.b[self.off],
            self.b[self.off + 1],
            self.b[self.off + 2],
            self.b[self.off + 3],
        ]);
        self.off += 4;
        Ok(v)
    }
    fn g64(&mut self) -> Result<u64, P9Error> {
        let lo = self.g32()? as u64;
        let hi = self.g32()? as u64;
        Ok(lo | (hi << 32))
    }
    fn gstr(&mut self) -> Result<String, P9Error> {
        let n = self.g16()? as usize;
        if self.off + n > self.b.len() {
            return Err(P9Error("malformed message".into()));
        }
        let s = String::from_utf8_lossy(&self.b[self.off..self.off + n]).into_owned();
        self.off += n;
        Ok(s)
    }
    fn rest(&self, n: usize) -> &'a [u8] {
        // clamp like the .py's slice semantics (short frames yield short data)
        let avail = self.b.len().saturating_sub(self.off);
        &self.b[self.off..self.off + n.min(avail)]
    }
}

/// Materialize the fid's directory listing (sorted, dotfiles skipped) and
/// remember the whole-entry end offsets.
fn dirlisting(srv: &Shared, f: &mut Fid) {
    if f.dirbuf.is_some() {
        return;
    }
    let mut ents = Vec::new();
    let mut ends = Vec::new();
    let mut off = 0usize;
    let names: Vec<String> = match fs::read_dir(&f.path) {
        Ok(rd) => {
            let mut v: Vec<String> = rd
                .filter_map(|e| e.ok())
                .map(|e| e.file_name().to_string_lossy().into_owned())
                .collect();
            v.sort();
            v
        }
        Err(_) => Vec::new(),
    };
    for n in names {
        if n.starts_with('.') {
            continue;
        }
        if let Ok(b) = srv.statbytes(&f.path.join(&n), Some(&n)) {
            off += b.len();
            ents.extend_from_slice(&b);
            ends.push(off);
        }
    }
    f.dirbuf = Some(ents);
    f.dirents = Some(ends);
}

fn resolve(fids: &HashMap<u32, Fid>, fid: u32) -> Result<&Fid, P9Error> {
    fids.get(&fid).ok_or_else(|| P9Error("unknown fid".into()))
}

fn resolve_mut(fids: &mut HashMap<u32, Fid>, fid: u32) -> Result<&mut Fid, P9Error> {
    fids.get_mut(&fid).ok_or_else(|| P9Error("unknown fid".into()))
}

fn dropdircache(fids: &mut HashMap<u32, Fid>) {
    // a mutation invalidated cached directory listings on every fid of this
    // connection (the .py cleared a shared table; per-conn here, IN-04)
    for f in fids.values_mut() {
        f.dirbuf = None;
        f.dirents = None;
    }
}

fn handle(
    srv: &Shared,
    fids: &mut HashMap<u32, Fid>,
    ctype: u8,
    p: &[u8],
) -> Result<(u8, Vec<u8>), P9Error> {
    match ctype {
        TVERSION => {
            let mut r = Rd::new(p);
            let msize = r.g32()?;
            // version string follows; we speak 9P2000 only
            fids.clear();
            let mut out = Vec::new();
            out.extend_from_slice(&p32(msize.min(MAXMSIZE)));
            out.extend_from_slice(&pstr(VERSION));
            Ok((RVERSION, out))
        }
        TAUTH => Err(P9Error("authentication not required".into())),
        TFLUSH => Ok((RFLUSH, Vec::new())),
        TATTACH => {
            let mut r = Rd::new(p);
            let fid = r.g32()?;
            let _afid = r.g32()?;
            // uname/aname strings after; we serve the root regardless
            fids.insert(fid, Fid::new(srv.root.clone()));
            Ok((RATTACH, srv.qidfor(&srv.root).encode().to_vec()))
        }
        TWALK => {
            let mut r = Rd::new(p);
            let fid = r.g32()?;
            let newfid = r.g32()?;
            let nw = r.g16()? as usize;
            let mut names = Vec::with_capacity(nw);
            for _ in 0..nw {
                names.push(r.gstr()?);
            }
            let mut cur = resolve(fids, fid)?.path.clone();
            let mut qids: Vec<u8> = Vec::new();
            let mut ok = true;
            for n in &names {
                if n == "." {
                    // no-op
                } else if n == ".." {
                    // clamped at the served root: '..' at root stays at root
                    if cur != srv.root {
                        if let Some(parent) = cur.parent() {
                            if parent == srv.root || parent.starts_with(&srv.root) {
                                cur = parent.to_path_buf();
                            }
                        }
                    }
                } else {
                    let nxt = cur.join(n);
                    let real = realpath(&nxt);
                    if !(real == srv.root || real.starts_with(&srv.root)) {
                        ok = false;
                        break;
                    }
                    if !nxt.exists() {
                        ok = false;
                        break;
                    }
                    cur = nxt;
                }
                qids.extend_from_slice(&srv.qidfor(&cur).encode());
            }
            let mut out = Vec::new();
            if !ok && qids.is_empty() {
                return Err(P9Error("file does not exist".into()));
            }
            let nq = qids.len() / 13;
            out.extend_from_slice(&p16(nq as u16));
            out.extend_from_slice(&qids);
            if ok {
                fids.insert(newfid, Fid::new(cur));
            }
            Ok((RWALK, out))
        }
        TOPEN => {
            let mut r = Rd::new(p);
            let fid = r.g32()?;
            let f = resolve_mut(fids, fid)?;
            if !f.path.exists() {
                return Err(P9Error("file does not exist".into()));
            }
            f.open = true;
            f.dirbuf = None;
            let mut out = srv.qidfor(&f.path).encode().to_vec();
            out.extend_from_slice(&p32(0)); // iounit
            Ok((ROPEN, out))
        }
        TREAD => {
            let mut r = Rd::new(p);
            let fid = r.g32()?;
            let offset = r.g64()?;
            let count = r.g32()?;
            let f = resolve_mut(fids, fid)?;
            if f.path.is_dir() {
                dirlisting(srv, f);
                let buf = f.dirbuf.as_ref().unwrap();
                let ends = f.dirents.as_ref().unwrap();
                let offset = offset as usize;
                let mut out = Vec::new();
                if offset >= buf.len() {
                    out.extend_from_slice(&p32(0));
                    return Ok((RREAD, out));
                }
                // whole entries only: the largest set of entries in
                // [offset, offset+count)
                let end = offset + count as usize;
                let mut n = 0usize;
                for &e in ends {
                    if e <= offset {
                        continue;
                    }
                    if e > end {
                        break;
                    }
                    n = e;
                }
                if n == 0 {
                    // a single entry larger than count cannot happen with a
                    // sane msize; return empty (client retries/EOF)
                    out.extend_from_slice(&p32(0));
                    return Ok((RREAD, out));
                }
                out.extend_from_slice(&p32((n - offset) as u32));
                out.extend_from_slice(&buf[offset..n]);
                return Ok((RREAD, out));
            }
            let data = (|| -> Result<Vec<u8>, P9Error> {
                use std::io::{Read, Seek, SeekFrom};
                let mut fp = fs::File::open(&f.path).map_err(|_| P9Error("i/o error".into()))?;
                fp.seek(SeekFrom::Start(offset))
                    .map_err(|_| P9Error("i/o error".into()))?;
                let mut buf = vec![0u8; count as usize];
                let n = fp.read(&mut buf).map_err(|_| P9Error("i/o error".into()))?;
                buf.truncate(n);
                Ok(buf)
            })()?;
            let mut out = Vec::new();
            out.extend_from_slice(&p32(data.len() as u32));
            out.extend_from_slice(&data);
            Ok((RREAD, out))
        }
        TSTAT => {
            let mut r = Rd::new(p);
            let fid = r.g32()?;
            let f = resolve(fids, fid)?;
            if !f.path.exists() {
                return Err(P9Error("file does not exist".into()));
            }
            let sb = srv.statbytes(&f.path, None)?;
            let mut out = Vec::new();
            out.extend_from_slice(&p16(sb.len() as u16));
            out.extend_from_slice(&sb);
            Ok((RSTAT, out))
        }
        TCLUNK => {
            let mut r = Rd::new(p);
            let fid = r.g32()?;
            fids.remove(&fid);
            Ok((RCLUNK, Vec::new()))
        }
        TCREATE => {
            let mut r = Rd::new(p);
            let fid = r.g32()?;
            let name = r.gstr()?;
            let perm = r.g32()?;
            // (mode byte follows; unused, as in the .py)
            if !srv.writable(&resolve(fids, fid)?.path) {
                return Err(P9Error("read only".into()));
            }
            {
                let f = resolve(fids, fid)?;
                if !f.path.is_dir() {
                    return Err(P9Error("not a directory".into()));
                }
            }
            if name.is_empty() || name == "." || name == ".." || name.contains('/') {
                return Err(P9Error("bad name in create".into()));
            }
            let npath = resolve(fids, fid)?.path.join(&name);
            if perm & DMDIR != 0 {
                fs::create_dir(&npath).map_err(|e| {
                    if e.kind() == std::io::ErrorKind::AlreadyExists {
                        P9Error("file exists".into())
                    } else {
                        P9Error("i/o error".into())
                    }
                })?;
            } else {
                use std::os::unix::fs::OpenOptionsExt;
                let r = fs::OpenOptions::new()
                    .write(true)
                    .create_new(true)
                    .mode(0o666)
                    .open(&npath);
                match r {
                    Ok(_) => {}
                    Err(e) if e.kind() == std::io::ErrorKind::AlreadyExists => {
                        return Err(P9Error("file exists".into()))
                    }
                    Err(_) => return Err(P9Error("i/o error".into())),
                }
            }
            srv.bump(&resolve(fids, fid)?.path); // parent dir listing changed
            srv.bump(&npath);
            dropdircache(fids);
            {
                let f = resolve_mut(fids, fid)?;
                f.path = npath.clone();
                f.open = true;
                f.dirbuf = None;
                f.dirents = None;
            }
            let mut out = srv.qidfor(&npath).encode().to_vec();
            out.extend_from_slice(&p32(0));
            Ok((RCREATE, out))
        }
        TWRITE => {
            let mut r = Rd::new(p);
            let fid = r.g32()?;
            let offset = r.g64()?;
            let count = r.g32()? as usize;
            let data = r.rest(count).to_vec();
            let f = resolve(fids, fid)?;
            if !srv.writable(&f.path) {
                return Err(P9Error("read only".into()));
            }
            (|| -> Result<(), P9Error> {
                use std::io::{Seek, SeekFrom, Write};
                let mut fp = fs::OpenOptions::new()
                    .read(true)
                    .write(true)
                    .open(&f.path)
                    .map_err(|_| P9Error("i/o error".into()))?;
                fp.seek(SeekFrom::Start(offset))
                    .map_err(|_| P9Error("i/o error".into()))?;
                fp.write_all(&data).map_err(|_| P9Error("i/o error".into()))
            })()?;
            srv.bump(&f.path);
            let mut out = Vec::new();
            out.extend_from_slice(&p32(data.len() as u32));
            Ok((RWRITE, out))
        }
        TREMOVE => {
            let mut r = Rd::new(p);
            let fid = r.g32()?;
            let f = resolve(fids, fid)?;
            if !srv.writable(&f.path) {
                return Err(P9Error("read only".into()));
            }
            let path = f.path.clone();
            let parent = path.parent().map(|p| p.to_path_buf());
            let r = if path.is_dir() {
                fs::remove_dir(&path)
            } else {
                fs::remove_file(&path)
            };
            r.map_err(|_| P9Error("i/o error".into()))?;
            if let Some(par) = parent {
                srv.bump(&par);
            }
            dropdircache(fids);
            fids.remove(&fid);
            Ok((RREMOVE, Vec::new()))
        }
        TWSTAT => {
            // mv(1) renames via dirwstat with only the name field set
            // (nulldir + null.name); apply exactly that and no-op the rest.
            // Payload: fid(4) size(2) stat-body — name begins at 4+2+39=45.
            let mut r = Rd::new(p);
            let fid = r.g32()?;
            {
                let f = resolve(fids, fid)?;
                if !srv.writable(&f.path) {
                    return Err(P9Error("read only".into()));
                }
            }
            let name = if p.len() >= 45 + 2 {
                let nlen = u16::from_le_bytes([p[45], p[46]]) as usize;
                if 47 + nlen <= p.len() {
                    String::from_utf8_lossy(&p[47..47 + nlen]).into_owned()
                } else {
                    String::new()
                }
            } else {
                String::new()
            };
            if !name.is_empty() && name != "." && name != ".." && !name.contains('/') {
                let (parent, npath) = {
                    let f = resolve(fids, fid)?;
                    let parent = f
                        .path
                        .parent()
                        .map(|p| p.to_path_buf())
                        .unwrap_or_else(|| srv.root.clone());
                    let npath = parent.join(&name);
                    (parent, npath)
                };
                if !srv.writable(&npath) {
                    return Err(P9Error("read only".into()));
                }
                // IN-05 (preserved): rename over an EXISTING target deletes
                // the target first — harness semantics the subset gate may
                // rely on. Do not "fix" silently.
                {
                    let f = resolve(fids, fid)?;
                    if npath.exists() {
                        let r = if npath.is_dir() {
                            fs::remove_dir(&npath)
                        } else {
                            fs::remove_file(&npath)
                        };
                        r.map_err(|_| P9Error("i/o error".into()))?;
                    }
                    fs::rename(&f.path, &npath).map_err(|_| P9Error("i/o error".into()))?;
                }
                resolve_mut(fids, fid)?.path = npath.clone();
                srv.bump(&parent);
                srv.bump(&npath);
                dropdircache(fids);
            }
            Ok((RWSTAT, Vec::new()))
        }
        other => Err(P9Error(format!("unknown message type {}", other))),
    }
}

fn serveconn(srv: Arc<Shared>, conn: TcpStream) {
    let mut fids: HashMap<u32, Fid> = HashMap::new(); // per-connection (IN-04)
    loop {
        let mut hdr = [0u8; 4];
        if (&conn).read_exact(&mut hdr).is_err() {
            break;
        }
        let size = u32::from_le_bytes(hdr) as usize;
        if size < 7 || size > MAXMSIZE as usize + 24 {
            break; // T-GIQ-01 frame guard
        }
        let mut rest = vec![0u8; size - 4];
        if (&conn).read_exact(&mut rest).is_err() {
            break;
        }
        let ctype = rest[0];
        let tag = u16::from_le_bytes([rest[1], rest[2]]);
        let payload = &rest[3..];
        let (rtype, rpayload) = match handle(&srv, &mut fids, ctype, payload) {
            Ok(x) => x,
            Err(e) => (RERROR, pstr(e.0.as_bytes())),
        };
        let mut out = Vec::with_capacity(7 + rpayload.len());
        out.extend_from_slice(&p32(4 + 1 + 2 + rpayload.len() as u32));
        out.push(rtype);
        out.extend_from_slice(&p16(tag));
        out.extend_from_slice(&rpayload);
        if (&conn).write_all(&out).is_err() {
            break;
        }
    }
    // fids drop with the connection
}

pub fn run(args: &[String]) -> i32 {
    if args.is_empty() || args[0] != "serve" {
        eprintln!("usage: harness srv9 serve --root DIR [--host H] [--port P] [--writable-prefix PATH ...]");
        return 2;
    }
    let mut root: Option<String> = None;
    let mut host = "127.0.0.1".to_string();
    let mut port: u16 = 1564;
    let mut writable: Vec<String> = Vec::new();
    let mut i = 1;
    while i < args.len() {
        match args[i].as_str() {
            "--root" => {
                root = args.get(i + 1).cloned();
                i += 2;
            }
            "--host" => {
                host = match args.get(i + 1) {
                    Some(h) => h.clone(),
                    None => {
                        eprintln!("srv9: --host requires a value");
                        return 2;
                    }
                };
                i += 2;
            }
            "--port" => {
                port = match args.get(i + 1).and_then(|p| p.parse().ok()) {
                    Some(p) => p,
                    None => {
                        eprintln!("srv9: --port requires a numeric value");
                        return 2;
                    }
                };
                i += 2;
            }
            "--writable-prefix" => match args.get(i + 1) {
                Some(p) => {
                    writable.push(p.clone());
                    i += 2;
                }
                None => {
                    eprintln!("srv9: --writable-prefix requires a value");
                    return 2;
                }
            },
            other => {
                eprintln!("srv9: unknown arg {}", other);
                return 2;
            }
        }
    }
    let root = match root {
        Some(r) => r,
        None => {
            eprintln!("srv9: --root required");
            return 2;
        }
    };
    if !Path::new(&root).is_dir() {
        eprintln!("srv9: {} is not a directory", root);
        return 2;
    }
    let listener = match TcpListener::bind((host.as_str(), port)) {
        Ok(l) => l,
        Err(e) => {
            eprintln!("srv9: bind {}:{}: {}", host, port, e);
            return 1;
        }
    };
    eprintln!("{}", serving_line(Path::new(&root), &host, port, &writable));
    match serve(listener, Path::new(&root), &writable) {
        Ok(()) => 0,
        Err(e) => {
            eprintln!("srv9: serve: {}", e);
            1
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::fs;
    use std::io::Read;
    use std::net::TcpStream;
    use std::time::{Duration, Instant};

    // ---- fixture tree + raw 9P test client --------------------------------

    fn fixture() -> (tempfile_like::TempDir, PathBuf) {
        let td = tempfile_like::TempDir::new();
        let root = td.path().join("root");
        fs::create_dir_all(root.join("dir")).unwrap();
        fs::create_dir_all(root.join("tmp")).unwrap();
        fs::write(root.join("hello.txt"), b"hello aarch64 harvey\n").unwrap();
        fs::write(root.join(".hidden"), b"dot\n").unwrap();
        fs::write(root.join("dir/a.txt"), b"aaa\n").unwrap();
        fs::write(root.join("dir/b.txt"), b"bbb\n").unwrap();
        fs::write(root.join("dir/.dotfile"), b"d\n").unwrap();
        (td, root)
    }

    /// minimal tempdir helper (std-only — no tempfile crate per D-02)
    mod tempfile_like {
        use std::path::{Path, PathBuf};
        pub struct TempDir(PathBuf);
        impl TempDir {
            pub fn new() -> TempDir {
                let mut p = std::env::temp_dir();
                let n = format!(
                    "srv9test.{}.{}",
                    std::process::id(),
                    std::time::SystemTime::now()
                        .duration_since(std::time::UNIX_EPOCH)
                        .unwrap()
                        .as_nanos()
                );
                p.push(n);
                std::fs::create_dir_all(&p).unwrap();
                TempDir(p)
            }
            pub fn path(&self) -> &Path {
                &self.0
            }
        }
        impl Drop for TempDir {
            fn drop(&mut self) {
                let _ = std::fs::remove_dir_all(&self.0);
            }
        }
    }

    fn start_server(root: &Path, writable: &[String]) -> String {
        let listener = TcpListener::bind("127.0.0.1:0").unwrap();
        let addr = listener.local_addr().unwrap().to_string();
        let root = root.to_path_buf();
        let writable = writable.to_vec();
        thread::spawn(move || {
            let _ = serve(listener, &root, &writable);
        });
        // give the accept loop a moment to enter
        std::thread::sleep(Duration::from_millis(50));
        addr
    }

    struct Client {
        s: TcpStream,
        tag: u16,
    }

    impl Client {
        fn connect(addr: &str) -> Client {
            let deadline = Instant::now() + Duration::from_secs(5);
            loop {
                match TcpStream::connect(addr) {
                    Ok(s) => {
                        s.set_read_timeout(Some(Duration::from_secs(5))).unwrap();
                        return Client { s, tag: 0 };
                    }
                    Err(_) if Instant::now() < deadline => std::thread::sleep(Duration::from_millis(50)),
                    Err(e) => panic!("connect {}: {}", addr, e),
                }
            }
        }
        fn rpc(&mut self, ty: u8, payload: &[u8]) -> (u8, Vec<u8>) {
            self.tag = self.tag.wrapping_add(1);
            let mut out = Vec::new();
            out.extend_from_slice(&p32(4 + 1 + 2 + payload.len() as u32));
            out.push(ty);
            out.extend_from_slice(&p16(self.tag));
            out.extend_from_slice(payload);
            self.s.write_all(&out).unwrap();
            let mut hdr = [0u8; 4];
            self.s.read_exact(&mut hdr).unwrap();
            let size = u32::from_le_bytes(hdr) as usize;
            let mut rest = vec![0u8; size - 4];
            self.s.read_exact(&mut rest).unwrap();
            (rest[0], rest[3..].to_vec())
        }
        fn version(&mut self) -> (u8, Vec<u8>) {
            let mut p = Vec::new();
            p.extend_from_slice(&p32(MAXMSIZE));
            p.extend_from_slice(&pstr(VERSION));
            self.rpc(TVERSION, &p)
        }
        fn attach(&mut self, fid: u32) -> (u8, Vec<u8>) {
            let mut p = Vec::new();
            p.extend_from_slice(&p32(fid));
            p.extend_from_slice(&p32(0xFFFF_FFFF)); // afid NOFID
            p.extend_from_slice(&pstr(b"glenda"));
            p.extend_from_slice(&pstr(b""));
            self.rpc(TATTACH, &p)
        }
        fn walk(&mut self, fid: u32, newfid: u32, names: &[&str]) -> (u8, Vec<u8>) {
            let mut p = Vec::new();
            p.extend_from_slice(&p32(fid));
            p.extend_from_slice(&p32(newfid));
            p.extend_from_slice(&p16(names.len() as u16));
            for n in names {
                p.extend_from_slice(&pstr(n.as_bytes()));
            }
            self.rpc(TWALK, &p)
        }
        fn open(&mut self, fid: u32) -> (u8, Vec<u8>) {
            self.rpc(TOPEN, &p32(fid))
        }
        fn read(&mut self, fid: u32, offset: u64, count: u32) -> (u8, Vec<u8>) {
            let mut p = Vec::new();
            p.extend_from_slice(&p32(fid));
            p.extend_from_slice(&p64(offset));
            p.extend_from_slice(&p32(count));
            self.rpc(TREAD, &p)
        }
        fn stat(&mut self, fid: u32) -> (u8, Vec<u8>) {
            self.rpc(TSTAT, &p32(fid))
        }
        fn clunk(&mut self, fid: u32) -> (u8, Vec<u8>) {
            self.rpc(TCLUNK, &p32(fid))
        }
        fn create(&mut self, fid: u32, name: &str, perm: u32) -> (u8, Vec<u8>) {
            let mut p = Vec::new();
            p.extend_from_slice(&p32(fid));
            p.extend_from_slice(&pstr(name.as_bytes()));
            p.extend_from_slice(&p32(perm));
            p.push(0); // mode
            self.rpc(TCREATE, &p)
        }
        fn write(&mut self, fid: u32, offset: u64, data: &[u8]) -> (u8, Vec<u8>) {
            let mut p = Vec::new();
            p.extend_from_slice(&p32(fid));
            p.extend_from_slice(&p64(offset));
            p.extend_from_slice(&p32(data.len() as u32));
            p.extend_from_slice(data);
            self.rpc(TWRITE, &p)
        }
        fn remove(&mut self, fid: u32) -> (u8, Vec<u8>) {
            self.rpc(TREMOVE, &p32(fid))
        }
        fn wstat_rename(&mut self, fid: u32, newname: &str) -> (u8, Vec<u8>) {
            // stat body: type(2) dev(4) qid(13) mode(4) atime(4) mtime(4)
            // length(8) then pstr name — all-null except name (mv idiom)
            let mut body = vec![0u8; 39];
            body.extend_from_slice(&pstr(newname.as_bytes()));
            let mut p = Vec::new();
            p.extend_from_slice(&p32(fid));
            p.extend_from_slice(&p16(body.len() as u16));
            p.extend_from_slice(&body);
            self.rpc(TWSTAT, &p)
        }
    }

    fn rerror_string(payload: &[u8]) -> String {
        let n = u16::from_le_bytes([payload[0], payload[1]]) as usize;
        String::from_utf8_lossy(&payload[2..2 + n]).into_owned()
    }

    /// parse a dir read buffer into entry names (skips 2-byte size prefix
    /// per entry; name follows the fixed 39-byte stat body)
    fn dir_names(mut buf: &[u8]) -> Vec<String> {
        let mut names = Vec::new();
        while buf.len() >= 2 {
            let sz = u16::from_le_bytes([buf[0], buf[1]]) as usize;
            let ent = &buf[2..2 + sz];
            let noff = 39;
            let nlen = u16::from_le_bytes([ent[noff], ent[noff + 1]]) as usize;
            names.push(String::from_utf8_lossy(&ent[noff + 2..noff + 2 + nlen]).into_owned());
            buf = &buf[2 + sz..];
        }
        names
    }

    fn stat_name_mode(payload: &[u8]) -> (String, u32) {
        // Rstat payload: p16(len) + stat-bytes; stat-bytes: p16(body-len) + body
        let sb = &payload[2..];
        let body = &sb[2..];
        let mode = u32::from_le_bytes([body[19], body[20], body[21], body[22]]);
        let nlen = u16::from_le_bytes([body[39], body[40]]) as usize;
        let name = String::from_utf8_lossy(&body[41..41 + nlen]).into_owned();
        (name, mode)
    }

    /// qid.vers out of an Rstat payload (body offset 2+4+1 = 7)
    fn stat_vers(payload: &[u8]) -> u32 {
        let sb = &payload[2..];
        let body = &sb[2..];
        u32::from_le_bytes([body[7], body[8], body[9], body[10]])
    }

    // ---- read-only conversation (the boot path's exact shape) -------------

    #[test]
    fn version_auth_attach_walk_open_read_stat_clunk() {
        let (_td, root) = fixture();
        let addr = start_server(&root, &[]);
        let mut c = Client::connect(&addr);

        let (t, p) = c.version();
        assert_eq!(t, RVERSION, "Tversion must answer Rversion");
        assert_eq!(&p[..4], &p32(MAXMSIZE));
        assert_eq!(&p[4..], &pstr(VERSION));

        let (t, p) = c.rpc(TAUTH, &pstr(b"glenda"));
        assert_eq!(t, RERROR, "Tauth must Rerror");
        assert_eq!(rerror_string(&p), "authentication not required");

        let (t, p) = c.attach(1);
        assert_eq!(t, RATTACH);
        assert_eq!(p[0], QTDIR, "root attach qid is a dir");

        let (t, _p) = c.walk(1, 2, &["hello.txt"]);
        assert_eq!(t, RWALK, "walk to hello.txt");
        let (t, p) = c.open(2);
        assert_eq!(t, ROPEN);
        assert_eq!(p[0] & QTDIR, 0, "hello.txt is not a dir");

        let (t, p) = c.read(2, 0, 4096);
        assert_eq!(t, RREAD);
        let n = u32::from_le_bytes([p[0], p[1], p[2], p[3]]) as usize;
        assert_eq!(&p[4..4 + n], b"hello aarch64 harvey\n");

        // partial read: offset into the file
        let (t, p) = c.read(2, 6, 7);
        assert_eq!(t, RREAD);
        let n = u32::from_le_bytes([p[0], p[1], p[2], p[3]]) as usize;
        assert_eq!(&p[4..4 + n], b"aarch64");

        let (t, p) = c.stat(2);
        assert_eq!(t, RSTAT);
        let (name, mode) = stat_name_mode(&p);
        assert_eq!(name, "hello.txt");
        assert_eq!(mode, 0o555, "read-only file mode");

        let (t, _p) = c.clunk(2);
        assert_eq!(t, RCLUNK);
    }

    #[test]
    fn directory_listing_sorted_dotfree_whole_entries() {
        let (_td, root) = fixture();
        let addr = start_server(&root, &[]);
        let mut c = Client::connect(&addr);
        c.version();
        c.attach(1);

        let (t, _p) = c.walk(1, 2, &["dir"]);
        assert_eq!(t, RWALK);
        let (t, _p) = c.open(2);
        assert_eq!(t, ROPEN);

        let (t, p) = c.read(2, 0, 65536);
        assert_eq!(t, RREAD);
        let n = u32::from_le_bytes([p[0], p[1], p[2], p[3]]) as usize;
        let names = dir_names(&p[4..4 + n]);
        assert_eq!(names, vec!["a.txt", "b.txt"], "sorted, dotfiles skipped");

        // whole-entry discipline: a count smaller than one entry yields an
        // empty read (the client retries with a sane msize)
        let (t, p) = c.read(2, 0, 4);
        assert_eq!(t, RREAD);
        let n = u32::from_le_bytes([p[0], p[1], p[2], p[3]]) as usize;
        assert_eq!(n, 0, "partial entry is never returned");
    }

    #[test]
    fn walk_confinement_and_missing() {
        let (_td, root) = fixture();
        let addr = start_server(&root, &[]);
        let mut c = Client::connect(&addr);
        c.version();
        c.attach(1);

        // '..' at the root is clamped — never escapes the served tree
        let (t, p) = c.walk(1, 2, &["..", ".."]);
        assert_eq!(t, RWALK, "walk ../.. from root stays in-tree");
        let nw = u16::from_le_bytes([p[0], p[1]]);
        assert_eq!(nw, 2);
        assert_eq!(p[2] & QTDIR, QTDIR, "still a dir (the root)");

        // walking to a missing name Rerrors
        let (t, p) = c.walk(1, 3, &["no-such-file"]);
        assert_eq!(t, RERROR);
        assert_eq!(rerror_string(&p), "file does not exist");
    }

    #[test]
    fn writable_prefix_crud_and_vers_bumps() {
        let (_td, root) = fixture();
        let addr = start_server(&root, &["/tmp".to_string()]);
        let mut c = Client::connect(&addr);
        c.version();
        c.attach(1);

        // create under /tmp (writable)
        let (t, _p) = c.walk(1, 10, &["tmp"]);
        assert_eq!(t, RWALK);
        let (t, p) = c.create(10, "scratch.txt", 0o666);
        assert_eq!(t, RCREATE, "create under writable prefix");
        assert_eq!(p[0] & QTDIR, 0);

        let (t, p) = c.write(10, 0, b"scratch data\n");
        assert_eq!(t, RWRITE);
        assert_eq!(u32::from_le_bytes([p[0], p[1], p[2], p[3]]), 13);

        // stat reports the honest writable mode (0666)
        let (t, p) = c.stat(10);
        assert_eq!(t, RSTAT);
        let (_n, mode) = stat_name_mode(&p);
        assert_eq!(mode, 0o666);

        // qid.vers bumps across mutations
        let vers1 = {
            let (_t, p) = c.stat(10);
            stat_vers(&p)
        };
        let (t, _p) = c.write(10, 13, b"more\n");
        assert_eq!(t, RWRITE);
        let vers2 = {
            let (_t, p) = c.stat(10);
            stat_vers(&p)
        };
        assert!(vers2 > vers1, "qid.vers bumped across mutation");

        // Twstat rename — and IN-05: rename over an EXISTING target deletes it
        let (t, _p) = c.walk(1, 11, &["tmp"]);
        assert_eq!(t, RWALK);
        let (t, _p) = c.create(11, "target.txt", 0o666);
        assert_eq!(t, RCREATE);
        let (t, _p) = c.wstat_rename(10, "target.txt");
        assert_eq!(t, RWSTAT, "rename over existing target (target deleted first)");

        let (t, p) = c.read(10, 0, 4096);
        assert_eq!(t, RREAD);
        let n = u32::from_le_bytes([p[0], p[1], p[2], p[3]]) as usize;
        assert_eq!(&p[4..4 + n], b"scratch data\nmore\n");

        let (t, _p) = c.remove(10);
        assert_eq!(t, RREMOVE);

        // ops outside the writable prefix Rerror 'read only'
        let (t, _p) = c.walk(1, 20, &["dir"]);
        assert_eq!(t, RWALK);
        let (t, p) = c.create(20, "nope.txt", 0o666);
        assert_eq!(t, RERROR);
        assert_eq!(rerror_string(&p), "read only");
        let (t, _p) = c.walk(1, 21, &["hello.txt"]);
        assert_eq!(t, RWALK);
        let (t, p) = c.write(21, 0, b"x");
        assert_eq!(t, RERROR);
        assert_eq!(rerror_string(&p), "read only");
        let (t, p) = c.remove(21);
        assert_eq!(t, RERROR);
        assert_eq!(rerror_string(&p), "read only");
    }

    #[test]
    fn malformed_frames_drop_the_connection() {
        let (_td, root) = fixture();
        let addr = start_server(&root, &[]);
        let mut c = Client::connect(&addr);
        c.version();
        // size < 7 is a protocol violation: the server drops the conn
        c.s.write_all(&p32(3)).unwrap();
        let mut buf = [0u8; 16];
        let mut got_eof = false;
        let deadline = Instant::now() + Duration::from_secs(5);
        while Instant::now() < deadline {
            match c.s.read(&mut buf) {
                Ok(0) => {
                    got_eof = true;
                    break;
                }
                Ok(_) => continue,
                Err(e) if e.kind() == std::io::ErrorKind::WouldBlock => {
                    std::thread::sleep(Duration::from_millis(50))
                }
                Err(_) => {
                    got_eof = true;
                    break;
                }
            }
        }
        assert!(got_eof, "server must drop the connection on a bad frame");

        // oversized size likewise
        let mut c2 = Client::connect(&addr);
        c2.version();
        c2.s.write_all(&p32(MAXMSIZE + 25)).unwrap();
        let mut got_eof2 = false;
        let deadline = Instant::now() + Duration::from_secs(5);
        while Instant::now() < deadline {
            match c2.s.read(&mut buf) {
                Ok(0) => {
                    got_eof2 = true;
                    break;
                }
                Ok(_) => continue,
                Err(e) if e.kind() == std::io::ErrorKind::WouldBlock => {
                    std::thread::sleep(Duration::from_millis(50))
                }
                Err(_) => {
                    got_eof2 = true;
                    break;
                }
            }
        }
        assert!(got_eof2, "server must drop the connection on an oversized frame");
    }

    #[test]
    fn serving_line_byte_exact() {
        let root = Path::new("/some/root");
        assert_eq!(
            serving_line(root, "127.0.0.1", 1564, &[]),
            format!("srv9: serving {} on 127.0.0.1:1564 (9P2000, read-only)", realpath(root).display())
        );
        assert_eq!(
            serving_line(root, "127.0.0.1", 1564, &["/tmp".to_string(), "/usr/glenda/tmp".to_string()]),
            format!(
                "srv9: serving {} on 127.0.0.1:1564 (9P2000, writable prefixes: /tmp, /usr/glenda/tmp)",
                realpath(root).display()
            )
        );
    }

    #[test]
    fn usage_and_arg_errors_exit_2() {
        // run() touches the real process stderr; assert only the exit codes
        assert_eq!(run(&[]), 2);
        assert_eq!(run(&["nosuch".to_string()]), 2);
        assert_eq!(
            run(&["serve".to_string(), "--bogus".to_string(), "x".to_string()]),
            2
        );
        assert_eq!(run(&["serve".to_string()]), 2); // --root required
        assert_eq!(
            run(&[
                "serve".to_string(),
                "--root".to_string(),
                "/definitely/not/a/dir".to_string()
            ]),
            2
        );
    }
}
