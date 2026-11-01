#!/usr/bin/env python3
# srv9.py — minimal read-only 9P2000 file server (build/aarch64 harness).
#
# Serves a host directory tree over TCP so the 9front donor kernel
# (CONF=qemu, built in-donor-tree by Harvey's 7a/7c/7l) can boot to an
# rc shell: the guest runs bootrc with bootargs=tcp and mounts this
# tree as its root via `srv -q tcp!$fs!564 boot` + `mount /srv/boot /root`.
#
# Why this exists (plan 02-04 deviation record): the stock donor boot
# cannot reach a shell from the embedded bootfs.paq alone — bootrc
# requires a /srv/boot connection, and the `local!` paqfs path is broken
# upstream (bootfs() calls `paqfs -s -f`, but donor paqfs has no -f flag;
# verified by reading sys/src/cmd/paqfs/paqfs.c ARGBEGIN at the pin).
# 9P-over-tcp is the donor's own tested remote-root path (connecttcp),
# needs zero donor modification, and doubles as the binary-delivery
# channel for plans 02-05/02-07 (drop binaries in the served root, run
# them from the rc shell over the serial console).
#
# Protocol coverage (read-only): Tversion, Tauth (Rerror "no
# authentication required" — amount(2) then proceeds without afid),
# Tattach, Twalk, Topen, Tread (files and directories), Tstat, Tclunk,
# Tflush.  Tcreate/Twrite/Tremove/Twstat get Rerror "read only".
# Wire format verified against Harvey's sys/src/libc/9sys/convD2M.c,
# convS2M.c and sys/include/fcall.h (all fields little-endian).
#
# Opt-in writable scratch (plan 02-07 Task 2): --writable-prefix PATH
# (repeatable) lifts the read-only Rerror for paths under PREFIX
# (guest-visible absolute prefixes, e.g. /tmp and /usr/glenda/tmp —
# the donor's lib/namespace binds one onto the other with -c, so
# covered either way). The subset-exec.sh gate needs a writable
# hierarchical scratch for its mkdir/cp/mv/rm round-trip; the kernel
# permits creates there via the bind's MCREATE flag (chan.c createdir
# has no mode check), so only the server had to agree. Paths under a
# writable prefix report 0777/0666 modes (dirstat honesty); qid.vers
# bumps on every mutation so a -C (cached) mount never serves a stale
# listing. Default (no flag) is byte-identical read-only behavior —
# boot-9qemu.sh and run-gate.sh are unaffected.
#
# usage: srv9.py serve --root DIR --host 127.0.0.1 --port 1564
#        [--writable-prefix /tmp --writable-prefix /usr/glenda/tmp]
#        (1564 not 564: 564 is privileged on macOS/Linux; qemu user-net
#        guestfwd maps guest 10.0.2.100:564 to host 127.0.0.1:1564)

import os
import socket
import stat as statmod
import struct
import sys
import threading

VERSION = b"9P2000"
MAXMSIZE = 65536

# message types (sys/include/fcall.h)
Tversion, Rversion = 100, 101
Tauth, Rauth = 102, 103
Tattach, Rattach = 104, 105
Rerror = 107
Tflush, Rflush = 108, 109
Twalk, Rwalk = 110, 111
Topen, Ropen = 112, 113
Tcreate, Rcreate = 114, 115
Tread, Rread = 116, 117
Twrite, Rwrite = 118, 119
Tclunk, Rclunk = 120, 121
Tremove, Rremove = 122, 123
Tstat, Rstat = 124, 125
Twstat, Rwstat = 126, 127

QTDIR = 0x80
DMDIR = 0x80000000
NOFID = 0xFFFFFFFF


def p16(v): return struct.pack("<H", v)
def p32(v): return struct.pack("<I", v)
def p64(v): return struct.pack("<Q", v)


def pstr(s):
    if isinstance(s, str):
        s = s.encode("utf-8")
    return p16(len(s)) + s


class Qid:
    __slots__ = ("type", "vers", "path")

    def __init__(self, t, path):
        self.type = t
        self.vers = 0
        self.path = path

    def encode(self):
        return struct.pack("<BIQ", self.type, self.vers, self.path & 0xFFFFFFFFFFFFFFFF)


class Fid:
    __slots__ = ("path", "open", "dirbuf", "dirents")

    def __init__(self, path):
        self.path = path          # absolute host path
        self.open = False
        self.dirbuf = None        # materialized dir listing bytes
        self.dirents = None       # list of entry end-offsets


