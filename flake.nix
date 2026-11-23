{
  description = "Harvey OS dev environment — plan9port toolchain, devshell and build apps";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      # PROJECT.md scope: darwin-aarch64 (primary dev), linux aarch64/
      # x86_64.  x86_64-darwin is OUT of scope (its nixpkgs pin-era eval
      # throws — and Harvey never ships for it).
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
        # 19-06 (DESK-01/D-02): the drawterm package — the vendored
        # in-tree drawterm compiled hermetically (src is the committed
        # repo dir; no fetch, no patchPhase — local -O/-G/gui-none work
        # lands as normal Harvey commits on the vendor).  Linux-only
        # beside minimega: the gui-x11 backend is this phase's windowed
        # leg (darwin is the documented-manual -G-only venue, amended
        # D-03).
        // nixpkgs.lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
          minimega = pkgs.callPackage ./nix/minimega.nix { };
          drawterm = pkgs.callPackage ./nix/drawterm.nix { };
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
          # 01-26 (D-08 narrowed by D-20, settled by D-26): the ONE Harvey
          # command that keeps the flake self-sufficient without r9 — build
          # Harvey's own amd64/9k10cpu.elf through the platform build above
          # (build.sh on Linux, vm-build.sh on darwin) and boot it under
          # `qemu-system-x86_64 -M q35` to the `root is from (tcp)[tcp]:`
          # prompt.  The script is spikes/s5/boot-q35.sh's launch-and-
          # classify harness (capture-before-start, the banner/prompt/
          # signature classification, kill-and-reap on every exit) with the
          # platform build wired in; KVM when /dev/kvm is writable, else an
          # explicit HARVEY_Q35_ACCEL=tcg — never a silent downgrade.  The
          # runtimeInputs are the build app's platform split plus qemu, git
          # (the HARVEY and KERNDATE lookups), coreutils and gnugrep.
          q35Pkg = mkScriptApp pkgs "harvey-q35" ./nix/q35.sh
            (
              if isLinux then ''
                export GNU_SED="${pkgs.gnused}/bin/sed"
              '' else ''
                export LIMA_YAML="${./nix/lima-harvey.yaml}"
              ''
            )
            ([ pkgs.plan9port pkgs.bash pkgs.qemu pkgs.coreutils pkgs.gnugrep pkgs.git ]
              ++ pkgs.lib.optionals isLinux [ pkgs.util-linux pkgs.gnused pkgs.mount pkgs.binutils ]
              ++ pkgs.lib.optionals (!isLinux) [ pkgs.lima pkgs.openssh pkgs.rsync ]);
          # 19-06 (DESK-01): the drawterm session wrapper — scrubs the
          # credential-bearing env ($cpu/$auth/$PASS/$USER), pins the
          # connection on argv via -O (the committed hostfwd pair's
          # loopback side: cpu=127.0.0.1, auth=tcp!127.0.0.1!5670,
          # user=glenda — argv is the single source), prints the exact
          # encrypted-default connect line (windowed primary + the -G
          # text form; no -e flag anywhere, D-15), and execs the
          # package binary.  Headless (DISPLAY unset) runs the -G stdio
          # line LOUDLY — never a silent downgrade.  linux-only beside
          # the drawterm package: it consumes NO r9 attrs (D-20 keeps it
          # as it is today).
          drawtermX64Pkg = mkScriptApp pkgs "harvey-drawterm" ./nix/drawterm-x64.sh ''
            ${nixpkgs.lib.optionalString isLinux ''
              export DRAWTERM_BIN="${self.packages.${system}.drawterm}/bin/drawterm"
            ''}
          '' [ pkgs.bash ];
        in {
          setup = mkApp setupPkg;
          toolchain = mkApp toolchainPkg;
          build = mkApp buildPkg;
          iso = mkApp isoPkg;
          default = mkApp setupPkg;
          # 01-26 (D-26): the own-kernel q35 launcher.
          q35 = mkApp q35Pkg;
        }
        # 16-03/19-06: the drawterm session app — the wrapper above
        # (scrub + -O pin + printed connect line + exec).  It consumes no
        # r9 attrs, so it stays after the flip (D-20).
        // nixpkgs.lib.optionalAttrs isLinux {
          drawterm = mkApp drawtermX64Pkg;
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
              echo "apps: nix run .#setup -> .#toolchain -> .#build | .#iso | .#q35"
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
