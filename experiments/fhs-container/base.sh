#!/bin/sh
# Build-time: what every mode's image shares. A NixOS-shaped root (nixos/nix
# has only /bin/sh and /usr/bin/env, like stock NixOS), the native tools the
# corpus drives, and the FHS layers from one pinned nixpkgs revision.
set -eu
REV=c59305bab2065cfecc4944690d9eedbb56f3a9fa   # nixos-unstable, 2026-10-02
echo 'experimental-features = nix-command flakes' >> /etc/nix/nix.conf

# A separate profile: the image's own profile already holds curl, gzip and friends.
P=github:NixOS/nixpkgs/$REV
nix profile add --profile /tools \
  "$P#curl" "$P#gnutar" "$P#gzip" "$P#xz" "$P#uv" "$P#gcc" "$P#file" \
  "$P#patchelf" "$P#findutils" "$P#gnugrep" "$P#which"

nix build --impure --file /fhs-src/layers.nix -o /fhs

# Every NixOS system has /etc/zoneinfo; the container image does not.
ln -s /fhs/tzdata/share/zoneinfo /etc/zoneinfo

# nixos/nix links /usr/share to /nix/var/nix/profiles/share, which does not
# exist; the profile's share is /nix/var/nix/profiles/default/share
# (NixOS/nix docker.nix). Repair it until the upstream fix ships.
if [ ! -e /usr/share/. ]; then
  rm /usr/share
  ln -s /nix/var/nix/profiles/default/share /usr/share
fi
