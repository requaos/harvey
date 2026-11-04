{
  description = "Harvey OS dev environment — plan9port toolchain, devshell and build apps";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  # D-10/INT-04: Harvey's flake owns the composition — the r9 kernel arrives
  # as a proper flake input (exact rev + narHash pinned in flake.lock), never
  # a sibling-checkout path or submodule.  Consumed: r9.packages.<system>.kernel-virt
  # (05-10's kernel-virt.elf + aarch64/lib/virt-gicv2.dtb store-path contract).
  # Dev flow against a local r9 checkout (D-13): nix run .#boot-r9
  # --override-input r9 git+file:///path/to/r9 — dev-only, never the default.
  inputs.r9.url = "github:requaos/r9";

  outputs = { self, nixpkgs, r9 }:
    let
      # PROJECT.md scope: darwin-aarch64 (primary dev), linux aarch64/
      # x86_64.  x86_64-darwin is OUT of scope (its nixpkgs pin-era eval
      # throws — and Harvey never ships for it); r9 also ships no package
      # for the tuple, so dropping it from the systems list fixes
      # `nix flake show --all-systems` AND keeps the boot-r9 hasAttr
      # gating truthful (05-11's comment).
      systems = [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
      pkgsFor = system: nixpkgs.legacyPackages.${system};

      mkScriptApp = pkgs: name: file: extraHeader: runtimeInputs:
        pkgs.writeShellApplication {
          inherit name runtimeInputs;
          text = ''
            set -euo pipefail
            export PLAN9="${pkgs.plan9port}/plan9"
            # plan9 bin LAST per BUILD_ON_UNIX — plan9port ships a 9p `mount`
            # (mount addr mtpt) which must not shadow util-linux mount in the
            # namespace build
            export PATH="$PATH:$PLAN9/bin"
            ${extraHeader}
            ${builtins.readFile file}
          '';
        };
    in
    {
      packages = forAllSystems (system:
        let pkgs = pkgsFor system; in
        # harness: the build/aarch64 host harness (srv9/drive9/gdbpoke9/mkfs9/
        # trace-syscalls) as ONE std-only Rust binary (quick task 261103-giq,
        # D-01/D-02). Pure-std: builds on all four systems, sandboxed build is
        # network-free via the committed zero-dep Cargo.lock.
        {
          harness = pkgs.rustPlatform.buildRustPackage {
            pname = "harness";
            version = "0.1.0";
            src = ./build/harness;
            cargoLock.lockFile = ./build/harness/Cargo.lock;
            # Tests run via `nix develop -c cargo test` (the plan's verify),
            # not in the package build: a mid-TDD RED tree must still give a
            # working devshell, and the sandboxed build stays minimal.
            doCheck = false;
          };
        }
        # minimega VM orchestration, fetched+built by nix (no submodule glue).
        # Linux-only upstream (KVM, linux/fs.h); manages Harvey/r9 amd64 test
        # VMs on KVM hosts. aarch64 guests are NOT supported upstream.
        // nixpkgs.lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
          minimega = pkgs.callPackage ./nix/minimega.nix { };
        });

      apps = forAllSystems (system:
        let
          pkgs = pkgsFor system;
          isLinux = pkgs.stdenv.hostPlatform.isLinux;
          mkApp = pkg: { type = "app"; program = "${pkg}/bin/${pkg.name}"; };
          isoPkg = mkScriptApp pkgs "harvey-iso" ./nix/iso.sh "" [
            pkgs.expect pkgs.qemu pkgs.curl pkgs.bzip2 pkgs.gnutar pkgs.git
          ];
          setupPkg = mkScriptApp pkgs "harvey-setup" ./nix/setup.sh ""
            [ pkgs.plan9port pkgs.coreutils ];
          toolchainPkg = mkScriptApp pkgs "harvey-toolchain" ./nix/toolchain.sh ""
            # stdenv.cc: vendored 9cc builds with host cc (absent on minimal
            # guests). binutils (nm for 9l autolib; ar) on Linux only —
            # plan9port's darwin build ships its own nm, and GNU nm can't
            # read Mach-O objects
            ([ pkgs.plan9port pkgs.bash pkgs.stdenv.cc ]
              ++ pkgs.lib.optionals isLinux [ pkgs.binutils ]);
          # Kernel build needs Linux mount namespaces: native on Linux,
          # lima VM on darwin.
          buildPkg = if isLinux
            # NB: no pkgs.sudo — a store sudo lacks the setuid bit; use the
            # host's /usr/bin/sudo. GNU_SED is absolute because
            # $HARVEY_LINUX_BIN shadows `sed` with plan9 sed (no -i flag).
            then mkScriptApp pkgs "harvey-build" ./nix/build.sh ''
              export GNU_SED="${pkgs.gnused}/bin/sed"
            '' [ pkgs.plan9port pkgs.bash pkgs.util-linux pkgs.gnused pkgs.mount pkgs.binutils ]
            else mkScriptApp pkgs "harvey-build" ./nix/vm-build.sh ''
              export LIMA_YAML="${./nix/lima-harvey.yaml}"
            '' [ pkgs.lima pkgs.openssh pkgs.rsync ];
          # 05-11 (INT-01, D-10/D-11): THE one command — build the aarch64
          # userland (lima on darwin, native unshare on linux — the same
          # mkScriptApp platform split), bake bootfs.paq with Harvey's own
          # mkpaqfs, fdtput-patch a copy of the r9 package's DTB, and
          # launch the flake-input kernel to the interactive % prompt.
          # The kernel/DTB arrive ONLY as the r9 flake input's store
          # paths (T-05-21) — never a sibling-checkout path (INT-04).
          # qemu+dtc+git always (the launch, the DTB patch, the KERNDATE
          # derivation); the build-transport inputs mirror the build
          # app's platform split.
          bootR9Pkg = mkScriptApp pkgs "harvey-boot-r9" ./nix/boot-r9.sh ''
            export R9_KERNEL_PKG="${r9.packages.${system}.kernel-virt}"
          '' ([ pkgs.plan9port pkgs.bash pkgs.qemu pkgs.dtc pkgs.git ]
            ++ pkgs.lib.optionals isLinux [ pkgs.util-linux pkgs.gnused pkgs.mount pkgs.binutils ]
            ++ pkgs.lib.optionals (!isLinux) [ pkgs.lima pkgs.openssh pkgs.rsync ]);
          # 05-12 (INT-02, D-12): the expect-style smoke as a flake app —
          # the SAME composed pipeline as boot-r9 (R9_KERNEL_PKG store
          # path, build → bake → DTB patch) but launched under
          # build/aarch64/smoke-r9.expect, which drives the full D-09
          # sweep and exits 0/1 for CI.  boot-r9's behavior is untouched.
          smokeR9Pkg = mkScriptApp pkgs "harvey-boot-r9-smoke" ./nix/smoke-r9.sh ''
            export R9_KERNEL_PKG="${r9.packages.${system}.kernel-virt}"
          '' ([ pkgs.plan9port pkgs.bash pkgs.qemu pkgs.dtc pkgs.git pkgs.expect ]
            ++ pkgs.lib.optionals isLinux [ pkgs.util-linux pkgs.gnused pkgs.mount pkgs.binutils ]
            ++ pkgs.lib.optionals (!isLinux) [ pkgs.lima pkgs.openssh pkgs.rsync ]);
        in {
          setup = mkApp setupPkg;
          toolchain = mkApp toolchainPkg;
          build = mkApp buildPkg;
          iso = mkApp isoPkg;
          default = mkApp setupPkg;
          # boot-r9 exists only where r9 ships packages.kernel-virt (its
          # flake systems: aarch64-darwin, aarch64-linux, x86_64-linux).
          # x86_64-darwin is doubly absent: r9 ships no package for it AND
          # Harvey dropped the tuple from the systems list (261104-b4p,
          # PROJECT.md scope) — the hasAttr gate keeps this attrset's
          # evaluation lazy where the package is absent.
        } // nixpkgs.lib.optionalAttrs (builtins.hasAttr system r9.packages) {
          boot-r9 = mkApp bootR9Pkg;
          boot-r9-smoke = mkApp smokeR9Pkg;
        });

      devShells = forAllSystems (system:
        let
          pkgs = pkgsFor system;
          isLinux = pkgs.stdenv.hostPlatform.isLinux;
        in {
          default = pkgs.mkShell {
            packages = with pkgs; [
              plan9port git gnumake bashInteractive coreutils gnused findutils
              qemu expect curl bzip2 gnutar
              # 261103-giq (D-06): stable nixpkgs Rust for the harness crate
              # (NO rust-overlay, NO nightly) + the harness itself on PATH
              cargo rustc
            ] ++ [ self.packages.${system}.harness ]
              ++ pkgs.lib.optionals isLinux [ util-linux binutils self.packages.${system}.minimega ]
              ++ pkgs.lib.optionals (!isLinux) [ lima ];

            shellHook = ''
              export PLAN9="${pkgs.plan9port}/plan9"
              export HARVEY="''${HARVEY:-$(git rev-parse --show-toplevel 2>/dev/null || echo "$PWD")}"
              _hb_os=$(uname -s); _hb_os=''${_hb_os,,}
              _hb_arch=$(uname -m); [ "$_hb_arch" = "arm64" ] && _hb_arch=aarch64
              export HARVEY_LINUX_BIN="''${HARVEY_LINUX_BIN:-$HARVEY/.build/hostbin-$_hb_os-$_hb_arch/bin}"
              export objtype=amd64
              export cputype=unix
              export FORCERCFORMK=1
              export CGO_ENABLED=0
              # $PLAN9/bin LAST per BUILD_ON_UNIX; harvey host bin FIRST
              export PATH="$HARVEY_LINUX_BIN:$PATH:$PLAN9/bin"
              # 261103-giq (D-04): nix-store-first harness resolution for the
              # build/aarch64 shell callers (they fall back to PATH)
              export HARNESS_BIN="${self.packages.${system}.harness}/bin/harness"

              echo "harvey devshell: HARVEY=$HARVEY PLAN9=$PLAN9"
              echo "  host bin: $HARVEY_LINUX_BIN"
              echo "  harness: $HARNESS_BIN"
              echo "apps: nix run .#setup -> .#toolchain -> .#build | .#iso"
              ${if isLinux then ''
                echo "(. #build uses sudo unshare; run from the repo root)"
              '' else ''
                echo "(. #build runs the Linux namespace build inside a lima VM)"
              ''}
            '';
          };
        });
    };
}
