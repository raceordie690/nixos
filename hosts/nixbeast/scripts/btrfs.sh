#!/usr/bin/env bash

# This script formats an mdadm array, creates Btrfs subvolumes, and mounts them
# for a NixOS installation.
#
# WARNING: This will destroy all data on /dev/md0.
# Run this from the NixOS live environment before running nixos-install.

set -euo pipefail

MD_DEVICE="/dev/md0"
EFI_DEVICE="/dev/disk/by-uuid/AAF00-48DB"
MOUNT_POINT="/mnt"

# --- STEP 3: Create the Btrfs filesystem ---
echo "Creating Btrfs filesystem on ${MD_DEVICE}..."
mkfs.btrfs -f -L nixos "${MD_DEVICE}"

# --- STEP 4: Create the Btrfs subvolumes ---
echo "Mounting top-level Btrfs volume to create subvolumes..."
mount "${MD_DEVICE}" "${MOUNT_POINT}"

echo "Creating Btrfs subvolumes..."
btrfs subvolume create "${MOUNT_POINT}/@"
btrfs subvolume create "${MOUNT_POINT}/@home"
btrfs subvolume create "${MOUNT_POINT}/@nix"
btrfs subvolume create "${MOUNT_POINT}/@var"
btrfs subvolume create "${MOUNT_POINT}/@tmp"
btrfs subvolume create "${MOUNT_POINT}/@data"
btrfs subvolume create "${MOUNT_POINT}/@vm"

echo "Unmounting top-level Btrfs volume..."
umount "${MOUNT_POINT}"

# --- STEP 5: Mount filesystems for NixOS installation ---
echo "Mounting Btrfs subvolumes for NixOS installation..."

# Mount root subvolume
mount -o subvol=@,compress=zstd,ssd,space_cache=v2,noatime "${MD_DEVICE}" "${MOUNT_POINT}"

# Create mount points for other filesystems
mkdir -p "${MOUNT_POINT}"/{home,nix,var,data,vm,efi}

# Mount other subvolumes
mount -o subvol=@home,compress=zstd,ssd,space_cache=v2,noatime "${MD_DEVICE}" "${MOUNT_POINT}/home"
mount -o subvol=@nix,compress=zstd,ssd,space_cache=v2,noatime "${MD_DEVICE}" "${MOUNT_POINT}/nix"
mount -o subvol=@var,compress=zstd,ssd,space_cache=v2,noatime "${MD_DEVICE}" "${MOUNT_POINT}/var"
mount -o subvol=@data,compress=zstd:3,ssd,space_cache=v2,noatime "${MD_DEVICE}" "${MOUNT_POINT}/data"
mount -o subvol=@vm,nodatacow,ssd,space_cache=v2,noatime "${MD_DEVICE}" "${MOUNT_POINT}/vm"
# Note: /tmp is configured as tmpfs, so we don't mount a subvolume for it.

# Mount the primary EFI partition
echo "Mounting EFI partition..."
mount "${EFI_DEVICE}" "${MOUNT_POINT}/efi"

echo "✅ All filesystems mounted successfully."
echo "You can now run 'nixos-generate-config --root /mnt' and 'nixos-install'."
echo "Final mount points:"
lsblk

