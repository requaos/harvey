# build/x86_64/root-tree — the bootfs image skeleton (14-05)

The committed skeleton `build/x86_64/mkimage.sh` tars into every baked
`bootfs.paq` before the mount-point dirs and marker binaries land — the
x86_64 re-key of `build/aarch64/root-tree/`'s role (05-02).

This era (Phase 14, D-08's staged leg 1) the skeleton is deliberately
minimal: the image carries only the marker at `/amd64/init`, the empty
mount-point dirs, and this file. The real content grows here as the
phase's later plans land — `rc/lib/rcmain` (verbatim, the amd64-safety
single-source rule), `rc/bin/termrc`, `lib/namespace`,
`usr/glenda/lib/profile`, and the lib fixtures — keyed to image
contents, never shared-source edits.
