# Prior art

As of October 2026, no existing distribution combines nixpkgs, `cache.nixos.org`, and a
system-wide FHS library layout. What does exist are building blocks and partial
answers. Omnix builds on what they learned.

## Tools on NixOS

| Project | What it does | Gap Omnix addresses |
|---|---|---|
| [nix-ld](https://github.com/nix-community/nix-ld) | Shim at `/lib64/ld-linux-x86-64.so.2` that hands off to a store loader using `NIX_LD` / `NIX_LD_LIBRARY_PATH` | **Omnix's loader.** Off by default and has no `/usr/lib`; Omnix turns it on and adds the standard paths |
| [envfs](https://github.com/Mic92/envfs) | FUSE filesystem serving `/bin` and `/usr/bin` from the caller's `PATH` | **Omnix's `/bin` and `/usr/bin`.** Covers executables and shebangs only, so Omnix pairs it with nix-ld for libraries |
| [nixos-fhs-compat](https://github.com/balsoft/nixos-fhs-compat) | NixOS modules that link binaries and libraries into `/bin`, `/usr/lib`, … | Closest to Omnix, but explicitly scoped to containers and VMs, and has no loader |
| [`buildFHSEnv`](https://ryantm.github.io/nixpkgs/builders/special/fhs-environments/) | Per-application bubblewrap sandbox with a synthetic FHS root (Steam, `vscode-fhs`) | Per app, not system-wide. Needs a wrapper derivation for every program |
| [nix-alien](https://github.com/thiagokokada/nix-alien) | Detects a foreign binary's libraries and runs it in an FHS shell or via nix-ld | Per binary, after the fact |
| `stub-ld` (NixOS module) | Puts a loader stub at the FHS path that prints a helpful error | Explains the failure rather than fixing it |

## Other systems

- **Guix System:** [`guix shell --container --emulate-fhs`](https://guix.gnu.org/en/blog/2023/the-filesystem-hierarchy-standard-comes-to-guix-containers/)
  gives a container with an FHS layout and a glibc that reads `/etc/ld.so.cache`. It is
  cleaner than nix-ld, but doing the same on Nix means building and hosting a glibc, which
  Omnix's constraints rule out. Guix also applies it per shell, not system-wide.
- **Nix on FHS distributions** ([system-manager](https://github.com/numtide/system-manager),
  the Determinate and NixOS installers, Flox, Devbox) solve the problem the other way
  round: an FHS host with `/nix` added. You keep the FHS layout and lose NixOS's
  whole-system declarative model.
- **NixOS derivatives** on the [wiki list](https://wiki.nixos.org/wiki/NixOS-based_distributions)
  (SnowflakeOS, Spectrum, Aux, and others) all keep the NixOS layout.

## Key discussions

- [Is a Nix-based FHS-compliant distribution possible?](https://discourse.nixos.org/t/is-a-nix-based-fhs-compliant-distribution-possible/40829)
  The main objection is that global paths hide undeclared dependencies. Omnix's answer is
  design §4: the build sandbox still has no `/usr`.
- [Nix needs relocatable binaries](https://fzakaria.com/2026/06/21/nix-needs-relocatable-binaries)
  explains why moving the store prefix forfeits the cache, which is why Omnix adds and
  never relocates.
- [Nix pragmatism: nix-ld and envfs](https://fzakaria.com/2025/02/26/nix-pragmatism-nix-ld-and-envfs)
  is the "good enough" baseline Omnix must clearly beat.
- [FHS major revision, licensing store-based Unixes](https://discourse.nixos.org/t/fhs-major-revision-licensing-store-based-unixes/75420)
  is an in-progress FHS revision that would put store-based distributions on an equal
  footing. Omnix should follow it and contribute to it.
- [On Nix, NixOS and the Filesystem Hierarchy Standard](https://sandervanderburg.blogspot.com/2011/11/on-nix-nixos-and-filesystem-hierarchy.html)
  (2011) gives the original rationale for Nix leaving FHS behind.
