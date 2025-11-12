# My NixOS Configuration

This repository contains my personal NixOS configurations, managed using Nix Flakes. It includes system configurations for multiple machines (`nixboss`, `nixbeast`, `nixserve`) and a custom ISO installer.

## Table of Contents

- Prerequisites
- Building the Custom Installer
- Installation on a New Machine
  - Step 2.1: Boot and Connect to Network
  - Step 2.2: Disk Partitioning
  - Step 2.3: Create Swap
  - Step 2.4: Create ZFS Pool and Datasets
  - Step 2.5: Mount Filesystems
  - Step 2.6: Install NixOS
- Post-Installation Management

---

## Prerequisites

- A machine with Nix installed to build the installer ISO.
- The target machine for the new installation.
- A USB drive (at least 4GB).
- An internet connection on the target machine during installation.

---

## 1. Building the Custom Installer

This flake includes a configuration for a custom installer ISO. This is necessary because the standard NixOS installer does not have flakes enabled or ZFS tools pre-installed.

1.  **Build the ISO:**
    From the root of this repository, run:
    ```bash
    nix build .#nixosConfigurations.installer.config.system.build.isoImage
    ```

2.  **Locate the ISO:**
    The build command creates a `result` symlink in your project directory. The ISO file is located at:
    ```
    ./result/iso/nixos-custom-installer.iso
    ```

3.  **Burn to USB:**
    Write the ISO to a USB drive. On Linux, you can use `dd`:
    ```bash
    # Replace /dev/sdX with your USB device (e.g., /dev/sdb)
    # Be very careful! This will wipe the target device.
    sudo dd if=./result/iso/nixos-custom-installer.iso of=/dev/sdX bs=4M conv=fsync status=progress
    ```

---

## 2. Installation on a New Machine

Follow these steps on the target machine after booting from the custom installer USB.

### Step 2.1: Boot and Connect to Network

1.  Boot the target machine from the USB drive. You will be logged into a root shell.
2.  Connect to the internet.
    - For Ethernet, it should connect automatically.
    - For Wi-Fi, run `nmtui` to connect to a network.
3.  Verify connectivity: `ping nixos.org`

### Step 2.2: Disk Partitioning

This guide assumes a UEFI system and will create two partitions: one for EFI and one for ZFS.
**Repeat these steps for each disk** that will be part of your system.
It is **highly recommended** to use stable device paths like `/dev/disk/by-partuuid/` or `/dev/disk/by-id/` instead of `/dev/sdX` or `/dev/nvme0n1`.

1.  **Identify your disk:**
    Use `ls -la /dev/disk/by-partuuid/` to list partitions by their unique UUIDs.

2.  **Set a variable for the disk** (replace with your actual disk):
    (Example using `/dev/disk/by-id/`)
    ```bash
    export DISK=/dev/disk/by-id/your-disk-id
    ```

3.  **Use `gdisk` to partition:**
    ```bash
    sudo gdisk ${DISK}
    ```
    Inside `gdisk`:
    - Press `o` to create a new empty GUID partition table (GPT).
    - Create an EFI partition. For boot redundancy, it's best to create one on each disk.
      - Press `n` for a new partition.
      - Partition number: `1`
      - First sector: (default)
      - Last sector: `+1G` (for a 1GB EFI partition)
      - Hex code: `ef00`
    - Create a swap partition. The size depends on your RAM and needs (e.g., `+16G` for 16GB).
      - Press `n` for a new partition.
      - Partition number: `2`
      - First sector: (default)
      - Last sector: `+16G` (or your desired swap size)
      - Hex code: `8200` (Linux swap)
    - Create the ZFS partition using the remaining space.
      - Press `n` for a new partition.
      - Partition number: `3`
      - First sector: (default)
      - Last sector: (default, to use all remaining space)
      - Hex code: `bf00` (Solaris / ZFS)
    - Press `w` to write changes and exit.

4.  **Format the EFI partition:**
    Format each EFI partition you created. It's good practice to give them unique labels (e.g., `EFI`, `EFI2`).
    (Example using partUUIDs)
    ```bash
    sudo mkfs.vfat -F32 -n EFI /dev/disk/by-partuuid/64446512-5ea8-475e-9bff-4bb490472289
    sudo mkfs.vfat -F32 -n EFI2 /dev/disk/by-partuuid/df6b205b-82f5-48d9-8876-b132b6e0f383
    # ...and so on for each ESP.
    ```
    > **Note:** To make this redundancy work, your NixOS configuration must be set up to install the bootloader to all ESPs using the `boot.loader.efi.extraEfiSystemPartitions` option.

### Step 2.3: Create Swap

1.  **Format the swap partitions:**
    Run `mkswap` on each of the swap partitions you created across all your disks. Use the stable `/dev/disk/by-partuuid/` paths.
    ```bash
    sudo mkswap /dev/disk/by-partuuid/df6b205b-82f5-48d9-8876-b132b6e0f383
    sudo mkswap /dev/disk/by-partuuid/fbaacb93-f630-42ae-927c-43b297902427
    # ...and so on for each swap partition.
    ```

