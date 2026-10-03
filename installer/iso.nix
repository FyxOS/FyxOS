# The FyxOS installer ISO: nixpkgs' stock minimal installer plus fyxos-install
# with its registry and templates (design §7).
{ config, lib, pkgs, modulesPath, nixpkgsRev, ... }:
let
  fyxos-install = pkgs.writeShellApplication {
    name = "fyxos-install";
    runtimeInputs = with pkgs; [ gum jq disko curl util-linux pciutils networkmanager nixos-install-tools gnused coreutils ];
    text = builtins.readFile ./fyxos-install.sh;
  };
in
{
  imports = [ "${modulesPath}/installer/cd-dvd/installation-cd-minimal.nix" ];

  environment.systemPackages = [ fyxos-install pkgs.gum pkgs.disko ];
  environment.etc = {
    "fyxos/flavors.json".source = ../flavors.json;
    "fyxos/disk-layout.nix".source = ./disk-layout.nix;
    "fyxos/flake.nix".source = ./flake.nix.template;
    "fyxos/local.nix".source = ./local.nix.template;
    "fyxos/nixpkgs-rev".text = nixpkgsRev;
  };

  networking.networkmanager.enable = true;
  networking.wireless.enable = lib.mkForce false;
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  # A serial console too, so the installer can be driven headless (tests, servers).
  boot.kernelParams = [ "console=ttyS0,115200n8" "console=tty0" ];

  image.baseName = lib.mkForce "fyxos";
  isoImage.volumeID = lib.mkForce "FYXOS";
  services.getty.helpLine = lib.mkForce ''
    Welcome to the FyxOS installer. Run: sudo fyxos-install
  '';
}
