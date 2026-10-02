# Roadmap

Every phase stays inside the [constraints](design.md#1-constraints). All testing happens in
VMs or on spare disks, never on a live machine that someone depends on.

## Phase 0: validation

In a NixOS-unstable VM, set the base options by hand and resolve the **[verify]** items
in the [design](design.md). Then run this corpus of foreign binaries unmodified:

- manylinux wheels (`pip install numpy torch`)
- rustup and a Go release binary
- a prebuilt LLVM `ld.lld`
- an AppImage
- Playwright's Chromium
- a script with `#!/usr/bin/python3`

**Exit:** the corpus runs, and the closure has nothing to build.

Progress: the container half is done in
[`experiments/fhs-container`](../experiments/fhs-container/). Everything except
the store-loader gap passes on the base and desktop modes. What remains needs a
booted NixOS VM: real envfs (FUSE) and activation of the `/usr/lib` and `/lib`
links.

## Phase 1: the base

- `flake.nix` with `nixosModules.default`.
- `fyx.fhs.libraries`, the desktop preset, and envfs.
- A NixOS VM test for the corpus.

**Exit:** a NixOS-unstable system that imports the module runs the corpus.

## Phase 2: Atrium

- Write [Atrium](https://github.com/FyxOS/Atrium) from scratch as a declarative KDE
  flavor.
- Pass the flavor contract.

**Exit:** Atrium installs in a VM with nothing to build except unfree drivers.

## Phase 3: installer

- `fyxos-install` (gum), disko presets, `flavors.json` with Minimal and Atrium.
- `nix build .#iso`, and the first ISO on GitHub Releases.

**Exit:** boot the ISO in a VM, choose Atrium, and reboot into a working desktop.

## Phase 4: Autarchy

- [Autarchy](https://github.com/FyxOS/Autarchy) `stable`, pinned to an Omarchy release.
  Then `latest`.
- Add both to the registry.

**Exit:** both variants install from the same ISO. This is the reproducibility proof.

## Phase 5: switchover

The maintainer's own workstation moves from its plain-NixOS configuration to a private
machine flake that imports FyxOS and Atrium. The maintainer starts this step; no phase
triggers it automatically.

## v2

- Dual-boot: install into free space beside another OS.
- Third-party flavors, by pull request and contract check.
- A `fyxos flavor switch` helper.
- Small fixes sent upstream to nixpkgs, such as the nix-ld docs and library list.
