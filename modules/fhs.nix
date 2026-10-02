# FyxOS base: the standard Linux library layout on NixOS (docs/design.md §4).
#
#   /lib64/ld-linux-x86-64.so.2  nix-ld's loader shim
#   /usr/lib, /lib               the nix-ld library tree
#   /sbin/ldconfig               glibc's ldconfig on /etc/ld.so.cache
#   /etc/ld.so.cache             rebuilt from /usr/lib on boot and every switch
#   /bin, /usr/bin               envfs: any name on the caller's PATH
#
# Everything comes from nixpkgs as-is (rule 4); the only local builds are
# symlink trees and text files (rule 1).
{ config, lib, pkgs, ... }:
let
  cfg = config.fyx.fhs;

  # Sonames nixpkgs no longer ships under the name foreign binaries ask for.
  legacySonameShims = pkgs.runCommand "fyx-legacy-soname-shims" { } ''
    mkdir -p $out/lib
    # libxml2 moved to .so.16 in 2.15; prebuilt LLVM tools still ask for .so.2.
    ln -s ${pkgs.libxml2.out}/lib/libxml2.so $out/lib/libxml2.so.2
  '';

  # §4.2. nix-ld's own defaults (zlib, openssl, systemd, ...) merge in.
  baseLibraries = with pkgs; [
    stdenv.cc.cc.lib libffi libxcrypt elfutils libunwind
    libxcrypt-legacy
    ncurses readline sqlite expat pcre2 icu
    lz4 brotli snappy
    legacySonameShims
  ];

  desktopLibraries = with pkgs; [
    glib gtk3 cairo pango atk gdk-pixbuf at-spi2-atk at-spi2-core
    nss nspr dbus fontconfig freetype
    libGL libdrm libxkbcommon mesa libgbm vulkan-loader
    libx11 libxcomposite libxdamage libxext libxfixes libxrandr libxrender libxi libxtst
    libxscrnsaver libxcb libxcursor libxshmfence
    webkitgtk_4_1 libsoup_3 alsa-lib libpulseaudio cups
  ];

  libraryTree = "/run/current-system/sw/share/nix-ld/lib";

  # nixpkgs' ldconfig reads a cache inside its own store path unless given -C.
  ldconfig = pkgs.writeShellScript "ldconfig" ''
    exec ${pkgs.glibc.bin}/bin/ldconfig -C /etc/ld.so.cache "$@"
  '';
in
{
  options.fyx.fhs = {
    enable = lib.mkEnableOption "the standard Linux library layout" // {
      default = true;
    };
    libraries = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [ ];
      description = "Extra libraries for /usr/lib, beyond the base set.";
    };
    presets.desktop = lib.mkEnableOption ''
      the desktop library set: GTK, WebKitGTK, mesa, X11 and audio clients, for
      Electron apps, Playwright browsers and prebuilt GUI tools
    '';
  };

  config = lib.mkIf cfg.enable {
    programs.nix-ld.enable = true;
    programs.nix-ld.libraries =
      baseLibraries ++ lib.optionals cfg.presets.desktop desktopLibraries ++ cfg.libraries;

    services.envfs.enable = true;

    systemd.tmpfiles.rules = [
      "L+ /usr/lib - - - - ${libraryTree}"
      "L+ /lib - - - - /usr/lib"
      "d /sbin 0755 root root - -"
      "L+ /sbin/ldconfig - - - - ${ldconfig}"
    ];

    # Python's ctypes.util.find_library asks `/sbin/ldconfig -p`. The cache only
    # answers queries; no loader reads it (§4.3).
    systemd.services.fyx-ldconfig = {
      description = "Rebuild /etc/ld.so.cache from /usr/lib";
      wantedBy = [ "multi-user.target" ];
      after = [ "systemd-tmpfiles-setup.service" ];
      restartTriggers = [ config.programs.nix-ld.libraries ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "${ldconfig} -f /dev/null -X /usr/lib";
      };
    };
  };
}
