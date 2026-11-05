
## 07-04 session findings (lima guest toolchain)

- **02-4 root cause pinned:** vm-run.sh's ensure sentinel `GHB="$GUEST_DIR/.build/hostbin-linux-aarch64/bin"` is a RELATIVE path checked after `cd "$GUEST_DIR"` in the same remote shell, so the tested path is `harvey-build/harvey-build/...` — it never exists, and `nix run .#setup && nix run .#toolchain` re-runs on EVERY darwin-leg invocation (minutes per run).
- **Race hazard:** each vm-run.sh push rsyncs with `--delete`, wiping the guest's gitignored `sys/src/cmd/unix/9cc/obj.linux` (a darwin host has only obj.darwin); toolchain.sh lacks `set -e`, so a raced nm.BUILD failure (ar: lib9.a/libmach.a missing) doesn't stop the chain — a zombie build keeps mutating the shared guest while the next push wipes obj.linux under it. Observed twice in this session; converges once the guest is quiet. Fix candidates: absolute GHB, `--exclude 'obj.*'` (or ctimes-based skip) on the push, `set -e` in toolchain.sh.
