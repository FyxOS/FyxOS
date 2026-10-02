# Roadmap

Each phase ends with something usable and a clear go/no-go signal for the next.

## Phase 0: validation spike

Prove the risky assumptions in the [design](design.md) (items marked **[verify]**)
before building anything on them.

- Build `fhs-ld` from the pinned nixpkgs glibc source with stock FHS search behaviour.
  Confirm it reads `/etc/ld.so.cache` and `/usr/lib`.
- In a NixOS VM, hand-assemble an FHS root for the `base` and `manylinux` profiles.
- Run the **compatibility corpus** unmodified:
  - `pip install` manylinux wheels: numpy, torch, cryptography
  - Node prebuilt native modules: `better-sqlite3`, `sharp`
  - rustup and a Go release binary
  - VS Code Server and a JetBrains IDE
  - An AppImage
  - Conda/miniforge
- Measure the `cache.nixos.org` hit rate of the resulting system closure.

**Exit:** the corpus passes and the cache hit rate is at least 99%. Otherwise, revisit the
loader design (design §5 fallback).

## Phase 1: NixOS module

- `fyxos.nixosModules.fhs` with `fyx.fhs.*` options and the `base`, `manylinux`, and
  `desktop` profiles.
- `fhs-ld` and FHS roots published to `cache.fyxos.org`.
- CI: the corpus runs in VMs on every change. A glibc version-match check and a
  cache-hit-rate check run as well.
- `fyx why <binary>` diagnostics.

**Exit:** a stock NixOS user can import one module and run the corpus.

## Phase 2: distribution

- `fyxos.lib.system`, `fyxos-rebuild`, and a FyxOS-branded installer ISO, built from the
  same modules.
- Channels that track `nixos-YY.MM` and `nixos-unstable` revisions.
- The `gaming` profile with i686 multilib.
- aarch64-linux.

**Exit:** install FyxOS on bare metal and run Steam, a JetBrains IDE, and a PyTorch
wheel with no extra configuration.

## Phase 3: ecosystem

- Propose the loader and FHS-root pieces upstream to nixpkgs where they fit.
- Engage with the FHS revision for store-based Unixes.
- Documentation for vendors: "your Linux binary runs on FyxOS if it runs on manylinux_2_28".
