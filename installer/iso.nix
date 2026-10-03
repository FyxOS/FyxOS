# The Omnix installer ISO: nixpkgs' stock minimal installer plus omnix-install
# with its registry and templates (design §7).
{ config, lib, pkgs, modulesPath, nixpkgsRev, ... }:
let
  omnix-install = pkgs.writeShellApplication {
    name = "omnix-install";
    runtimeInputs = with pkgs; [ gum jq disko curl util-linux pciutils networkmanager nixos-install-tools gnused coreutils ];
    text = builtins.readFile ./omnix-install.sh;
  };
in
{
  imports = [ "${modulesPath}/installer/cd-dvd/installation-cd-minimal.nix" ];

  environment.systemPackages = [ omnix-install pkgs.gum pkgs.disko ];
  environment.etc = {
    "omnix/flavors.json".source = ../flavors.json;
    "omnix/disk-layout.nix".source = ./disk-layout.nix;
    "omnix/flake.nix".source = ./flake.nix.template;
    "omnix/local.nix".source = ./local.nix.template;
    "omnix/nixpkgs-rev".text = nixpkgsRev;
  };

  networking.networkmanager.enable = true;
  networking.wireless.enable = lib.mkForce false;
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  # A serial console too, so the installer can be driven headless (tests, servers).
  boot.kernelParams = [ "console=ttyS0,115200n8" "console=tty0" ];

  image.baseName = lib.mkForce "omnix";
  isoImage.volumeID = lib.mkForce "OMNIX";
  services.getty.helpLine = lib.mkForce ''
    Welcome to the Omnix installer. Run: sudo omnix-install
  '';
}
