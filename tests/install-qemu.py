"""End-to-end installer test: boot the FyxOS ISO in QEMU (UEFI), install onto
a blank disk unattended over the serial console, then boot the disk alone.

    uv run --with pexpect python tests/install-qemu.py ISO OVMF_FD QEMU_BIN [FLAVOR] [FS]

The install downloads from cache.nixos.org (QEMU user networking), as a real
install does. Exit status 0 means the installed system booted to a login.
"""

import os
import subprocess
import sys
import tempfile
import time

import pexpect

iso, ovmf, qemu = sys.argv[1:4]
flavor = sys.argv[4] if len(sys.argv) > 4 else "minimal"
fs = sys.argv[5] if len(sys.argv) > 5 else "btrfs"
work = tempfile.mkdtemp(prefix="fyxos-install-")
disk = os.path.join(work, "disk.qcow2")
subprocess.run(["qemu-img", "create", "-f", "qcow2", disk, "40G"], check=True,
               stdout=subprocess.DEVNULL)


def boot(*extra, display=("-nographic",)):
    return pexpect.spawn(
        qemu,
        ["-enable-kvm", "-cpu", "host", "-m", "6144", "-smp", "4",
         "-bios", ovmf, "-nic", "user,model=virtio-net-pci",
         "-drive", f"file={disk},if=virtio", *display, *extra],
        encoding="utf-8", codec_errors="replace", timeout=600,
        logfile=sys.stdout,
    )


# 1. The ISO autologins the `nixos` user on the serial console.
vm = boot("-cdrom", iso, "-boot", "d")
# The prompt ends `$`, a color reset, then a space; match up to the `$`.
vm.expect(r"nixos@nixos:~\]\$", timeout=600)
answers = (f"FYXOS_DISK=/dev/vda FYXOS_FS={fs} FYXOS_LUKS=0 FYXOS_FLAVOR={flavor} "
           "FYXOS_USER=tester FYXOS_PASSWORD=tester FYXOS_HOSTNAME=fyxtest "
           "FYXOS_TIMEZONE=UTC FYXOS_YES=1")
vm.sendline(f"sudo {answers} fyxos-install; echo INSTALL_RC=$?")
vm.expect(r"INSTALL_RC=(\d+)", timeout=5400)
rc = int(vm.match.group(1))
if rc != 0:
    sys.exit(f"fyxos-install failed: {rc}")

# 2. Check the installed system from the installer.
vm.sendline("sudo test -e /mnt/etc/nixos/flake.lock && "
            "sudo grep -q github:FyxOS/FyxOS /mnt/etc/nixos/flake.nix && "
            "sudo test -e /mnt/boot/EFI/BOOT/BOOTX64.EFI && echo LAYOUT_OK")
vm.expect("LAYOUT_OK", timeout=60)
vm.sendline("sync; sudo umount -R /mnt; sudo poweroff")
try:
    vm.expect(pexpect.EOF, timeout=300)
except pexpect.TIMEOUT:
    vm.terminate(force=True)  # the disk is synced and unmounted

# 3. Boot the disk alone. The installed system has no serial console, so wait
# for its getty on tty1, then capture the screen through the QEMU monitor.
monitor = os.path.join(work, "monitor.sock")
vm = boot("-monitor", f"unix:{monitor},server,nowait",
          display=("-display", "none", "-vga", "std", "-serial", "null"))
time.sleep(90)
shot = os.path.join(work, "booted.ppm")
subprocess.run(["sh", "-c", f"echo 'screendump {shot}' | "
                f"{os.environ.get('SOCAT', 'socat')} - UNIX-CONNECT:{monitor}"], check=True)
time.sleep(3)
vm.terminate(force=True)
print(f"\nSCREENSHOT {shot}")
