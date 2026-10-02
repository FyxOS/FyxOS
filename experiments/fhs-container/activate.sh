#!/bin/sh
# Build-time activation of one FHS mode, the container analogue of switching
# to a NixOS generation: it runs once, when the mode's image is built, and the
# corpus never changes a system path at run time.
#
#   stock    programs.nix-ld.enable = true, module defaults only
#   base     FyxOS: base library set, /usr/lib + /lib, ldconfig, envfs
#   desktop  base + the desktop preset
set -eu
MODE=$1
L=/fhs/$MODE
mkdir -p /lib64 /run/current-system
ln -s "$(readlink -f "$L/ldso")" /lib64/ld-linux-x86-64.so.2
ln -s "$(readlink -f "$L/sw")" /run/current-system/sw
[ "$MODE" = stock ] && exit 0

# FyxOS design §4.2: the standard library paths are the nix-ld tree.
ln -s /run/current-system/sw/share/nix-ld/lib /usr/lib
ln -s /usr/lib /lib

# nixpkgs' ldconfig reads a cache inside its own store path unless given -C,
# and ctypes.util.find_library asks `/sbin/ldconfig -p`.
mkdir -p /sbin
printf '#!/bin/sh\nexec /fhs/glibc-bin/bin/ldconfig -C /etc/ld.so.cache "$@"\n' > /sbin/ldconfig
chmod +x /sbin/ldconfig
/sbin/ldconfig -f /dev/null -X /usr/lib

# envfs, emulated (no FUSE in a container): these names resolve on PATH.
ln -s /fhs-src/envfs-shim /usr/bin/python3
ln -s /fhs-src/envfs-shim /bin/true