class Srv:
    def __init__(self, root, logf=None, writable=()):
        self.root = os.path.realpath(root)
        self.lock = threading.Lock()
        self.fids = {}            # per-connection fid table
        self.logf = logf
        # writable scratch prefixes (guest-visible, e.g. "/tmp"), stored
        # as host-side realpaths
        self.wr = [os.path.realpath(os.path.join(self.root, p.lstrip("/")))
                   for p in writable]
        self.vmap = {}            # host path -> qid version (bumps on mutation)

    def writable(self, path):
        real = os.path.realpath(path)
        for p in self.wr:
            if real == p or real.startswith(p + os.sep):
                return True
        return False

    def bump(self, path):
        real = os.path.realpath(path)
        self.vmap[real] = self.vmap.get(real, 0) + 1

    def dropdircache(self):
        # a mutation invalidated cached directory listings on every fid
        with self.lock:
            for f in self.fids.values():
                f.dirbuf = None
                f.dirents = None

    def log(self, msg):
        if self.logf:
            self.logf.write(msg + "\n")
            self.logf.flush()

    def qidfor(self, path):
        real = os.path.realpath(path)
        vers = self.vmap.get(real, 0)
        try:
            st = os.stat(path)
            ino = st.st_ino & 0xFFFFFFFFFFFFFFFF
            if ino == 0:
                ino = abs(hash(path)) & 0xFFFFFFFFFFFFFFFF
            if statmod.S_ISDIR(st.st_mode):
                q = Qid(QTDIR, ino)
                q.vers = vers
                return q
            q = Qid(0, ino)
            q.vers = vers
            return q
        except OSError:
            return Qid(0, abs(hash(path)) & 0xFFFFFFFFFFFFFFFF)

    def resolve(self, fid):
        f = self.fids.get(fid)
        if f is None:
            raise P9Error("unknown fid")
        return f

    def statbytes(self, path, name=None):
        st = os.lstat(path)
        if name is None:
            name = os.path.basename(path) or "/"
        isdir = statmod.S_ISDIR(st.st_mode)
        q = self.qidfor(path)
        if self.writable(path):
            mode = (DMDIR | 0o777) if isdir else 0o666
        else:
            mode = (DMDIR | 0o555) if isdir else 0o555
        length = 0 if isdir else st.st_size
        mtime = int(st.st_mtime) & 0xFFFFFFFF
        body = b"".join([
            p16(0),                    # type (dev type — unused)
            p32(0),                    # dev
            q.encode(),
            p32(mode),
            p32(mtime),                # atime
            p32(mtime),                # mtime
            p64(length),
            pstr(name),
            pstr("glenda"),            # uid
            pstr("glenda"),            # gid
            pstr("glenda"),            # muid
        ])
        return p16(len(body)) + body

    def dirlisting(self, f):
        if f.dirbuf is not None:
            return
        ents = []
        ends = []
        off = 0
        try:
            names = sorted(os.listdir(f.path))
        except OSError:
            names = []
        for n in names:
            if n.startswith("."):
                continue
            b = self.statbytes(os.path.join(f.path, n), name=n)
            ents.append(b)
            off += len(b)
            ends.append(off)
        f.dirbuf = b"".join(ents)
        f.dirents = ends

    # ---- message handlers -------------------------------------------------

    def handle(self, ctype, tag, p):
        """Return reply type + payload bytes."""
        if ctype == Tversion:
            msize = struct.unpack_from("<I", p, 0)[0]
            # version string follows; we speak 9P2000 only
            with self.lock:
                self.fids.clear()
            return Rversion, p32(min(msize, MAXMSIZE)) + pstr(VERSION)

        if ctype == Tauth:
            raise P9Error("authentication not required")

        if ctype == Tflush:
            return Rflush, b""

        if ctype == Tattach:
            fid, afid = struct.unpack_from("<II", p, 0)
            # uname, aname strings after; we serve the root regardless
            with self.lock:
                self.fids[fid] = Fid(self.root)
            return Rattach, self.qidfor(self.root).encode()

        if ctype == Twalk:
            fid, newfid, nw = struct.unpack_from("<IIH", p, 0)
            off = struct.calcsize("<IIH")
            names = []
            for _ in range(nw):
                ln = struct.unpack_from("<H", p, off)[0]
                off += 2
                names.append(p[off:off + ln].decode("utf-8", "replace"))
                off += ln
            cur = self.resolve(fid).path
            qids = []
            ok = True
            for n in names:
                if n == ".":
                    pass
                elif n == "..":
                    parent = os.path.dirname(cur)
                    if parent.startswith(self.root):
                        cur = parent
                else:
                    nxt = os.path.join(cur, n)
                    real = os.path.realpath(nxt)
                    if not (real == self.root or real.startswith(self.root + os.sep)):
                        ok = False
                        break
                    if not os.path.exists(nxt):
                        ok = False
                        break
                    cur = nxt
                qids.append(self.qidfor(cur).encode())
            if not ok:
                if not qids:
                    raise P9Error("file does not exist")
                # partial walk
                return Rwalk, p16(len(qids)) + b"".join(qids)
            with self.lock:
                self.fids[newfid] = Fid(cur)
            return Rwalk, p16(len(qids)) + b"".join(qids)

        if ctype == Topen:
            fid = struct.unpack_from("<I", p, 0)[0]
            f = self.resolve(fid)
            if not os.path.exists(f.path):
                raise P9Error("file does not exist")
            f.open = True
            f.dirbuf = None
            return Ropen, self.qidfor(f.path).encode() + p32(0)

        if ctype == Tread:
            fid = struct.unpack_from("<I", p, 0)[0]
            offset = struct.unpack_from("<Q", p, 4)[0]
            count = struct.unpack_from("<I", p, 12)[0]
            f = self.resolve(fid)
            if os.path.isdir(f.path):
                self.dirlisting(f)
                if offset >= len(f.dirbuf):
                    return Rread, p32(0)
                # return only whole entries: largest set of entries in
                # [offset, offset+count)
                end = offset + count
                n = 0
                for e in f.dirents:
                    if e <= offset:
                        continue
                    if e > end:
                        break
                    n = e
                if n == 0:
                    # single entry larger than count cannot happen with
                    # a sane msize; return empty (client retries/EOF)
                    return Rread, p32(0)
                return Rread, p32(n - offset) + f.dirbuf[offset:n]
            try:
                with open(f.path, "rb") as fp:
                    fp.seek(offset)
                    data = fp.read(count)
            except OSError:
                raise P9Error("i/o error")
            return Rread, p32(len(data)) + data

        if ctype == Tstat:
            fid = struct.unpack_from("<I", p, 0)[0]
            f = self.resolve(fid)
            if not os.path.exists(f.path):
                raise P9Error("file does not exist")
            sb = self.statbytes(f.path)
            return Rstat, p16(len(sb)) + sb

        if ctype == Tclunk:
            fid = struct.unpack_from("<I", p, 0)[0]
            with self.lock:
                self.fids.pop(fid, None)
            return Rclunk, b""

        if ctype == Tcreate:
            fid = struct.unpack_from("<I", p, 0)[0]
            nlen = struct.unpack_from("<H", p, 4)[0]
            name = p[6:6 + nlen].decode("utf-8", "replace")
            perm = struct.unpack_from("<I", p, 6 + nlen)[0]
            f = self.resolve(fid)
            if not self.writable(f.path):
                raise P9Error("read only")
            if not os.path.isdir(f.path):
                raise P9Error("not a directory")
            if name in ("", ".", "..") or "/" in name:
                raise P9Error("bad name in create")
            npath = os.path.join(f.path, name)
            try:
                if perm & DMDIR:
                    os.mkdir(npath)
                else:
                    fd = os.open(npath, os.O_CREAT | os.O_EXCL | os.O_WRONLY, 0o666)
                    os.close(fd)
            except FileExistsError:
                raise P9Error("file exists")
            except OSError:
                raise P9Error("i/o error")
            self.bump(f.path)          # parent dir listing changed
            self.bump(npath)
            self.dropdircache()
            f.path = npath
            f.open = True
            f.dirbuf = None
            f.dirents = None
            return Rcreate, self.qidfor(npath).encode() + p32(0)

        if ctype == Twrite:
            fid = struct.unpack_from("<I", p, 0)[0]
            offset = struct.unpack_from("<Q", p, 4)[0]
            count = struct.unpack_from("<I", p, 12)[0]
            data = p[16:16 + count]
            f = self.resolve(fid)
            if not self.writable(f.path):
                raise P9Error("read only")
            try:
                with open(f.path, "r+b") as fp:
                    fp.seek(offset)
                    fp.write(data)
            except OSError:
                raise P9Error("i/o error")
            self.bump(f.path)
            return Rwrite, p32(len(data))

        if ctype == Tremove:
            fid = struct.unpack_from("<I", p, 0)[0]
            f = self.resolve(fid)
            if not self.writable(f.path):
                raise P9Error("read only")
            try:
                if os.path.isdir(f.path):
                    os.rmdir(f.path)
                else:
                    os.remove(f.path)
            except OSError:
                raise P9Error("i/o error")
            self.bump(os.path.dirname(f.path))
            self.dropdircache()
            with self.lock:
                self.fids.pop(fid, None)
            return Rremove, b""

        if ctype == Twstat:
            # mv(1) renames via dirwstat with only the name field set
            # (nulldir + null.name); apply exactly that and no-op the
            # rest. Stat body: type(2) dev(4) qid(13) mode(4) atime(4)
            # mtime(4) length(8) then pstr name — name begins at offset
            # fid(4)+size(2)+39 = 45.
            fid = struct.unpack_from("<I", p, 0)[0]
            f = self.resolve(fid)
            if not self.writable(f.path):
                raise P9Error("read only")
            noff = 4 + 2 + 39
            if len(p) >= noff + 2:
                nlen = struct.unpack_from("<H", p, noff)[0]
                name = p[noff + 2:noff + 2 + nlen].decode("utf-8", "replace")
            else:
                name = ""
            if name and name not in (".", "..") and "/" not in name:
                parent = os.path.dirname(f.path)
                npath = os.path.join(parent, name)
                if not self.writable(npath):
                    raise P9Error("read only")
                try:
                    if os.path.exists(npath):
                        if os.path.isdir(npath):
                            os.rmdir(npath)
                        else:
                            os.remove(npath)
                    os.rename(f.path, npath)
                except OSError:
                    raise P9Error("i/o error")
                f.path = npath
                self.bump(parent)
                self.bump(npath)
                self.dropdircache()
            return Rwstat, b""

        raise P9Error("unknown message type %d" % ctype)

    def serveconn(self, conn, addr):
        self.logf and self.log("connect %s" % (addr,))
        try:
            while True:
                hdr = recvn(conn, 4)
                if hdr is None:
                    break
                size = struct.unpack("<I", hdr)[0]
                if size < 7 or size > MAXMSIZE + 24:
                    break
                rest = recvn(conn, size - 4)
                if rest is None:
                    break
                ctype = rest[0]
                tag = struct.unpack_from("<H", rest, 1)[0]
                payload = rest[3:]
                try:
                    rtype, rpayload = self.handle(ctype, tag, payload)
                except P9Error as e:
                    rtype, rpayload = Rerror, pstr(str(e))
                except Exception as e:
                    rtype, rpayload = Rerror, pstr("internal error: %s" % e)
                out = p32(4 + 1 + 2 + len(rpayload)) + bytes([rtype]) + p16(tag) + rpayload
                conn.sendall(out)
        except (ConnectionError, OSError):
            pass
        finally:
            with self.lock:
                self.fids.clear()
            try:
                conn.close()
            except OSError:
                pass
        self.logf and self.log("disconnect %s" % (addr,))


