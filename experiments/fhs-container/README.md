# FHS container experiment

This experiment runs unmodified foreign binaries on a NixOS-shaped root, once
per FHS mode, under [bosn](https://github.com/zackees/bosn).

| Mode | What the image activates |
|---|---|
| `baseline` | Nothing: stock NixOS paths only (`/bin/sh`, `/usr/bin/env`, `/etc/zoneinfo`) |
| `stock` | `programs.nix-ld.enable = true` with the module's default libraries |
| `base` | The Omnix base: library set, `/usr/lib` and `/lib`, an `ldconfig` wrapper with a cache built at activation, and envfs (emulated) |
| `desktop` | `base` plus the desktop preset |

Each mode is its own image (`docker/<mode>.Dockerfile`). `activate.sh` runs once
at image build, the way switching to a NixOS generation does. `corpus.sh` never
changes a system path; it writes only `/work` and the machine-scoped `/cache`
volume. Tasks can therefore rerun in their persistent container and measure the
same system every time.

```bash
bosn run --task baseline   # or stock | base | desktop
```

The FHS layers are built from the real NixOS `nix-ld` module at nixos-unstable
`c59305b` (`layers.nix`).

## Results (2026-10-02)

| Check | baseline | stock | base | desktop |
|---|---|---|---|---|
| Node.js tarball | ✗ | ✓ | ✓ | ✓ |
| uv CPython, HTTPS, `zoneinfo` | ✗ | ✓ | ✓ | ✓ |
| numpy wheel | ✗ | ✓ | ✓ | ✓ |
| `ctypes.util.find_library`, `ldconfig -p` | ✗ | ✗ | ✓ | ✓ |
| `libxml2.so.2` shim, CPython 3.11 `crypt` | ✗ | ✗ | ✓ | ✓ |
| `#!/usr/bin/python3`, `/bin/true` | ✗ | ✗ | ✓¹ | ✓¹ |
| rustup + `cargo run` | ✗ | ✓ | ✓ | ✓ |
| AppImage (static runtime) | ✓ | ✓ | ✓ | ✓ |
| Playwright Chromium | ✗ | ✗ | ✗ | ✓ |
| Binary with a Nix-store loader | ✗ | ✗ | ✗ | ✗ (known gap) |

¹ This needs a bosn that keeps a build-context file's execute bit. The fix is
merged on bosn `main` ([zackees/bosn#428](https://github.com/zackees/bosn/pull/428),
on top of [kernal-api 0.1.25](https://github.com/zackees/kernal-api/pull/394)) and
ships with the next bosn release. Older bosn copies `envfs-shim` into the image
without its execute bit, so these two checks fail with `Permission denied`.

## Upstream issues found

- **`nixos/nix` image:** `/usr/share` points at `/nix/var/nix/profiles/share`,
  which does not exist; it should be `/nix/var/nix/profiles/default/share`
  (`docker.nix`). `base.sh` repairs it until the upstream fix ships.
- **bosn:** manifest build contexts dropped file modes. Fixed at the root in
  kernal-api 0.1.25 (released) and bosn#428 (merged).
- **envfs:** names were not resolved on `readlink`, which breaks relocatable
  interpreters behind `#!/usr/bin/python3` on a real booted system
  ([Mic92/envfs#233](https://github.com/Mic92/envfs/pull/233)).
