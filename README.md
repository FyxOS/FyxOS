# FyxOS

**NixOS with the standard Linux layout, and a choice of systems at install time.**

FyxOS has two parts:

1. **A base:** NixOS (unstable) plus a small layer that gives it the standard library
   layout other distributions have. Prebuilt software then just runs: manylinux wheels,
   rustup, vendor SDKs, AppImages, Electron apps.
2. **An installer:** a small ISO that asks *"What kind of system do you want?"* and
   installs the flavor you choose over the network, straight from `cache.nixos.org`.

```
FyxOS installer
  ▸ What kind of system do you want?
      Atrium            polished windows, mouse-first KDE desktop
      Autarchy          Omarchy-style keyboard-driven Hyprland (stable or latest)
      Minimal           just the base
```

## The FHS problem

On NixOS, a binary built for "Linux" usually fails to start:

```console
$ ./some-vendor-tool
bash: ./some-vendor-tool: cannot execute: required file not found
```

It needs `/lib64/ld-linux-x86-64.so.2`, `/usr/lib`, and `/usr/bin/python3`, which every
other distribution provides. The FyxOS base adds them using tools nixpkgs already ships:
[nix-ld](https://github.com/nix-community/nix-ld) and
[envfs](https://github.com/Mic92/envfs). It never relocates the Nix store, so every
package still comes from the official binary cache.

## Flavors

A flavor is a flake that turns the base into a complete system. Each one lives in its
own repository:

| Flavor | What it is |
|---|---|
| [Atrium](https://github.com/FyxOS/Atrium) | KDE Plasma desktop, polished windows, mouse-first |
| [Autarchy](https://github.com/FyxOS/Autarchy) | A port of Omarchy, in *stable* (a pinned Omarchy release) and *latest* variants |
| Minimal | The base alone |

The installed system is a flake that **you** own. The flavor is just one input. You
switch flavors by changing that input and rebuilding, and you can return to the
previous one from the boot menu.

## Small on purpose

- **No packages of its own.** Everything comes from nixpkgs and `cache.nixos.org`.
- **No infrastructure** beyond a minimal installer ISO on GitHub Releases. There is no
  binary cache, channel, or website.
- **Opinions live in flavors.** The base only provides FHS compatibility.

## Status

**Design phase.** See [design](docs/design.md), [prior art](docs/prior-art.md), and
[roadmap](docs/roadmap.md). The flavor registry is [`flavors.json`](flavors.json).

## Relationship to NixOS

FyxOS is independent and not affiliated with or endorsed by the NixOS Foundation. It
depends entirely on nixpkgs, NixOS, and the public `cache.nixos.org`. Small fixes that
belong upstream go upstream.
