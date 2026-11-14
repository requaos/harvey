# nix/drawterm.nix — the drawterm package (DESK-01, 19-06 D-02).
#
# Builds the VENDORED IN-TREE drawterm (sys/src/cmd/unix/drawterm,
# D-01's source of record) hermetically: src is the committed repo
# directory itself — no fetchurl, no fetchgit, no patchPhase (T-19-SC:
# zero external packages; local fixes like -O/-G/gui-none land as
# normal Harvey commits on the vendor, never as patch indirection).
#
# The gui-x11 backend is linked (the windowed human default); -G runs
# from the same binary without touching the display.  Make.unix keys
# its X11 wiring off $(X11), so the build assembles ONE merged prefix
# from the nix store's split outputs (libX11 headers+lib, libXt
# headers — x11.c includes IntrinsicP.h though Make.unix links only
# -lX11 — and xorgproto's X11/X.h) and passes it env-style.  Only
# git-TRACKED files reach the flake's source copy: new vendor files
# must be staged before `nix build` sees them (the 16-01 lesson).
#
# Flakes note: building against an unstaged working tree silently
# evaluates the last COMMITTED state of the vendor dir.

{ stdenv, libX11, libXt, xorgproto }:

stdenv.mkDerivation {
  pname = "drawterm";
  version = "19.06";

  src = ../sys/src/cmd/unix/drawterm;

  buildInputs = [ libX11 libXt xorgproto ];

  # the vendored Makefile is the whole build; nothing to configure
  dontConfigure = true;

  buildPhase = ''
    runHook preBuild

    # merged X11 prefix: $(X11)/include, $(X11)/lib{,64} — the shape
    # Make.unix expects, assembled from the store's split -dev/-out
    # outputs (plus xorgproto's X.h, which libX11's headers include)
    mkdir -p x11/include/X11 x11/lib x11/lib64
    for d in ${libX11.dev}/include ${libXt.dev}/include ${xorgproto.dev or xorgproto}/include; do
      if [ -d "$d/X11" ]; then
        for h in "$d"/X11/*; do ln -sf "$h" x11/include/X11/; done
      fi
    done
    for l in ${libX11.out}/lib/libX11.so*; do
      ln -sf "$l" x11/lib/
      ln -sf "$l" x11/lib64/
    done

    make CONF=unix X11=$PWD/x11

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    install -Dm755 drawterm $out/bin/drawterm
    runHook postInstall
  '';

  meta = {
    description = "Plan 9 drawterm client (Harvey vendored source, -G/-O additions)";
    mainProgram = "drawterm";
  };
}
