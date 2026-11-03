---
last_mapped_commit: fa0ed761b9667411e8d93797bdbb79ba0598fa2f
last_mapped_at: 2026-11-03
---
# External Integrations

**Analysis Date:** 2026-11-03

> **Context.** Harvey OS is an operating system, not a web app. It has no third-party SaaS SDKs, no Stripe/Twilio/Auth0 clients, and no `.env` file. "External integrations" here means:
> 1. **Network protocols the OS speaks** (servers + clients shipped in-tree).
> 2. **External repositories fetched at build time** to produce the ISO (plus the Nix flake's pinned inputs: `nixpkgs` and `r9`).
> 3. **The host-side 9P server** used to feed source into the build VM.
> 4. **The r9 kernel flake input** (`github:requaos/r9`, pinned in `flake.lock`) — the Rust kernel, coupled to this repo by a frozen syscall ABI and consumed as read-only nix store paths.
>
> Every entry below includes the directory that implements it.

## 1. Network Protocols Implemented In-Tree

### Core OS Protocols

**9P / 9P2000 (Plan 9 file protocol)** — the backbone of the system.
- Kernel server side: `sys/src/9/port/dev*.c` (each `dev*` is a kernel driver exposing a 9P interface — `devcons.c`, `devdraw.c`, `devmnt.c`, `devpipe.c`, `devproc.c`, `devroot.c`, `devsd.c`, `devsrv.c`, `devssl.c`, `devtls.c`, `devuart.c`, …).
- Userspace library: `sys/src/lib9p/` (`sys/include/9p.h`).
- Userspace servers/clients: `sys/src/cmd/srv.c`, `sys/src/cmd/9pcon.c` (`sys/src/cmd/aux/9pcon.c`), `sys/src/cmd/exportfs/`, `sys/src/cmd/srvfs.c`, `sys/src/cmd/srvold9p/`, `sys/src/cmd/mntgen.c`, `sys/src/cmd/cfs/`, `sys/src/cmd/fscfs/`, `sys/src/cmd/ramfs.c`, `sys/src/cmd/ramcfs/`, `sys/src/cmd/archfs.c`, `sys/src/cmd/pipefile.c`, `sys/src/cmd/snap/`.
- Mounting/binding: `sys/src/cmd/mount.c`, `sys/src/cmd/bind.c`, `sys/src/cmd/nmount.c`, `sys/src/cmd/unmount.c`.
- Boot-time 9P: `sys/src/9/boot/boot.c`, `sys/src/9/boot/bootip.c`.

**Venti** (content-addressed archival block storage)
- Server: `sys/src/cmd/venti/srv/`
- Clients / libraries: `sys/src/libventi/`, `sys/src/liboventi/` (header `sys/include/venti.h`, `sys/include/oventi.h`).
- Utilities: `sys/src/cmd/vac/`, `sys/src/cmd/venti/{copy.c,read.c,write.c,sync.c,randtest.c,readlist.c}`.

**Fossil** (snapshotting filesystem layered on Venti)
- Source: `sys/src/cmd/fossil/` (`9p.c`, `9srv.c`, `9fsys.c`, `9user.c`, `archive.c`, `build` script).

### Authentication & Security

**factotum(4)** — authentication agent
- Source: `sys/src/cmd/auth/factotum/`
- Protocols implemented: `p9any.c`, `p9sk1.c`, `p9cr.c`, `apop.c`, `chap.c`, `httpdigest.c`, `rsa.c`, `wep.c`, `wpapsk.c`, `pass.c`, `secstore.c`.

**authsrv(8)** — authentication server (ticket issuance)
- Source: `sys/src/cmd/auth/authsrv.c`, helpers in `sys/src/cmd/auth/`.

**secstore(1)** — encrypted file storage (e.g. for SSH keys)
- Source: `sys/src/cmd/auth/secstore/` (`secstored.c`, `aescbc.c`, `SConn.c`, `pak.c`).

**TLS / SSL**
- Kernel devices: `sys/src/9/port/devtls.c`, `sys/src/9/port/devssl.c`.
- Userspace: `sys/src/cmd/tlsclient.c`, `sys/src/cmd/tlssrv.c`.
- Cipher implementations: `sys/src/libsec/port/` (AES, DES, 3DES, Blowfish, RC4, ChaCha, RSA, DSA, ElGamal, ECC, X.509, ASN.1, PEM).

**SSH**
- SSH-1 client: `sys/src/cmd/ssh1/`
- SSH-2 client: `sys/src/cmd/ssh2/` (ciphers in `cipheraes.c`, `cipherblowfish.c`, `cipher3des.c`, `cipherrc4.c`; transport in `transport.c`, `netssh.c`, `dh.c`).

### Web / Internet Protocols

**HTTP / HTTPS**
- HTTP server framework: `sys/src/libhttpd/` (`sys/src/cmd/ip/httpd/` — `httpd.c`, `authorize.c`, `classify.c`, `content.c`, `imagemap.c`).
- HTTP client / FS: `sys/src/cmd/webfs/` (`client.c`, `http.c`, `cookies.c`, `fs.c`, `io.c`).
- Helpers: `sys/src/cmd/hget.c`, `sys/src/cmd/webfsget.c`, `sys/src/cmd/webcookies.c`, `sys/src/cmd/ip/httpfile.c`.
- HTML rendering: `sys/src/libhtml/`, `sys/src/cmd/abaco/` (web browser), `sys/src/cmd/troff2html/`, `sys/src/cmd/ms2html.c`.

**FTP**
- Server: `sys/src/cmd/ip/ftpd.c`
- Filesystem client: `sys/src/cmd/ip/ftpfs/`

**Email**
- **upas** (mail system): `sys/src/cmd/upas/` with subdirs `smtp/` (`smtp.c`, `smtpd.c`, `smtpd.y`, `rfc822.y`, `greylist.c`, `mxdial.c`, `rmtdns.c`), `pop3/`, `imap4d/` (in `sys/src/cmd/ip/imap4d/`), `send/`, `filterkit/`, `bayes/`, `fs/`, `marshal/`, `ml/`, `ned/`, `q/`, `scanmail/`, `unesc/`, `vf/`, `alias/`, `misc/`, `common/`.

**DNS**
- Server and resolver: `sys/src/cmd/ndb/` (`dns.c`, `dnserver.c`, `dnresolve.c`, `dnstcp.c`, `dnudpserver.c`, `dnarea.c`, `dnnotify.c`, `dnsquery.c`, `dnsdebug.c`).
- Connection-server (dial/lookup): `sys/src/cmd/ndb/cs.c`, `csquery.c`, `dblookup.c`.
- Database: `lib/ndb/` (data), `sys/src/libndb/` (parser).

**DHCP / BOOTP**
- Server: `sys/src/cmd/ip/dhcpd/`
- Client: `sys/src/cmd/ip/dhcpclient.c`, `sys/src/cmd/ip/ipconfig/`.

**Telnet / rlogin / rexec**
- `sys/src/cmd/ip/telnet.c`, `sys/src/cmd/ip/telnetd.c`, `sys/src/cmd/ip/rlogind.c`, `sys/src/cmd/ip/rexexec.c`.

**Routing / low-level IP**
- Kernel IP stack: `sys/src/9/ip/` (`ip.c`, `ipv6.c`, `icmp.c`, `icmp6.c`, `arp.c`, `gre.c`, `esp.c`, `ipifc.c`, `iproute.c`, `ipmux.c`, `loopbackmedium.c`, `ethermedium.c`, `pktmedium.c`, `netdevmedium.c`).
- Userspace: `sys/src/cmd/ip/ping.c`, `traceroute.c`, `rip.c` (RIP), `gping.c`, `6in4.c` (IPv6 tunnel), `rarpd.c`, `tftpd.c`, `udpecho.c`, `wol.c`, `linklocal.c`, `hogports.c`, `measure.c`.
- Kernel-side for the 9k kernel: `sys/src/9k/ip/`.

**PPP family**
- PPP: `sys/src/cmd/ip/ppp/` (`ppp.c`, `block.c`, `compress.c`, `mppc.c`, `ipaux.c`).
- PPPoE: `sys/src/cmd/ip/pppoe.c`
- PPTP client/server: `sys/src/cmd/ip/pptp.c`, `sys/src/cmd/ip/pptpd.c`.

**VNC**
- Server: `sys/src/cmd/vnc/vncs.c` (+ `screen.c`, `draw.c`, `kbdv.c`, `wsys.c`).
- Client: `sys/src/cmd/vnc/vncv.c` (+ `proto.c`, `color.c`, `auth.c`).

**NTP-like time sync** — `sys/src/cmd/aux/timesync.c` (no full NTP implementation; uses various time sources).

### Filesystem / Storage Protocols

**NFS**
- NFS server (Plan 9 → Unix): `sys/src/cmd/9nfs/` (`nfsserver.c`, `rpc.c`, `portmapper.c`, `pcnfsd.c`, `mport.c`, `nfsmount.c`).
- NFS client: `sys/src/cmd/nfs.c`.
- Sun RPC library: `sys/src/libsunrpc/`.

**SMB / CIFS**
- CIFS client: `sys/src/cmd/cifs/` (`cifs.c`, `auth.c`, `dfs.c`, `netbios.c`, `trans.c`, `trans2.c`, `transnt.c`, `pack.c`).

**iSCSI**
- Server: `sys/src/cmd/ip/iscsisrv.c` (header `iscsi.h`).

**AoE (ATA over Ethernet)**
- Kernel device: `sys/src/9/port/devaoe.c` (`aoe.h`).

**Local / removable filesystems**
- ISO 9660: `sys/src/cmd/9660srv/`, `sys/src/cmd/disk/9660/`, `sys/src/cmd/disk/mk9660*` (`rd9660.c`).
- DOS/FAT: `sys/src/cmd/dossrv/`.
- ext2: `sys/src/cmd/ext2srv/`.
- CD filesystem (MMC/SCSI): `sys/src/cmd/cdfs/` (`mmc.c`, `scsi.c`).
- KFS (legacy local FS): `sys/src/cmd/disk/kfs/`, `kfscmd.c`.
- mkfs / format / partition: `sys/src/cmd/disk/{mkfs.c,format.c,mbr.c,partfs.c,mkext.c,exsort.c,prep/}`.
- Paq (compressed archival): `sys/src/cmd/paqfs/`.
- Tape: `sys/src/cmd/tapefs/`.
- dump / backup tools: `sys/src/cmd/9660srv`, `sys/src/cmd/disk/prep`, `sys/src/cmd/cwfs/` (cached-worm FS), `sys/src/cmd/fossil/`.
- Zip / tar / gzip / bzip2 / lzip / compress / paq: `sys/src/cmd/tar.c`, `tarsplit`, `gzip/`, `bzip2/`, `lzip/`, `compress/`.

### Peripheral / Bus Protocols

**USB** — kernel: `sys/src/9/pc/devusb.c`, `usbuhci.c`, `usbohci.c`, `usbehci.h`, `usbehcipc.c`. Userspace daemons: `sys/src/cmd/usb/`.

**ATA / SATA / SCSI / NVMe-like**
- AHCI: `sys/src/9/pc/sdiahci.c` (`ahci.h`).
- Legacy SD/SCSI: `sys/src/9/pc/sd53c8xx.c`, `sdata.c`, `sdmv50xx.c`, `sdmylex.c`, `sdvirtio.c` (virtio block).
- Generic SD layer: `sys/src/9/port/devsd.c`.

**Ethernet drivers** — `sys/src/9/pc/ether*.c` (~30 drivers: Intel 825xx, Realtek 8139/8169, Broadcom, AMD PCnet, 3Com, DEC tulip, NE2000, etc.). Virtio net: `etherif.h` users. See `sys/src/9/pc/`.

**Serial / UART / mouse / keyboard / VGA / audio** — `sys/src/9/port/devuart.c`, `devmouse.c`, `devdraw.c`, `devvga.c` (`sys/src/9k/k10/devvga.c`), `audio.h`, `devaudio.c`.

**ACPI** — `sys/src/9k/k10/devacpi.c` + `sys/src/libaml/` (AML interpreter).

### Inter-Process / Inter-Machine

**cpu(1) / exportfs / import** — remote execution & file import: `sys/src/cmd/cpu.c`, `sys/src/cmd/exportfs/`, `sys/src/cmd/import.c` (see also `sys/src/cmd/con/`).

**Plumber** — inter-app message bus: `sys/src/cmd/plumb/`, library `sys/src/libplumb/`.

**drawterm** (host-side remote access to Plan 9) — `sys/src/cmd/unix/drawterm/` (built for host OS).

**u9fs** (Unix-hosted 9P file server) — `sys/src/cmd/unix/u9fs/`. Used when Harvey is hosted on a Unix box.

**execnet** — `sys/src/cmd/execnet/`.

### Printing / Fax

- `sys/src/cmd/lp/` — line printer daemon (`lpdaemon.c`, `lpsend.rc`, `tonet.c`, `ipcopen.c`).
- `sys/src/cmd/fax/` — fax send/receive.
- PostScript: `sys/src/cmd/postscript/`, `sys/src/cmd/gs/` (Ghostscript port).
- `sys/src/cmd/proof/`, `sys/src/cmd/page/` — viewers.

## 2. External Repositories Pulled at Build Time

These are **not** in-tree; they are cloned by scripts (or pinned by the Nix flake) when producing a dev environment or ISO. Treat them as the closest thing this repo has to runtime dependencies.

| Repo | Purpose | Fetched by |
|------|---------|------------|
| `github:NixOS/nixpkgs/nixos-unstable` (rev `31ecbaca1bdefa45dffc409f0250bd8039ea0010`) | Primary Nix flake input — supplies plan9port, qemu, lima, expect, dtc, binutils, util-linux, `stdenv.cc`, and the build inputs for `./nix/minimega.nix` | `flake.lock`; `flake.nix` line 4 |
| **`github:requaos/r9`** (rev `9549cee63d86a0c6d9b4d04ed8860b2efabcd3e6`, narHash `sha256-g9OBd1Mwll2bx5bNjzxkuREB0X3H7uTPTyQ62PGrzQc=`) | The r9 Rust kernel as a flake input (D-10/INT-04) — consumed only as `r9.packages.<system>.kernel-virt` store paths (`kernel-virt.elf` + `aarch64/lib/virt-gicv2.dtb`); transitively pins its own `nixpkgs` (rev `1c89083e451e891152365b799595cf7790a43325`) and `oxalica/rust-overlay` (rev `c85ccd343087c57da6021cafa1647142ad03e32e`, honoring r9's `nightly-2026-01-30` toolchain) | `flake.lock`; `flake.nix` line 11; exported to `nix/boot-r9.sh` + `nix/smoke-r9.sh` as `R9_KERNEL_PKG` |
| `9fans/plan9port` | Host build tools (`mk`, `rc`, `9c`/`pcc`, `sed`, `yacc`, `lex`, `awk`) | via nixpkgs in the Nix flow; `build/Dockerfile` lines 29–42 and manually per `BUILD_ON_UNIX` in the legacy flow |
| `0intro/9-cc` (with `build/9-cc.patch`) | Host-side Plan 9 archiver `iar` | `build/Dockerfile` lines 49–81; manually per `BUILD_ON_UNIX`; built with host cc by `./nix/toolchain.sh` in the Nix flow |
| `Harvey-OS/harvey` release `9legacy.iso.bz2` | Bootstrap ISO used to boot the build VM | `build/build.bash` line 6 |
| `golang/go` branch `go1.16.6` | Go toolchain compiled for `GOOS=plan9` to build the Go programs that ship in the image | `.github/workflows/harvey.yml` lines 21–23 |
| `harvey-os.org/cmd/ufs` | Host-side 9P file server used to expose the Harvey tree to the build VM | `.github/workflows/harvey.yml` line 18 (`go get`) |
| `Harvey-OS/edwood` | Go Acme clone shipped in the ISO | `sys/src/cmd/go/fetchrepos.sh` (entry in `commands`) |
| `golang/tools` (`gopls`, `goimports`) | Go language tooling shipped in the ISO | `sys/src/cmd/go/fetchrepos.sh` |
| `fhs/acme-lsp` | LSP bridge for Acme | `sys/src/cmd/go/fetchrepos.sh` |
| `nicolagi/muscle` | 9P/RAM utilities in Go | `sys/src/cmd/go/fetchrepos.sh` |
| **lima** (VM manager, via nixpkgs) | Runs the Linux mount-namespace build inside a VM on macOS | `flake.nix` darwin `harvey-build`/`boot-r9`/`boot-r9-smoke` apps (`./nix/vm-build.sh`, `LIMA_YAML=./nix/lima-harvey.yaml`); devshell on non-Linux |
| **minimega** (VM orchestration, via `./nix/minimega.nix`) | Manages Harvey/r9 amd64 test VMs on KVM hosts (Linux-only upstream; aarch64 guests NOT supported) | `flake.nix` packages + Linux devshell |
| **9front donor tree** (`github.com/9front/9front`, branch `front`, pin `350266104f1fed81c78c3d05fa44f523bec0ae4d`) | Retired-bridge reference kernel for the Phase-2/3 aarch64 harness (proves the vendored 7a/7c/7l toolchain + frozen ABI before r9); also the ABI provenance source (`aarch64/ABI.md`) | One-shot manual clone to gitignored `.build/9front-donor/` — no repeatable import script (`build/aarch64/README.md` "The 9front donor pin") |
| `DeterminateSystems/nix-installer-action` @ `3138316df39ed29be04236d7ffc686fa525866aa` (full-SHA pin, T-05-24) | Installs nix on the CI runner for the r9 boot smoke | `.github/workflows/r9-shell.yml` |

**Note on auth to these:** all are public repos cloned over HTTPS/SSH with no embedded credentials.

## 2a. Cross-Repo Integration: r9 (Rust kernel)

The project's end-state couples this repo to **r9** — a Rust `no_std` reimplementation of the Plan 9 kernel, built with cargo xtask. r9 arrives as the **pinned flake input** `inputs.r9 = github:requaos/r9` (`flake.nix` line 11; exact rev `9549cee63d86a0c6d9b4d04ed8860b2efabcd3e6` + narHash in `flake.lock`). No sibling-checkout path exists anywhere in the composition (INT-04); the dev-loop override is `nix run .#boot-r9 --override-input r9 git+file:///path/to/r9` (D-13 — dev-only, never the default, never what CI uses).

- **Consumed surface:** only `r9.packages.<system>.kernel-virt` — the store path carrying `kernel-virt.elf` + `aarch64/lib/virt-gicv2.dtb`. The `boot-r9`/`boot-r9-smoke` apps export it as `R9_KERNEL_PKG` (`flake.nix`); `nix/boot-r9.sh` and `nix/smoke-r9.sh` validate presence before launch and never exec a caller-supplied kernel path (T-05-21). The apps exist only on systems where r9 ships `packages.kernel-virt` (aarch64-darwin, aarch64-linux, x86_64-linux).
- **The composed boot (INT-01/INT-02):** `nix run .#boot-r9` (interactive `%` prompt) and `nix run .#boot-r9-smoke` (CI smoke) run one pipeline: `build/aarch64/subset-build.sh` (aarch64 userland; lima guest on darwin, native `sudo unshare -m` on linux) → `build/aarch64/mkimage.sh` (bakes `build/aarch64/bootfs.paq` with Harvey's own host-built `mkpaqfs` — r9's xtask is never invoked, D-11) → `fdtput` patch of a throwaway DTB copy (`/chosen linux,initrd-start`/`-end`, two 32-bit BE cells, high word first — mirrors r9's `xtask/src/config.rs` `prepare_initrd_dtb`) → `qemu-system-aarch64 -M virt,gic-version=2 -cpu cortex-a72 -smp 1 -m 1024M -accel tcg -kernel <r9 ELF> -dtb <patched> -device loader,file=<bootfs.paq>,addr=0x48000000 -nographic` (argv values from r9's `aarch64/lib/config_virtexec.toml` `[qemu]`). The smoke (`build/aarch64/smoke-r9.expect`) asserts the D-09 sweep — banner → paqfs → stacksmoke → `%` prompt → echo/ls/ps/cat → DEL safety → init restart — and exits 0/1.
- **Coupling contract (frozen, Phase 2 / decisions D-15/D-16/D-17):**
  - `aarch64/ABI.md` — Harvey↔r9 user-side syscall wire contract for `objtype=aarch64`: syscall number in register `R0`, arguments in 8-byte slots at user `SP+8` upward, trap via `SVC`, result in `R0`. Syscall table = Harvey's `sys/src/libc/9syscall/sys.h` 0–54 verbatim (53 `NSEC` zero-arg register-return; 54 `NMOUNT` Harvey-only, may stay unimplemented in r9 until called). Stubs generated by the `case aarch64` block of `sys/src/libc/9syscall/mkfile`.
  - `aarch64/include/ureg.h` — the frozen trap frame (`r0`..`r28`, `r29`, `r30`/`link`, `sp`, `pc`, `psr`, `type`). `aarch64/ABI.md`'s Phase-4 appendix pins the byte offsets (r0@0 … type@272, `sizeof(Ureg)`=280); r9 enforces them with in-crate `core::mem::offset_of!` const asserts (frame stride 288) plus the cross-repo `cargo xtask ureg-check`, which parses this repo's header via `R9_HARVEY_DIR` (default `../harvey`) and fails on field-name/order/count drift. Changing either file after Phase 4 means re-freezing both repos.
  - Kernel-side dispatch style explicitly does **not** cross the wire (D-17).
- **Provenance:** ABI derived from 9front arm64 at pin `350266104f1fed81c78c3d05fa44f523bec0ae4d` (branch `front`), research-verified 2026-10-31 against 9front `sys/src/9/arm64/trap.c:196` + `mem.h:92` and Harvey `sys/src/libc/9syscall/sys.h` + `sys/src/libc/9syscall/mkfile` (per `aarch64/ABI.md`).
- **Target:** Harvey userspace + r9 kernel boot to a shell on aarch64 under **qemu `-M virt`** — demonstrated end-to-end (see `build/REPRODUCIBILITY.md` INT-03: `git clone … && nix run .#boot-r9-smoke` reproduces the green smoke from a clean checkout on darwin-aarch64 and linux; the linux leg runs in CI as `.github/workflows/r9-shell.yml`).
- **Toolchain note:** the aarch64 Plan 9 compiler triple is `7a`/`7c`/`7l` with `O=7` (`aarch64/mkfile`); prebuilt in `aarch64/bin/`.

## 3. Data Storage

**Databases:** None (no SQL, no Redis, no embedded DB). The system uses the **`/lib/ndb` network database** (flat files parsed by `sys/src/libndb/`) for hosts, DNS, and auth domains — data lives in `lib/ndb/`.

**File storage:**
- **Fossil** (`sys/src/cmd/fossil/`) — primary local filesystem, layered on **Venti** for archival storage (`sys/src/cmd/venti/srv/`).
- **cwfs** (`sys/src/cmd/cwfs/`) — cached-WORM file system (legacy).
- **kfs** (`sys/src/cmd/disk/kfs/`) — simple local FS.
- Everything else is served over 9P from user-space file servers (`sys/src/cmd/*fs.c`, `*fs/` directories).

**Caching:** `cfs` (`sys/src/cmd/cfs/`) and `fscfs` (`sys/src/cmd/fscfs/`) provide client-side caching for 9P mounts. No external cache service.

## 4. Authentication & Identity

**Auth provider:** Self-hosted Plan 9 authentication. **No third-party IdP** (no OAuth, OIDC, SAML, LDAP, Kerberos).

- **factotum(4)** — per-user authentication agent: `sys/src/cmd/auth/factotum/`.
- **authsrv(8)** — central ticket-issuing server: `sys/src/cmd/auth/authsrv.c`.
- **keyfs(4)** — key database: `sys/src/cmd/auth/keyfs.c`.
- **secstore(1)** — user-secret store: `sys/src/cmd/auth/secstore/`.
- **Protocols:** p9sk1, p9cr (Plan 9 challenge/response), APOP, CHAP, HTTP Digest, WPA-PSK, WEP, RSA/DSA/ElGamal PKI, X.509 certificates (`sys/src/cmd/auth/rsa2x509.c`, `asn12rsa.c`, `asn12dsa.c`).
- **Password/key utilities:** `sys/src/cmd/auth/{passwd.c,changeuser.c,userpasswd.c,wrkey.c,convkeys.c,convkeys2.c,netkey.c,printnetkey.c,readnvram.c,secureidcheck.c,uniq.c,warning.c,login.c,newns.c,none.c,guard.srv.c,cron.c,status,enable,disable}`.

## 5. Monitoring & Observability

**Error tracking:** None (no Sentry/Bugsnag/etc.). Errors are surfaced via Plan 9's `errstr` mechanism and `sysfatal`/`syslog`.

**Logs:**
- `sys/src/cmd/syslog.c`-style helpers — search for `syslog` usage in `sys/src/cmd/`.
- Kernel trace / profiling: `sys/src/cmd/kprof.c`, `sys/src/cmd/ktrace.c`, `sys/src/cmd/tprof.c`, `sys/src/cmd/trace.c`, `sys/src/cmd/stats.c`, `sys/src/cmd/aux/clog.c`.
- Log files conventionally under `sys/log/` (see `sys/log/`).

**Stats / performance:** `stats(1)` (`sys/src/cmd/stats.c`) renders CPU/memory graphs; `top`-like functionality via `ps.c`, `sys/src/cmd/aux/acidleak.c`.

## 6. CI/CD & Deployment

**Hosting / target:** Self-hosted — Harvey runs on bare metal or in QEMU (amd64 today; aarch64 under qemu `-M virt` with the r9 kernel as the project target). No PaaS.

**CI pipeline:**
- **GitHub Actions** — two workflows, both `on: [push, pull_request]`:
  - `.github/workflows/harvey.yml` (legacy amd64): Ubuntu-latest runner; installs `rc qemu go-dep qemu-utils expect qemu-system-x86`; clones Go 1.16.6 source, builds `GOOS=plan9 GOARCH=amd64`; `go get harvey-os.org/cmd/ufs` to install the host 9P server; starts `ufs` serving the repo on 9P, runs `bash command.bash` inside `build/`.
  - `.github/workflows/r9-shell.yml` (Phase 5, D-13 — the whole CI story for the aarch64/r9 boot; linux-only by SC#3 amendment): `ubuntu-latest`, 90-minute budget, `permissions: contents: read`; steps are `actions/checkout@v4` → `DeterminateSystems/nix-installer-action` pinned to full SHA `3138316df39ed29be04236d7ffc686fa525866aa` (T-05-24 supply-chain rule — never a floating tag) → `nix run .#boot-r9-smoke`. This is the linux clean-checkout reproduction proof (INT-03); the darwin leg is documented-manual via `build/REPRODUCIBILITY.md`.
- **Nix flake apps** (`flake.nix`) — the modern local pipeline: `nix run .#setup` → `nix run .#toolchain` → `nix run .#build` → `nix run .#iso` (default app is `setup`); plus the r9 boot: `nix run .#boot-r9` (interactive) / `nix run .#boot-r9-smoke` (self-asserting). `build` and the boot-r9 apps use `sudo unshare` (host `/usr/bin/sudo`) on Linux and a lima VM (`./nix/vm-build.sh`, `./nix/lima-harvey.yaml`) on darwin. Devshell via `nix develop`.
- **Docker** (legacy) — `build/Dockerfile` defines an `ubuntu:21.10` image that pre-installs plan9port + 9-cc. Entry point `build/BUILD_IN_DOCKER`. Invocation examples in the Dockerfile header comment.

**Artifact produced:** A bootable ISO written back to the host over the 9P-mounted `/n/host` (`build/build.bash` line 72: `time fcp /tmp/dist/plan9-new.iso.bz2 /n/host/`); the Nix `iso` app (`./nix/iso.sh`) is the modern equivalent.

## 7. Environment Configuration

**Required env vars (host-side only):**

| Var | Purpose |
|-----|---------|
| `HARVEY` | Absolute path to this repo (devshell derives it from `git rev-parse --show-toplevel`) |
| `HARVEY_LINUX_BIN` | Host toolchain bin dir — legacy: `$HARVEY/linux_amd64/bin`; Nix devshell: `$HARVEY/.build/hostbin-$os-$arch/bin` (with `arm64`→`aarch64` normalization) |
| `PLAN9` | plan9port install root — Nix: `${pkgs.plan9port}/plan9`; legacy: `/usr/local/plan9` |
| `PATH` | `$HARVEY_LINUX_BIN` FIRST, `$PLAN9/bin` **LAST** (plan9port's 9p `mount` must not shadow util-linux `mount`) |
| `objtype` | Target arch (`amd64`, `386`, `arm`, `aarch64`, …); devshell exports `amd64` |
| `cputype` | Devshell exports `unix` |
| `ARCH`, `OS` | Host arch/OS, used by CI and build scripts |
| `FORCERCFORMK` | Force mk to run recipes via rc (set in `sys/src/BUILD`; devshell exports `1`) |
| `CGO_ENABLED` | Devshell exports `0` (host Go builds without cgo) |
| `GNU_SED` | Absolute GNU sed path, exported by the Linux `harvey-build` app (plan9 sed lacks `-i`) |
| `LIMA_YAML` | Path to `./nix/lima-harvey.yaml`, exported by the darwin `harvey-build` app |
| `KERNDATE` | Pinned build timestamp (epoch), derived host-side from `git log -1 --format=%ct`; honored by the 9k mkfiles and the boot-r9 apps (`build/REPRODUCIBILITY.md`) |
| `R9_KERNEL_PKG` | r9 `kernel-virt` store path — required by `nix/boot-r9.sh`/`nix/smoke-r9.sh`; exported by the flake apps from `inputs.r9.packages.<system>.kernel-virt` (the only kernel/DTB source, T-05-21) |
| `R9_SKIP_BUILD` | `=1` skips the userland build leg of the boot-r9 apps (dev iteration hatch; gates always run the default full build) |
| `R9_KERNEL` / `R9_DTB` | Kernel ELF + DTB paths required by `build/aarch64/run-r9.sh` (no defaults by design, D-10/D-11) |
| `R9_INITRD` / `QEMU_BIN` | `run-r9.sh` overrides (defaults: `build/aarch64/bootfs.paq`, `qemu-system-aarch64`) |
| `R9_SMOKE_LOG` / `R9_QEMU` | `nix/smoke-r9.sh` capture path (default `build/aarch64/smoke-r9.log`) / qemu binary overrides |
| `R9_HARVEY_DIR` | Locates this repo for r9's `cargo xtask ureg-check` (default `../harvey`) |

**Secrets location:** **None in-repo.** There is no `.env`, no `credentials.json`, no `secrets/` directory. Any real credentials would live in the runtime Plan 9 `factotum` or `secstore` on a deployed system — never in the source tree.

## 8. Webhooks & Callbacks

**Incoming (listeners/servers shipped in-tree):**
- 9P listener — `sys/src/cmd/aux/listen.c`, `listen1.c` (the standard Plan 9 listener)
- HTTP(S) — `sys/src/cmd/ip/httpd/`
- FTP — `sys/src/cmd/ip/ftpd.c`
- SMTP — `sys/src/cmd/upas/smtp/smtpd.c`
- IMAP4 — `sys/src/cmd/ip/imap4d/`
- POP3 — `sys/src/cmd/upas/pop3/`
- DNS — `sys/src/cmd/ndb/dns.c`, `dnserver.c`
- DHCP — `sys/src/cmd/ip/dhcpd/`
- Telnet / rlogin / rexec — `sys/src/cmd/ip/{telnetd.c,rlogind.c,rexec.c}`
- TFTP — `sys/src/cmd/ip/tftpd.c`
- VNC server — `sys/src/cmd/vnc/vncs.c`
- NFS server — `sys/src/cmd/9nfs/nfsserver.c`
- iSCSI target — `sys/src/cmd/ip/iscsisrv.c`
- PPTP — `sys/src/cmd/ip/pptpd.c`
- Venti / Fossil listeners — `sys/src/cmd/venti/srv/`, `sys/src/cmd/fossil/9lstn.c`
- Auth server — `sys/src/cmd/auth/authsrv.c`, `sys/src/cmd/auth/secstore/secstored.c`

**Outgoing (clients shipped in-tree):**
- HTTP — `sys/src/cmd/hget.c`, `webfsget.c`, `webfs/client.c`
- FTP — `sys/src/cmd/ip/ftpfs/`
- SMTP — `sys/src/cmd/upas/smtp/smtp.c`, `send/`
- POP3 / IMAP clients — `sys/src/cmd/upas/{pop3,ned}/`
- DNS resolver — `sys/src/cmd/ndb/dnresolve.c`, `dnsquery.c`
- DHCP client — `sys/src/cmd/ip/dhcpclient.c`, `ipconfig/`
- SSH — `sys/src/cmd/ssh1/`, `ssh2/`
- Telnet — `sys/src/cmd/ip/telnet.c`
- VNC viewer — `sys/src/cmd/vnc/vncv.c`
- NFS client — `sys/src/cmd/nfs.c`
- CIFS client — `sys/src/cmd/cifs/`
- TLS client — `sys/src/cmd/tlsclient.c`

**Outbound HTTP to external SaaS APIs:** None. This is a self-contained operating system.

---

*Integration audit: 2026-11-03*
