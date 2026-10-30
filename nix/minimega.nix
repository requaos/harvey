# minimega (Sandia) — VM launch/management daemon + CLI.
# Fetched and built by nix per project decision (no submodules/relative paths).
{ lib, buildGoModule, fetchFromGitHub, libpcap, writeText }:

let
  # upstream generates internal/version from git metadata at build time
  # (scripts/version.bash); fetchFromGitHub tarballs have no .git, so write
  # it deterministically here
  version = "3.3.0";
  src = fetchFromGitHub {
    owner = "sandia-minimega";
    repo = "minimega";
    rev = "refs/tags/${version}";
    hash = "sha256-jcQH+F/YSluNrt+fhnB81iFPpUgFlpxuNc4Zse6rD1o=";
  };
  versionGo = writeText "version.go" ''
    package version

    var (
    	Version  = "${version}"
    	Revision = "${src.rev}"
    	Date     = "nix"
    )
  '';
in

buildGoModule {
  pname = "minimega";
  inherit version src;

  # upstream ships vendor/ — use it (no vendored-hash fetch)
  vendorHash = null;

  # gopacket/pcap needs CGO + libpcap headers
  buildInputs = [ libpcap ];

  # Only the daemon/CLI and the web UI are needed for this project
  subPackages = [ "cmd/minimega" "cmd/miniweb" ];

  # tests require KVM / root / network namespaces
  doCheck = false;

  preBuild = ''
    mkdir -p internal/version
    cp ${versionGo} internal/version/version.go
  '';

  ldflags = [ "-s" "-w" ];

  meta = with lib; {
    description = "Launch and manage virtual machines (Sandia minimega)";
    homepage = "https://sandia-minimega.github.io/minimega/";
    license = licenses.gpl3Only;
    platforms = platforms.linux; # daemon is linux-only upstream (linux/fs.h, KVM)
    # aarch64 guests are NOT supported upstream (x86/KVM-centric: hardcoded
    # qemu-system-x86, x86 CPU parsing). It manages Harvey/r9 amd64 test VMs.
  };
}
