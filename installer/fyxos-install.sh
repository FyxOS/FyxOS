#!/usr/bin/env bash
# FyxOS installer (design §7): network, disk, flavor, user, then nixos-install.
#
# Every answer can come from the environment instead of a prompt, which is how
# the installer is tested unattended:
#   FYXOS_DISK FYXOS_FS FYXOS_LUKS FYXOS_FLAVOR FYXOS_USER FYXOS_PASSWORD
#   FYXOS_HOSTNAME FYXOS_TIMEZONE FYXOS_YES=1 (skip the wipe confirmation)
set -euo pipefail
# Unset answers are asked for below.
FYXOS_DISK=${FYXOS_DISK:-} FYXOS_FS=${FYXOS_FS:-} FYXOS_LUKS=${FYXOS_LUKS:-}
FYXOS_FLAVOR=${FYXOS_FLAVOR:-} FYXOS_USER=${FYXOS_USER:-} FYXOS_PASSWORD=${FYXOS_PASSWORD:-}
FYXOS_HOSTNAME=${FYXOS_HOSTNAME:-} FYXOS_TIMEZONE=${FYXOS_TIMEZONE:-} FYXOS_YES=${FYXOS_YES:-}
ETC=/etc/fyxos
NIXPKGS_REV=$(cat $ETC/nixpkgs-rev)
MNT=/mnt

die() { gum style --foreground 1 "fyxos-install: $*" >&2; exit 1; }
ask() { # var, prompt, [default]
  local current=${!1:-}
  [ -n "$current" ] && return
  printf -v "$1" '%s' "$(gum input --header "$2" --value "${3:-}")"
}
choose() { # var, header, options...
  local var=$1 header=$2; shift 2
  [ -n "${!var:-}" ] && return
  printf -v "$var" '%s' "$(gum choose --header "$header" "$@")"
}

[ "$(id -u)" = 0 ] || die "run as root (sudo fyxos-install)"
gum style --border rounded --padding "0 2" --bold "FyxOS installer"

