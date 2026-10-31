#!/usr/bin/env python3
# mkfs9.py — a host-side replacement for the donor's disk/mkfs, used by
# the 02-04 donor-kernel build (installed as disk/mkfs in the guest
# scratch bin by donor-ns-build.sh).
#
# Why this exists (02-04-SUMMARY deviation): the donor's mkfs.c is the
# right tool, but EVERY host build route for it is broken on a unix host:
#   * plan9port's libdisk rdproto mangles relative proto source paths
#     (/../boot/reboot.rc) — silently dropped bootrc/net.rc/local.rc
#     from the bootfs (lineage mismatch with 9front's libdisk);
#   * building the donor's own proto.c hits the host-unparseable
#     embedded `QLock;` in the donor's disk.h, and then plan9port lib9's
#     dirfwstat silently ignores nd.name (no rename), so mkfs's
#     temp+rename idiom leaves read-only __mkfstmp files and the next
#     copy in the same dir dies EACCES (reproduced on host and guest).
# plan9port's own unix mkfs.c shares the rename idiom — equally broken.
#
# So this implements the exact semantics the CONF=qemu boot needs from
# the pinned protos (bootfs.proto + disk.proto + devusb.proto):
#   disk/mkfs -aos / PROTOS   → print the source path of every non-dir
#                               entry (mk's prerequisite list)
#   disk/mkfs -s / -d DIR PROTOS → materialize the tree at DIR
# Proto grammar (per donor libdisk/proto.c + cmd/disk/mkfs.c):
#   indent (tab=8, space=1) tree; fields: name [mode owner group source]
#   `+` as a name → recursively copy the current source dir's contents
#   `$objtype` → environment expansion; `#` comment; blank skipped
#   missing source → warn to stderr, skip the entry's subtree
# Modes: explicit proto mode wins; otherwise the source's mode is
# preserved (the donor mkfs's group/other widening is cosmetic for a
# boot image and is NOT reproduced). Owners are not set (host defaults);
# mkpaqfs records the host's uid/gid strings in the paq — irrelevant to
# the kernel boot.
#
# Runs on python3 (guest: /usr/bin/python3). Not a general mkfs.

import os
import shutil
import sys


def cleanname(p):
    # Plan 9 cleanname(1): lexical . and .. resolution
    out = []
    for part in p.split("/"):
        if part in ("", "."):
            continue
        if part == "..":
            if out:
                out.pop()
            continue
        out.append(part)
    return ("/" if p.startswith("/") else "") + "/".join(out)


class Proto:
    def __init__(self, fname, oldroot):
        self.fname = fname
        self.oldroot = oldroot
        self.entries = []  # (depth, name, mode, source) — source=None means implicit

    def parse(self):
        with open(self.fname) as f:
            for line in f:
                line = line.rstrip("\n")
                if not line:
                    continue
                depth = 0
                i = 0
                while i < len(line) and line[i] in " \t":
                    depth += 8 if line[i] == "\t" else 1
                    i += 1
                body = line[i:]
                if not body or body.startswith("#"):
                    continue
                fields = body.split()
                name = fields[0]
                if name.startswith("$"):
                    name = os.environ.get(name[1:], "")
                    if not name:
                        sys.stderr.write("mkfs9: %s: can't read environment variable\n" % self.fname)
                        continue
                mode = None
                src = None
                rest = fields[1:]
                if rest and rest[0] not in ("-",) and all(c in "01234567dal" for c in rest[0]):
                    mode = rest[0]
                    rest = rest[1:]
                # fields: mode uid gid [source]; source is the 4th field overall
                if len(fields) >= 5:
                    src = fields[4]
                self.entries.append((depth, name, mode, src))
        return self


def sourcepath(oldroot, cwd, name, src):
    if src is None or src == "-":
        # implicit: oldroot + proto path
        return cleanname(oldroot + "/" + name)
    if src.startswith("/"):
        return cleanname(oldroot + src)
    # explicit relative: resolved against the cwd (the kernel dir)
    return cleanname(os.path.join(cwd, src))


