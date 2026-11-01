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
# usage: srv9.py serve --root DIR --host 127.0.0.1 --port 1564
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
Tcreate = 114
Tread, Rread = 116, 117
Twrite = 118
Tclunk, Rclunk = 120, 121
Tremove = 122
Tstat, Rstat = 124, 125
Twstat = 126

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
    def __init__(self, root, logf=None):
        self.root = os.path.realpath(root)
        self.lock = threading.Lock()
        self.fids = {}            # per-connection fid table
        self.logf = logf

    def log(self, msg):
        if self.logf:
            self.logf.write(msg + "\n")
            self.logf.flush()

    def qidfor(self, path):
        try:
            st = os.stat(path)
            ino = st.st_ino & 0xFFFFFFFFFFFFFFFF
            if ino == 0:
                ino = abs(hash(path)) & 0xFFFFFFFFFFFFFFFF
            if statmod.S_ISDIR(st.st_mode):
                return Qid(QTDIR, ino)
            return Qid(0, ino)
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

        if ctype in (Tcreate, Twrite, Tremove, Twstat):
            raise P9Error("read only")

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


def serve(root, host, port, logf=None):
    if not os.path.isdir(root):
        sys.stderr.write("srv9: %s is not a directory\n" % root)
        return 2
    srv = Srv(root, logf=logf)
    lsock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    lsock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    lsock.bind((host, port))
    lsock.listen(16)
    sys.stderr.write("srv9: serving %s on %s:%d (9P2000, read-only)\n"
                     % (os.path.realpath(root), host, port))
    sys.stderr.flush()
    while True:
        conn, addr = lsock.accept()
        t = threading.Thread(target=srv.serveconn, args=(conn, addr), daemon=True)
        t.start()


def main(argv):
    if len(argv) < 2 or argv[1] != "serve":
        sys.stderr.write("usage: srv9.py serve --root DIR [--host H] [--port P]\n")
        return 2
    root = None
    host = "127.0.0.1"
    port = 1564
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
        else:
            sys.stderr.write("srv9: unknown arg %s\n" % argv[i])
            return 2
    if root is None:
        sys.stderr.write("srv9: --root required\n")
        return 2
    return serve(root, host, port)


if __name__ == "__main__":
    sys.exit(main(sys.argv) or 0)