# 1. Network: everything after this downloads from cache.nixos.org. Give a
# wired link up to a minute for DHCP before asking.
online() { curl -fsS --max-time 5 -o /dev/null https://cache.nixos.org/nix-cache-info; }
for _ in $(seq 30); do online && break; sleep 2; done
until online; do
  [ -n "${FYXOS_YES:-}" ] && die "no network"
  gum confirm "No network. Open nmtui to connect?" || die "a network is required"
  nmtui
done

# 2. Disk: the whole chosen disk; v1 has no dual-boot.
mapfile -t disks < <(lsblk -dpno NAME,SIZE,MODEL -e 1,7,11 | sed 's/  */ /g')
[ ${#disks[@]} -gt 0 ] || die "no disks found"
if [ -z "${FYXOS_DISK:-}" ]; then
  FYXOS_DISK=$(gum choose --header "Install to which disk? (it will be ERASED)" "${disks[@]}" | cut -d' ' -f1)
fi
choose FYXOS_FS "Filesystem" ext4 btrfs xfs
case $FYXOS_FS in ext4 | btrfs | xfs) ;; *) die "unknown filesystem $FYXOS_FS" ;; esac
if [ -z "${FYXOS_LUKS:-}" ]; then
  gum confirm "Encrypt the disk (LUKS)?" --default=false && FYXOS_LUKS=1 || FYXOS_LUKS=0
fi
EFI=false; [ -d /sys/firmware/efi ] && EFI=true

# 3. Flavor: the live registry, so a new flavor needs no new ISO; the ISO's
# own copy if GitHub is unreachable. Only ready entries are offered.
REGISTRY=/tmp/fyxos-flavors.json
if ! curl -fsS --max-time 10 -o $REGISTRY https://raw.githubusercontent.com/FyxOS/FyxOS/main/flavors.json \
  || ! jq -e 'type == "array"' $REGISTRY >/dev/null; then
  cp $ETC/flavors.json $REGISTRY
fi
mapfile -t flavors < <(jq -r '.[] | select(.status == "ready") | "\(.id)\t\(.name) — \(.description)"' $REGISTRY)
[ ${#flavors[@]} -gt 0 ] || die "the flavor registry has no ready flavors"
if [ -z "${FYXOS_FLAVOR:-}" ]; then
  FYXOS_FLAVOR=$(printf '%s\n' "${flavors[@]}" | gum choose --header "What kind of system do you want?" | cut -f1)
fi
flavor_json=$(jq -c --arg id "$FYXOS_FLAVOR" '.[] | select(.id == $id and .status == "ready")' $REGISTRY)
[ -n "$flavor_json" ] || die "unknown or unready flavor $FYXOS_FLAVOR"
flavor_flake=$(jq -r '.flake // empty' <<<"$flavor_json")
flavor_module=$(jq -r '.module // empty' <<<"$flavor_json")

# 4. User.
ask FYXOS_USER "Username"
[[ $FYXOS_USER =~ ^[a-z_][a-z0-9_-]*$ ]] || die "invalid username $FYXOS_USER"
if [ -z "${FYXOS_PASSWORD:-}" ]; then
  FYXOS_PASSWORD=$(gum input --password --header "Password for $FYXOS_USER")
  [ "$FYXOS_PASSWORD" = "$(gum input --password --header "Again")" ] || die "passwords differ"
fi
ask FYXOS_HOSTNAME "Hostname" fyxos
ask FYXOS_TIMEZONE "Timezone" "$(timedatectl show -p Timezone --value 2>/dev/null || echo UTC)"

if [ -z "${FYXOS_YES:-}" ]; then
  gum confirm "Erase $FYXOS_DISK and install FyxOS ($FYXOS_FLAVOR, $FYXOS_FS$([ "$FYXOS_LUKS" = 1 ] && echo ", encrypted"))?" || die "cancelled"
fi

# Partition, format and mount with disko.
luks=false; [ "$FYXOS_LUKS" = 1 ] && luks=true
cat > /tmp/fyxos-disk.nix <<NIX
import $ETC/disk-layout.nix { device = "$FYXOS_DISK"; fs = "$FYXOS_FS"; luks = $luks; efi = $EFI; }
NIX
disko --mode destroy,format,mount --yes-wipe-all-disks /tmp/fyxos-disk.nix

# 5. Hardware, and the machine flake the user owns.
nixos-generate-config --root $MNT
D=$MNT/etc/nixos
rm -f $D/configuration.nix
nvidia=false; lspci 2>/dev/null | grep -qi 'vga.*nvidia\|3d.*nvidia' && nvidia=true
sed -e "s|@HOSTNAME@|$FYXOS_HOSTNAME|" -e "s|@TIMEZONE@|$FYXOS_TIMEZONE|" \
  -e "s|@USER@|$FYXOS_USER|" -e "s|@EFI@|$EFI|" -e "s|@DISK@|$FYXOS_DISK|" \
  -e "s|@NVIDIA@|$nvidia|" $ETC/local.nix > $D/local.nix
if [ -n "$flavor_flake" ]; then
  flavor_input="flavor = { url = \"$flavor_flake\"; inputs.nixpkgs.follows = \"nixpkgs\"; inputs.fyxos.follows = \"fyxos\"; };"
  flavor_args="flavor, "
  flavor_modules="flavor.nixosModules.$flavor_module"
else
  flavor_input="" flavor_args="" flavor_modules=""
fi
sed -e "s|@FLAVOR_INPUT@|$flavor_input|" -e "s|@FLAVOR_ARGS@|$flavor_args|" \
  -e "s|@FLAVOR_MODULES@|$flavor_modules|" $ETC/flake.nix > $D/flake.nix
# Lock nixpkgs to the ISO's own revision: the versions the ISO was built and
# tested with, all on cache.nixos.org.
(cd $D && nix --extra-experimental-features 'nix-command flakes' flake lock \
  --override-input nixpkgs "github:NixOS/nixpkgs/$NIXPKGS_REV")

# 6. Install.
nixos-install --root $MNT --flake "$D#fyxos" --no-root-passwd
echo "$FYXOS_USER:$FYXOS_PASSWORD" | nixos-enter --root $MNT -c chpasswd
gum style --foreground 2 "FyxOS is installed. Reboot when ready."
