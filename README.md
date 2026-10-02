# FyxOS

**A Nix-based Linux distribution with a standard FHS library layout that still uses the
official NixOS binary cache.**

On NixOS, a binary built for "Linux" usually fails to start:

```console
$ ./some-vendor-tool
bash: ./some-vendor-tool: cannot execute: required file not found
```

The cause is the missing `/lib64/ld-linux-x86-64.so.2`, `/usr/lib`, and `/usr/bin/python3`.
Every other mainstream distribution has them, and prebuilt software expects them. This
includes manylinux wheels, npm and Cargo prebuilt binaries, rustup toolchains, VS Code
Server, JetBrains IDEs, AppImages, game launchers, and vendor SDKs.

FyxOS keeps everything that makes NixOS good: declarative configuration, atomic
upgrades, rollbacks, and reproducible builds. It adds the standard layout as a
first-class, always-on part of the system:

```console
$ ls -l /lib64/ld-linux-x86-64.so.2 /usr/lib/libz.so.1 /usr/bin/env
$ ./some-vendor-tool      # just runs
$ pip install numpy && python -c 'import numpy'   # manylinux wheel, just works
```

## How it works, in one paragraph

FyxOS **adds** an FHS view of the system and **never relocates** the Nix store.
Every package still lives in `/nix/store`, built by unmodified nixpkgs, so its store path
is identical to what `cache.nixos.org` already holds, and installs download prebuilt
binaries. On top of that store, each system generation builds a read-only FHS root:
`/usr/lib`, `/usr/bin`, `/lib64/ld-linux-x86-64.so.2`, and `/etc/ld.so.cache`. Its
contents are a declared, versioned set of libraries and tools. It is switched and rolled
back atomically with the rest of the generation. Nix builds stay sandboxed and cannot
see the FHS root, so Nix's purity guarantees are unchanged. Only foreign binaries at
runtime use it.

## Goals

- **Foreign binaries run unmodified.** No `patchelf`, no `nix-ld` environment
  variables, no per-app FHS sandbox.
- **`cache.nixos.org` keeps working.** FyxOS tracks NixOS channel revisions of nixpkgs and
  never overrides a package in a way that would change its store path. Its own cache
  holds only the small FHS glue derivations.
- **Still declarative and rollback-safe.** The FHS root is part of the system closure.
  `fyxos-rebuild switch --rollback` restores `/usr` along with everything else.
- **No new impurity for Nix builds.** The build sandbox has no `/usr`, so a derivation
  cannot silently depend on the FHS root.

## Non-goals

- Rebuilding nixpkgs with an FHS prefix. Store paths are baked into every package hash,
  so a different prefix would discard the binary cache entirely.
- Replacing Nix, nixpkgs, or the NixOS module system. FyxOS is a distribution layer on
  top of them, not a fork of nixpkgs.
- Mutable `/usr`. You cannot `make install` into `/usr`. Use `/usr/local` or `/opt` as on
  any other distribution.

## Status

**Design phase.** Nothing is installable yet. The design and the first validation spike
are described in the documentation below.

## Documentation

- [Design](docs/design.md): architecture, the FHS root, the loader, cache strategy,
  configuration, and open questions.
- [Prior art](docs/prior-art.md): `nix-ld`, `envfs`, `nixos-fhs-compat`, `buildFHSEnv`,
  Guix `--emulate-fhs`, and why none of them is a complete answer.
- [Roadmap](docs/roadmap.md): phased plan, from a NixOS module to an installable
  distribution.

## Relationship to NixOS

FyxOS is an independent project and is not affiliated with or endorsed by the NixOS
Foundation. It depends on nixpkgs, the NixOS module system, and the public
`cache.nixos.org` binary cache, and is grateful to everyone who builds and maintains
them. FyxOS aims to be a good citizen of that ecosystem. Its core FHS module is designed
to work on plain NixOS too, and improvements that belong upstream should go upstream.
