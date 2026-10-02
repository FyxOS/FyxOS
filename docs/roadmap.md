# Roadmap

Every phase stays inside the [constraints](design.md#1-constraints): no compute budget, no
hosting budget, and nothing beyond FHS compatibility.

## Phase 0: validation

In a local NixOS VM, set the options by hand and check each **[verify]** item in the
[design](design.md). Then run a small corpus of foreign binaries unmodified:

- a manylinux wheel (`pip install numpy`)
- a rustup toolchain
- a Go release binary
- an AppImage

**Exit:** the corpus runs, and every store path in the closure comes from
`cache.nixos.org`.

## Phase 1: the module

- `flake.nix` with `nixosModules.default`.
- `fyx.fhs.libraries`, `fyx.fhs.extraLibraries`, `fyx.fhs.binaries`.
- A NixOS VM test for the Phase 0 corpus.

**Exit:** a stock NixOS user can import one module and run the corpus.

## Phase 2: upstream

Propose the useful parts to nixpkgs: a default FHS library set for nix-ld, and the
`/usr/lib` link. If nixpkgs adopts them, FyxOS shrinks further. That is the intended
end state.