class P9Error(Exception):
    pass


def recvn(conn, n):
    buf = b""
    while len(buf) < n:
        chunk = conn.recv(n - len(buf))
        if not chunk:
            return None
        buf += chunk
    return buf


def serve(root, host, port, logf=None, writable=()):
    if not os.path.isdir(root):
        sys.stderr.write("srv9: %s is not a directory\n" % root)
        return 2
    srv = Srv(root, logf=logf, writable=writable)
    lsock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    lsock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    lsock.bind((host, port))
    lsock.listen(16)
    mode = "read-only" if not writable else "writable prefixes: %s" % ", ".join(writable)
    sys.stderr.write("srv9: serving %s on %s:%d (9P2000, %s)\n"
                     % (os.path.realpath(root), host, port, mode))
    sys.stderr.flush()
    while True:
        conn, addr = lsock.accept()
        t = threading.Thread(target=srv.serveconn, args=(conn, addr), daemon=True)
        t.start()


def main(argv):
    if len(argv) < 2 or argv[1] != "serve":
        sys.stderr.write("usage: srv9.py serve --root DIR [--host H] [--port P] [--writable-prefix PATH ...]\n")
        return 2
    root = None
    host = "127.0.0.1"
    port = 1564
    writable = []
    i = 2
    while i < len(argv):
        if argv[i] == "--root":
            root = argv[i + 1]
            i += 2
        elif argv[i] == "--host":
            host = argv[i + 1]
            i += 2
        elif argv[i] == "--port":
            port = int(argv[i + 1])
            i += 2
        elif argv[i] == "--writable-prefix":
            writable.append(argv[i + 1])
            i += 2
        else:
            sys.stderr.write("srv9: unknown arg %s\n" % argv[i])
            return 2
    if root is None:
        sys.stderr.write("srv9: --root required\n")
        return 2
    return serve(root, host, port, writable=writable)


if __name__ == "__main__":
    sys.exit(main(sys.argv) or 0)