def walk(protos, oldroot, dest=None, listonly=False):
    """Drive the proto entries; print sources (list mode) or materialize."""
    cwd = os.getcwd()
    for pr in protos:
        p = Proto(pr, oldroot).parse()
        # stack of (depth, proto_path, resolved_src, alive)
        stack = []
        for depth, name, mode, src in p.entries:
            while stack and stack[-1][0] >= depth:
                stack.pop()
            if stack and not stack[-1][3]:
                continue  # inside a skipped subtree
            if name == "+":
                # recurse: copy the current entry's source dir contents
                if not stack:
                    continue
                _, pp, spath, _ = stack[-1]
                if not os.path.isdir(spath):
                    sys.stderr.write("mkfs9: %s: can't recurse %s: not a directory\n"
                                     % (pr, spath))
                    continue
                for root, dirs, files in os.walk(spath):
                    for d in dirs:
                        sdir = os.path.join(root, d)
                        dd = os.path.join(dest, pp, os.path.relpath(sdir, spath)) if dest else None
                        if not listonly:
                            os.makedirs(dd, exist_ok=True)
                            shutil.copymode(sdir, dd)
                    for fn in files:
                        sfile = os.path.join(root, fn)
                        if listonly:
                            print(cleanname(sfile))
                        else:
                            dd = os.path.join(dest, pp, os.path.relpath(sfile, spath))
                            os.makedirs(os.path.dirname(dd), exist_ok=True)
                            shutil.copyfile(sfile, dd)
                            shutil.copymode(sfile, dd)
                continue
            pp = stack[-1][1] + "/" + name if stack else name
            spath = sourcepath(oldroot, cwd, pp, src)
            if os.path.isdir(spath):
                if dest is not None:
                    dd = os.path.join(dest, pp)
                    os.makedirs(dd, exist_ok=True)
                    if mode:
                        os.chmod(dd, int(mode.replace("d", "").replace("a", "").replace("l", ""), 8))
                    else:
                        shutil.copymode(spath, dd)
                stack.append((depth, pp, spath, True))
            elif os.path.exists(spath):
                if listonly:
                    print(cleanname(spath))
                else:
                    dd = os.path.join(dest, pp)
                    os.makedirs(os.path.dirname(dd), exist_ok=True)
                    shutil.copyfile(spath, dd)
                    if mode:
                        os.chmod(dd, int(mode.replace("d", "").replace("a", "").replace("l", ""), 8))
                    else:
                        shutil.copymode(spath, dd)
                stack.append((depth, pp, spath, True))
            else:
                sys.stderr.write("mkfs9: %s: can't stat file %s: No such file or directory\n"
                                 % (pr, spath))
                stack.append((depth, pp, spath, False))


def main(argv):
    listonly = False
    oldroot = "/"
    dest = None
    protos = []
    i = 1
    while i < len(argv):
        a = argv[i]
        if a.startswith("-") and len(a) > 1:
            # ARGBEGIN-style flag clustering: -aos == -a -o -s
            for c in a[1:]:
                if c == "a":
                    listonly = True
                elif c in ("o", "x", "p", "v", "D", "r", "U"):
                    pass
                elif c in ("s", "d"):
                    i += 1
                    if c == "s":
                        oldroot = argv[i]
                    else:
                        dest = argv[i]
                else:
                    sys.stderr.write("mkfs9: unsupported flag -%c\n" % c)
                    return 2
        else:
            protos.append(a)
        i += 1
    if not protos:
        sys.stderr.write("usage: mkfs9 [-a] [-s oldroot] [-d dest] proto ...\n")
        return 2
    if not listonly and dest is None:
        sys.stderr.write("mkfs9: -d required in materialize mode\n")
        return 2
    for pr in protos:
        sys.stderr.write("processing %s\n" % pr)
    walk(protos, oldroot, dest=dest, listonly=listonly)
    if not listonly:
        sys.stderr.write("file system made\n")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
