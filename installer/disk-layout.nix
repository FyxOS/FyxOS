# One whole-disk layout for disko, from the installer's choices (design §7).
#   device  the target disk, e.g. /dev/nvme0n1
#   fs      "ext4" | "btrfs" | "xfs"   (btrfs gets @, @home, @nix, @snapshots)
#   luks    encrypt the root partition (the passphrase is asked for interactively)
#   efi     an ESP for systemd-boot; otherwise a BIOS boot partition for GRUB
{ device, fs, luks ? false, efi ? true }:
let
  filesystem = {
    ext4 = {
      type = "filesystem";
      format = "ext4";
      mountpoint = "/";
    };
    xfs = {
      type = "filesystem";
      format = "xfs";
      # reflink is mkfs.xfs's default; stated, since cheap copies are why XFS is offered.
      extraArgs = [ "-m" "reflink=1" ];
      mountpoint = "/";
    };
    btrfs = {
      type = "btrfs";
      extraArgs = [ "-f" ];
      subvolumes = {
        "@" = { mountpoint = "/"; mountOptions = [ "compress=zstd" "noatime" ]; };
        "@home" = { mountpoint = "/home"; mountOptions = [ "compress=zstd" "noatime" ]; };
        "@nix" = { mountpoint = "/nix"; mountOptions = [ "compress=zstd" "noatime" ]; };
        "@snapshots" = { mountpoint = "/.snapshots"; mountOptions = [ "compress=zstd" "noatime" ]; };
      };
    };
  }.${fs};
  root =
    if luks then {
      type = "luks";
      name = "cryptroot";
      askPassword = true;
      settings.allowDiscards = true;
      content = filesystem;
    } else filesystem;
in
{
  disko.devices.disk.main = {
    type = "disk";
    inherit device;
    content = {
      type = "gpt";
      partitions =
        (if efi then {
          ESP = {
            size = "1G";
            type = "EF00";
            content = {
              type = "filesystem";
              format = "vfat";
              mountpoint = "/boot";
              mountOptions = [ "umask=0077" ];
            };
          };
        } else {
          boot = {
            size = "1M";
            type = "EF02";
          };
        })
        // {
          root = {
            size = "100%";
            content = root;
          };
        };
    };
  };
}
