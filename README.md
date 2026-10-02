# FyxOS

**NixOS, plus the standard Linux library layout. Nothing else.**

On NixOS, a binary built for "Linux" usually fails to start:

```console
$ ./some-vendor-tool
bash: ./some-vendor-tool: cannot execute: required file not found
```

It needs `/lib64/ld-linux-x86-64.so.2`, `/usr/lib`, and `/usr/bin/python3`, which every
other distribution has. Many kinds of prebuilt software assume those paths:

- manylinux wheels
- npm and Cargo prebuilt binaries
- rustup
- VS Code Server
- JetBrains IDEs
- AppImages
- vendor SDKs

FyxOS adds those paths, so such binaries run unmodified.

## Small on purpose

FyxOS is a **single NixOS module**, imported from a flake. It is not a fork:

- **No packages of its own.** Everything comes from your nixpkgs and
  `cache.nixos.org`. FyxOS builds nothing heavier than a symlink tree.
- **Almost no infrastructure.** No binary cache, no channel. The one thing FyxOS hosts is
  an installer ISO. That ISO is the stock NixOS installer with the FyxOS flake preloaded,
  so a fresh install is FyxOS from the first boot. You can also add the module to an
  existing NixOS system.
- **Reuses what nixpkgs already ships.** The loader is
  [nix-ld](https://github.com/nix-community/nix-ld). FyxOS's job is to turn it on by
  default and give it the standard paths.

```nix
{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  inputs.fyxos.url = "github:FyxOS/FyxOS";
  inputs.fyxos.inputs.nixpkgs.follows = "nixpkgs";

  outputs = { nixpkgs, fyxos, ... }: {
    nixosConfigurations.laptop = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [ ./configuration.nix fyxos.nixosModules.default ];
    };
  };
}
```

## What it adds

| Path | Provided by |
|---|---|
| `/lib64/ld-linux-x86-64.so.2` | nix-ld's loader shim (from nixpkgs) |
| `/usr/lib`, `/lib` | Symlink to the current generation's library set |
| `/usr/bin/bash`, `/bin/bash`, `/usr/bin/python3`, … | Symlinks to declared interpreters |

Everything points through `/run/current-system`, so switching generations and rolling
back already work, with no extra machinery.

## Status

**Design phase.** See [design](docs/design.md), [prior art](docs/prior-art.md), and
[roadmap](docs/roadmap.md).

Desktop opinions do not belong here. They live in separate projects such as
[Autarchy](https://github.com/FyxOS/Autarchy).

## Relationship to NixOS

FyxOS is independent and not affiliated with or endorsed by the NixOS Foundation. It
depends entirely on nixpkgs, NixOS, and the public `cache.nixos.org`, and anything
useful in it should go upstream.
