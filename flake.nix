{
  description = "Harvey OS dev environment — plan9port toolchain, devshell and build apps";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  # Harvey's flake owns the composition — the r9 kernel arrives
  # as a proper flake input (exact rev + narHash pinned in flake.lock), never
  # a sibling-checkout path or submodule.  Consumed: r9.packages.<system>.kernel-virt
  # (the kernel-virt.elf + aarch64/lib/virt-gicv{2,3}.dtb store-path contract —
  # the boot apps default to gicv3, with -accel hvf -cpu host on darwin-aarch64).
  # Dev flow against a local r9 checkout: nix run .#boot-r9
  # --override-input r9 git+file:///path/to/r9 — dev-only, never the default.
  inputs.r9.url = "github:requaos/r9";

  outputs = { self, nixpkgs, r9 }:
    let
      # PROJECT.md scope: darwin-aarch64 (primary dev), linux aarch64/
      # x86_64.  x86_64-darwin is OUT of scope (its nixpkgs pin-era eval
      # throws — and Harvey never ships for it); r9 also ships no package
      # for the tuple, so dropping it from the systems list fixes
      # `nix flake show --all-systems` AND keeps the boot-r9 hasAttr
      # gating truthful.
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
        # trace-syscalls) as ONE std-only Rust binary.
        # Pure-std: builds on all four systems, sandboxed build is
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
          # THE one command — build the aarch64
          # userland (lima on darwin, native unshare on linux — the same
          # mkScriptApp platform split), bake bootfs.paq with Harvey's own
          # mkpaqfs, fdtput-patch a copy of the r9 package's DTB, and
          # launch the flake-input kernel to the interactive % prompt.
          # The kernel/DTB arrive ONLY as the r9 flake input's store
          # paths — never a sibling-checkout path.
          # qemu+dtc+git always (the launch, the DTB patch, the KERNDATE
          # derivation); the build-transport inputs mirror the build
          # app's platform split.
          bootR9Pkg = mkScriptApp pkgs "harvey-boot-r9" ./nix/boot-r9.sh ''
            export R9_KERNEL_PKG="${r9.packages.${system}.kernel-virt}"
          '' ([ pkgs.plan9port pkgs.bash pkgs.qemu pkgs.dtc pkgs.git ]
            ++ pkgs.lib.optionals isLinux [ pkgs.util-linux pkgs.gnused pkgs.mount pkgs.binutils ]
            ++ pkgs.lib.optionals (!isLinux) [ pkgs.lima pkgs.openssh pkgs.rsync ]);
          # The expect-style smoke as a flake app —
          # the SAME composed pipeline as boot-r9 (R9_KERNEL_PKG store
          # path, build → bake → DTB patch) but launched under
          # build/aarch64/smoke-r9.expect, which drives the full
          # sweep and exits 0/1 for CI.  boot-r9's behavior is untouched.
          smokeR9Pkg = mkScriptApp pkgs "harvey-boot-r9-smoke" ./nix/smoke-r9.sh ''
            export R9_KERNEL_PKG="${r9.packages.${system}.kernel-virt}"
          '' ([ pkgs.plan9port pkgs.bash pkgs.qemu pkgs.dtc pkgs.git pkgs.expect ]
            ++ pkgs.lib.optionals isLinux [ pkgs.util-linux pkgs.gnused pkgs.mount pkgs.binutils ]
            ++ pkgs.lib.optionals (!isLinux) [ pkgs.lima pkgs.openssh pkgs.rsync ]);
          # 08-09 (D-13, NETIP-03's composed leg): the composed NET
          # smoke as a flake app — the SAME composed pipeline as
          # boot-r9-smoke (R9_KERNEL_PKG store path, build → bake →
          # DTB patch) but launched under build/aarch64/smoke-r9-net.expect,
          # which drives the user-visible net flows through the packaged
          # kernel's devip #I tree in ONE boot (ping 127.0.0.1, udp
          # echo, tcp/7 echo, ipconfig static + dhcp — the baked
          # fixtures' markers, both NOT-L2-TRUTH venue labels, and the
          # NET-SMOKE: ALL STAGES PASS completion marker) and exits
          # 0/1 for CI.  smoke-r9's behavior is untouched; the
          # packaged kernel carries devip from 08-09's virtshell dev
          # entry.  smokeR9Pkg's shape verbatim.
          netSmokeR9Pkg = mkScriptApp pkgs "harvey-boot-r9-net-smoke" ./nix/smoke-r9-net.sh ''
            export R9_KERNEL_PKG="${r9.packages.${system}.kernel-virt}"
          '' ([ pkgs.plan9port pkgs.bash pkgs.qemu pkgs.dtc pkgs.git pkgs.expect ]
            ++ pkgs.lib.optionals isLinux [ pkgs.util-linux pkgs.gnused pkgs.mount pkgs.binutils ]
            ++ pkgs.lib.optionals (!isLinux) [ pkgs.lima pkgs.openssh pkgs.rsync ]);
          # 06-07 (D-12, USPACE-04's second venue): the r9-side tier-1
          # gate — the SAME composed pipeline, the tier-1 payload in the
          # image, and build/aarch64/tier1-r9.expect driving the sweep
          # on r9 (one typed line; r9's devcons serves reads).
          # smokeR9Pkg's shape verbatim; smoke-r9 itself is untouched.
          tier1R9Pkg = mkScriptApp pkgs "harvey-boot-r9-tier1" ./nix/tier1-r9.sh ''
            export R9_KERNEL_PKG="${r9.packages.${system}.kernel-virt}"
          '' ([ pkgs.plan9port pkgs.bash pkgs.qemu pkgs.dtc pkgs.git pkgs.expect ]
            ++ pkgs.lib.optionals isLinux [ pkgs.util-linux pkgs.gnused pkgs.mount pkgs.binutils ]
            ++ pkgs.lib.optionals (!isLinux) [ pkgs.lima pkgs.openssh pkgs.rsync ]);
          # 14-07 (D-05/D-06, XEXEC-03): the x64 one-command compose —
          # the same pipeline shape as boot-r9 (kernel-package contract →
          # KERNDATE provenance → userland build → bake) but the kernel
          # arrives as the r9 input's kernel-x64 (the q35shell-config
          # kernel: exec+bootchain devs — plain q35 carries no user
          # mode), the bake is the 14-05/14-06 x64 pipeline (stage-build
          # + mkimage → bootfs.paq + bootfs-chain.paq), and the ISO
          # composition calls r9's exported iso-builder (ONE
          # reproducibility implementation, un-forked) before launching
          # qemu-system-x86_64 -M q35 -accel kvm -cdrom — NO DTB patch,
          # NO -device loader anywhere (the aarch64 delivery is
          # deliberately not carried: GRUB delivers bootfs as an mb2
          # tag-3 module off the same ISO).  The aarch64 app names and
          # bodies stay byte-untouched (frozen-at-pin; Phase 19's INT-05
          # owns any ONE-command consolidation).
          # dtc is NOT carried: nothing in the x64 pipeline touches a
          # DTB; git stays (the KERNDATE provenance step).
          bootR9X64Pkg = mkScriptApp pkgs "harvey-boot-r9-x64" ./nix/boot-r9-x64.sh ''
            export R9_KERNEL_X64_PKG="${r9.packages.${system}.kernel-x64}"
            export R9_ISO_BUILDER="${r9.packages.${system}.iso-builder}/bin/r9-iso-builder"
          '' ([ pkgs.plan9port pkgs.bash pkgs.qemu pkgs.git ]
            ++ pkgs.lib.optionals isLinux [ pkgs.util-linux pkgs.gnused pkgs.mount pkgs.binutils ]);
        in {
          setup = mkApp setupPkg;
          toolchain = mkApp toolchainPkg;
          build = mkApp buildPkg;
          iso = mkApp isoPkg;
          default = mkApp setupPkg;
          # boot-r9 exists only where r9 ships packages.kernel-virt (its
          # flake systems: aarch64-darwin, aarch64-linux, x86_64-linux).
          # x86_64-darwin is doubly absent: r9 ships no package for it AND
          # Harvey dropped the tuple from the systems list
          # (PROJECT.md scope) — the hasAttr gate keeps this attrset's
          # evaluation lazy where the package is absent.
        } // nixpkgs.lib.optionalAttrs (builtins.hasAttr system r9.packages) {
          boot-r9 = mkApp bootR9Pkg;
          boot-r9-smoke = mkApp smokeR9Pkg;
          boot-r9-net-smoke = mkApp netSmokeR9Pkg;
          boot-r9-tier1 = mkApp tier1R9Pkg;
        }
        # 14-07: the x64 compose apps live ONLY where r9 exports BOTH
        # kernel-x64 and iso-builder (its own gates: the kernel on every
        # linux host, the BIOS ISO machinery — grub's i386-pc modules —
        # on x86_64-linux only).  The hasAttr discipline re-keyed to the
        # attrs actually consumed, so evaluation stays lazy everywhere
        # else and widens automatically if r9 ever widens its exports.
        // nixpkgs.lib.optionalAttrs
          (builtins.all (a: builtins.hasAttr a r9.packages.${system}) [ "kernel-x64" "iso-builder" ]) {
          boot-r9-x64 = mkApp bootR9X64Pkg;
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
              # Stable nixpkgs Rust for the harness crate
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
              # Nix-store-first harness resolution for the
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
