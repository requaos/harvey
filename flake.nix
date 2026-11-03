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
      systems = [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" "x86_64-darwin" ];
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
        # minimega VM orchestration, fetched+built by nix (no submodule glue).
        # Linux-only upstream (KVM, linux/fs.h); manages Harvey/r9 amd64 test
        # VMs on KVM hosts. aarch64 guests are NOT supported upstream.
        nixpkgs.lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
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
        in {
          setup = mkApp setupPkg;
          toolchain = mkApp toolchainPkg;
          build = mkApp buildPkg;
          iso = mkApp isoPkg;
          default = mkApp setupPkg;
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
            ] ++ pkgs.lib.optionals isLinux [ util-linux binutils self.packages.${system}.minimega ]
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

              echo "harvey devshell: HARVEY=$HARVEY PLAN9=$PLAN9"
              echo "  host bin: $HARVEY_LINUX_BIN"
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
