# API Coverage Declaration — Phase 05

No external API integration: this phase composes two local repos (Harvey + r9) via Nix flakes and boots a qemu guest — it integrates no external API/SDK/service. The only new external reference is the `inputs.r9` flake input pointing at the project's own working fork `github.com:requaos/r9` (not a registry package; locked in PROJECT.md).
