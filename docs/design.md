# FyxOS design

Status: draft. Items marked **[verify]** are assumptions that Phase 0 of the
[roadmap](roadmap.md) must confirm.

## 1. Constraints

These are hard rules. A change that breaks one is rejected, however useful it is.

1. **Zero compute budget.** FyxOS adds no derivation that cannot be fetched from
   `cache.nixos.org`, except trivial local ones: symlink trees and text files that build
   in seconds.
2. **Zero hosting budget.** It has no binary cache, ISO, channel, or website. The GitHub
   repository is the only thing FyxOS publishes.
3. **Minimal surface.** FyxOS makes NixOS FHS-compatible and does nothing else.
   Desktops, defaults, and opinions live in other projects.
4. **Never change nixpkgs.** There are no overlays and no patched packages. Changing a
   package would change store paths, lose the cache, and violate rule 1.

## 2. Problem

Foreign binaries expect the following paths. NixOS does not provide them.

| Path | Used for |
|---|---|
| `/lib64/ld-linux-x86-64.so.2` | ELF interpreter (`PT_INTERP`) |
| `/usr/lib`, `/lib` | Libraries the binary links against |
| `/usr/bin/python3`, `/bin/bash`, … | Shebangs and hard-coded tool paths |

NixOS ships only `/bin/sh` and `/usr/bin/env`.

## 3. Design: add, never relocate

`/nix/store` is untouched, so every store path matches `cache.nixos.org`. FyxOS adds
the three missing pieces as thin layers over the current system generation.

### 3.1 Loader: nix-ld

nixpkgs already ships nix-ld and a NixOS module (`programs.nix-ld`). The module installs
a shim at `/lib64/ld-linux-x86-64.so.2`. The shim finds the real glibc loader and a
library path, then hands off to them. FyxOS:

- enables `programs.nix-ld` by default;
- sets `programs.nix-ld.libraries` from `fyx.fhs.libraries` (§3.2).

It does not build its own loader. A glibc built with standard search paths would mean
compiling and hosting glibc, which violates constraints 1 and 2.

nix-ld finds its library path through `NIX_LD_LIBRARY_PATH`. Only the shim reads that
variable. The normal glibc loader ignores it, so native nixpkgs binaries are unaffected.
**[verify]** That processes outside a login session still find the default library set
without the variable: systemd services, cron, and `ssh host cmd`. If they do not, FyxOS
sets the variable through `environment.sessionVariables` plus a systemd
`DefaultEnvironment`.

### 3.2 Libraries: `/usr/lib` and `/lib`

`programs.nix-ld.libraries` becomes a symlink tree in the system profile. FyxOS exposes
the same tree at the standard paths:

```
/usr/lib -> /run/current-system/sw/share/nix-ld/lib     [verify exact path]
/lib     -> /usr/lib
```

The links are created with `systemd.tmpfiles` rules. They point through
`/run/current-system`, so a generation switch or rollback changes the target with no
FyxOS code involved.

`fyx.fhs.libraries` defaults to a short list. It covers command-line binaries and
manylinux wheels: glibc, libstdc++, libgcc_s, zlib, zstd, xz, bzip2, openssl, libffi,
ncurses, libuuid, curl, and icu. GUI libraries are opt-in through
`fyx.fhs.extraLibraries`. Projects like Autarchy add them.

### 3.3 Interpreters: `/usr/bin`, `/bin`

FyxOS creates these links with `systemd.tmpfiles`:

- `/bin/bash`, `/usr/bin/bash` → bash in the system profile;
- one `/usr/bin/<name>` for each interpreter in `fyx.fhs.binaries`, which is empty by
  default. Declaring `python3` gives you `/usr/bin/python3`.

FyxOS deliberately does not use envfs. The path a binary resolves to would depend on
the caller's `PATH`. Declared links are predictable.

## 4. Purity

The usual objection to an FHS layout on NixOS is that global paths hide undeclared
dependencies. That objection does not apply here:

- **Nix builds cannot see `/usr/lib`.** The build sandbox has no `/usr`, so derivations
  stay pure.
- **Native binaries do not use nix-ld.** Their interpreter is a store path. Only binaries
  that ask for `/lib64/ld-linux…` go through the shim.
- **The library set is declared.** The same configuration gives the same `/usr/lib`.

## 5. What FyxOS is

When Phase 1 is done, FyxOS should be:

- `flake.nix` exposing `nixosModules.default`;
- one module of roughly a hundred lines that sets nix-ld options, declares the
  tmpfiles rules, and defines `fyx.fhs.{libraries,extraLibraries,binaries}`;
- a NixOS VM test (`nixosTests`-style) that runs a few foreign binaries. It runs locally
  or on free CI for public repositories. No hosted runners are paid for.

## 6. Out of scope

| Idea | Why not |
|---|---|
| A custom glibc or loader with standard search paths | Needs compute and a cache (constraints 1 and 2) |
| An FHS-prefix rebuild of nixpkgs | Loses the cache entirely |
| An installer ISO or channels | Hosting (constraint 2). Use the NixOS ISO |
| i686 multilib, Steam profiles, desktop library sets | Belong in downstream modules |
| A `fyx why` diagnostics tool | Nice to have later, not needed for compatibility |

## 7. Open questions

1. nix-ld's library directory path inside the system profile, and whether `/usr/lib`
   can point to it directly (§3.2).
2. nix-ld behaviour without `NIX_LD_LIBRARY_PATH` set (§3.1).
3. Whether NixOS activation conflicts with a `/usr/lib` or `/lib` link. NixOS already
   manages `/usr/bin/env`.
4. aarch64: nix-ld supports it. Confirm the paths (`/lib/ld-linux-aarch64.so.1`).
