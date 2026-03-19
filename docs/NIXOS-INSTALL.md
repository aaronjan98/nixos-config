# NixOS Install

This document describes a manual NixOS installation flow for a new laptop before the higher-level machine bootstrap takes over.

It is based on AJ's ThinkPad setup, but written to be generally reusable.

This document focuses on:
- preparing installer media
- wiping and partitioning the disk
- setting up LUKS encryption
- setting up Btrfs subvolumes
- installing NixOS
- booting into the new system

After the base install is complete, continue with:
- `MANUAL-BOOTSTRAP.md`
- `NEW-MACHINE-SETUP.md`

---

## 1. Create installer USB

### Download the ISO
Go to:

- `https://nixos.org/download/`

Download the graphical ISO for 64-bit Intel/AMD systems.

### Verify the ISO checksum

    sha256sum ~/Downloads/nixos-*.iso

Compare it with the SHA-256 checksum published on the download page.

### Identify the USB drive

    lsblk

Be absolutely sure which device is the USB drive.

### Unmount the USB drive

    sudo umount /dev/sda*

Replace `/dev/sda` with the correct device if needed.

### Flash the ISO

    sudo dd if=~/Downloads/nixos-graphical-25.11.650.8bb5646e0bed-x86_64-linux.iso of=/dev/sda bs=4M status=progress oflag=sync && sync

Replace:
- `if=` with the actual ISO path
- `of=` with the actual USB device

### Eject the USB

    sudo eject /dev/sda

---

## 2. Boot the live environment

Boot from the USB and open a terminal in the live environment.

Connect to Wi-Fi if needed:

    sudo nmtui

Verify networking:

    nmcli device status
    ip addr show

---

## 3. Inspect the target disk

Check detected disks:

    lsblk

In AJ's case the target disk was:

- `/dev/nvme0n1`

Adjust commands below if your device is different.

---

## 4. Wipe the target disk

These commands destroy old partition tables and signatures.

    sudo wipefs -a /dev/nvme0n1
    sudo sgdisk -Z /dev/nvme0n1

---

## 5. Create GPT partitions

This layout uses:
- EFI partition: 512 MB
- main partition: rest of disk, later encrypted with LUKS

    sudo sgdisk -o /dev/nvme0n1
    sudo sgdisk -n 1:2048:+512M -t 1:ef00 /dev/nvme0n1
    sudo sgdisk -n 2:0:0 -t 2:8300 /dev/nvme0n1

Resulting layout:
- `/dev/nvme0n1p1` → EFI
- `/dev/nvme0n1p2` → main partition for LUKS

---

## 6. Set up LUKS encryption

Encrypt the main partition:

    sudo cryptsetup luksFormat /dev/nvme0n1p2

Then open it:

    sudo cryptsetup open /dev/nvme0n1p2 luksroot

Verify mapper device exists:

    ls /dev/mapper

---

## 7. Format as Btrfs

    sudo mkfs.btrfs /dev/mapper/luksroot

---

## 8. Create Btrfs subvolumes

Mount temporarily:

    sudo mount /dev/mapper/luksroot /mnt

Create subvolumes:

    sudo btrfs subvolume create /mnt/@
    sudo btrfs subvolume create /mnt/@home
    sudo btrfs subvolume create /mnt/@nix
    sudo btrfs subvolume create /mnt/@swap
    sudo btrfs subvolume create /mnt/@var_log

Verify:

    sudo btrfs subvolume list /mnt

---

## 9. Remount subvolumes

Unmount temporary mount:

    sudo umount /mnt

Mount root subvolume:

    sudo mount -o subvol=@,compress=zstd,noatime /dev/mapper/luksroot /mnt

Create mount points:

    sudo mkdir -p /mnt/{home,nix,swap,var/log}

Mount remaining subvolumes:

    sudo mount -o subvol=@home,compress=zstd,noatime /dev/mapper/luksroot /mnt/home
    sudo mount -o subvol=@nix,compress=zstd,noatime /dev/mapper/luksroot /mnt/nix
    sudo mount -o subvol=@swap,noatime /dev/mapper/luksroot /mnt/swap
    sudo mount -o subvol=@var_log,compress=zstd,noatime /dev/mapper/luksroot /mnt/var/log

---

## 10. Format and mount EFI partition

Format EFI:

    sudo mkfs.fat -F 32 /dev/nvme0n1p1

Mount it:

    sudo mkdir -p /mnt/boot
    sudo mount /dev/nvme0n1p1 /mnt/boot

Sanity check:

    lsblk -f

---

## 11. Generate initial NixOS config

    sudo nixos-generate-config --root /mnt

This creates:
- `/mnt/etc/nixos/hardware-configuration.nix`
- `/mnt/etc/nixos/configuration.nix`

---

## 12. Install NixOS

Once mounts and config are correct:

    sudo nixos-install

Set the root password when prompted.

Then reboot:

    sudo reboot

Remove the USB when appropriate.

---

## 13. First boot

On first boot you should:
- unlock the LUKS device
- log into the installed system
- clone `~/nixos-config`
- continue with `MANUAL-BOOTSTRAP.md`

---

## Notes

This document covers base OS installation only.

After installation:
- do not try to solve secrets and workspace bootstrap from the live ISO
- instead log into the installed system and continue with the manual/bootstrap docs

That keeps the process cleaner and easier to maintain.