2.  **Enable swap for the installation:**
    This will make swap available to the installer environment, which is useful if you have low RAM.
    ```bash
    sudo swapon --all --priority=-1
    ```
    > **Note:** To make swap permanent, you must add these partitions to your NixOS configuration's `swapDevices` option.

### Step 2.4: Create ZFS Pool and Datasets

1.  **Create the root pool (`rpool`):**
    This command is based on a robust configuration for modern SSDs. It enables good compression, sets a larger record size suitable for general use, and disables `atime` for performance.

    ```bash
    sudo zpool create -f \
        -o ashift=12 \
        -o autotrim=on \
        -o compatibility=off \
        -O acltype=posixacl \
        -O aclinherit=passthrough \
        -O canmount=off \
        -O compression=zstd-5 \
        -O dnodesize=auto \
        -O mountpoint=none \
        -O xattr=sa \
        -O atime=off \
        -O recordsize=1M \
        -O redundant_metadata=most \
        rpool raidz1 \
          /dev/disk/by-partuuid/30be395c-ef39-43d9-bc97-122e53f29dcc \
          /dev/disk/by-partuuid/35567007-09f3-492d-860b-dcc61b974bc8 \
          /dev/disk/by-partuuid/13f4161e-72bf-4798-8c7a-f3b4c801f5d6
    ```
    > **Note:** The command above creates a `raidz1` pool. For a single-disk setup, change the last lines to just `rpool /dev/disk/by-partuuid/<zfs-partition-uuid>`.

2.  **Create ZFS datasets:**
    This layout creates separate datasets, each tuned for its specific workload. **Replace `nixbeast` with the actual hostname you are installing.**

    All datasets use `mountpoint=legacy`, which allows NixOS to manage mounting them via `configuration.nix`.
    ```bash
    # Root
    sudo zfs create -o canmount=noauto -o mountpoint=legacy -o recordsize=128K rpool/nixbeast
    
    # Home
    sudo zfs create -o mountpoint=legacy -o recordsize=128K rpool/home
    
    # /nix store - Crucial for NixOS
    sudo zfs create -o mountpoint=legacy rpool/nix

    # Tmp – fast scratch, no compression, async writes
    sudo zfs create -o mountpoint=legacy -o compression=off -o sync=disabled -o primarycache=metadata rpool/tmp
    
    # Var – small files and frequent writes
    sudo zfs create -o mountpoint=legacy -o recordsize=16K -o logbias=throughput rpool/var
    
    # VM – optimized for virtual disk images
    sudo zfs create -o mountpoint=legacy -o recordsize=16K -o logbias=throughput -o sync=standard rpool/vm
    
    # Data – large sequential files
    sudo zfs create -o mountpoint=legacy -o recordsize=1M -o compression=zstd-3 -o primarycache=metadata rpool/data
    ```

### Step 2.5: Mount Filesystems

1.  **Mount the root and other filesystems:**
    Mount all the ZFS datasets and the EFI partition to their respective locations under `/mnt`.
    ```bash
    # Mount the root filesystem
    sudo mount -t zfs rpool/nixbeast /mnt
    
    # Create directories for the other mountpoints
    sudo mkdir -p /mnt/{boot,home,nix,tmp,var,vm,data}

    # Mount the other datasets
    sudo mount -t zfs rpool/home /mnt/home
    sudo mount -t zfs rpool/nix /mnt/nix
    sudo mount -t zfs rpool/tmp /mnt/tmp
    sudo mount -t zfs rpool/var /mnt/var
    sudo mount -t zfs rpool/vm /mnt/vm
    sudo mount -t zfs rpool/data /mnt/data
    
    # Mount the primary EFI partition
    sudo mount /dev/disk/by-partuuid/64446512-5ea8-475e-9bff-4bb490472289 /mnt/boot
    ```

### Step 2.6: Install NixOS

1.  **Generate initial hardware config (optional but recommended):**
    ```bash
    sudo nixos-generate-config --root /mnt
    # You can inspect /mnt/etc/nixos/hardware-configuration.nix and copy relevant parts
    # to your flake's host file later. For now, we can ignore it and rely on nixos-hardware.
    # It's good practice to remove the generated configuration.nix to avoid confusion.
    sudo rm /mnt/etc/nixos/configuration.nix
    ```

2.  **Clone your configuration repository:**
    ```bash
    sudo git clone https://github.com/your-username/your-repo.git /mnt/etc/nixos
    ```

3.  **Run the installation:**
    Change into your configuration directory and run `nixos-install`. Make sure to replace `<hostname>` with the correct host from your flake (e.g., `nixbeast`).
    ```bash
    # Change directory into your cloned repo
    cd /mnt/etc/nixos

    # Run the installer
    sudo nixos-install --root /mnt --flake .#<hostname>
    ```

4.  **Reboot:**
    After the installation completes, unmount and reboot.
    ```bash
    sudo umount -R /mnt
    sudo reboot
    ```

---

## 3. Post-Installation Management

Once the system is running, all changes should be made through this Git repository.

1.  Make changes to your configuration files.
2.  Commit and push the changes to Git.
3.  On the target machine, pull the changes and run `sudo nixos-rebuild switch`.

You can also use the `devShell` from this flake, which provides a convenient `rebuild` alias:
```bash
nix develop
rebuild <hostname> switch
```