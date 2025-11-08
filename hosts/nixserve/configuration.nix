# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).
{ config, lib, pkgs, ... }:

{
  imports = [
    ../../modules/amdgpu.nix
    ../../modules/rocm.nix
  ];

  # optimizations for AI Max+ 395 LLM usage
  boot.kernelParams = [
    "amd_iommu=off"
    "amdgpu.gttsize=131072"
    "transparent_hugepage=always"
    "ttm.pages_limit=33554432"
  ];

  # Enable the base AMD GPU drivers (from amdgpu.nix).
  drivers.amdgpu.enable = true;
  # Enable the ROCm compute stack specifically for this host (from rocm.nix).
  drivers.rocm.enable = true;

  nix.settings = {
    max-jobs = "auto";
    cores = 48;
  };
  # Use a specific kernel version for this host.
  # The unstable kernel is aliased to `pkgs.linuxPackages_latest`
  boot.kernelPackages = pkgs.linuxPackages_6_12;

   # Use the systemd-boot EFI boot loader.
  boot.loader = {
    systemd-boot.enable = true;
    efi.canTouchEfiVariables = true;
    # This script runs during `nixos-rebuild switch` to back up the primary EFI partition.
    systemd-boot.extraInstallCommands = ''
      set -euxo pipefail
      export PATH=${pkgs.coreutils}/bin:${pkgs.util-linux}/bin:${pkgs.rsync}/bin:$PATH

      # Define backup EFI partition
      BACKUP_EFI_PART="/dev/disk/by-partuuid/dafe0025-dfd4-460c-a041-6ba57fd0858b"

      # Mount secondary EFI partition
      mkdir -p /mnt/efibackup
      mount "$BACKUP_EFI_PART" /mnt/efibackup

      # Mirror contents from primary EFI partition (/boot/efi) to the backup
      rsync -a --delete /efi/ /mnt/efibackup/

      umount /mnt/efibackup
    '';
  };

  # List packages installed in system profile.
  # You can use https://search.nixos.org/ to find more packages (and options).
  # GPU-related tools are now managed by the amdgpu.nix module.
  environment.systemPackages = with pkgs; [
    ollama # A popular tool for running LLMs locally
    lm_sensors # For monitoring CPU temperatures
  ]; # Add other nixserve-specific packages here

  # This option defines the first version of NixOS you have installed on this particular machine,
  # and is used to maintain compatibility with application data (e.g. databases) created on older NixOS versions.
  #
  # Most users should NEVER change this valueafter the initial install, for any reason,
  # even if you've upgraded your system to a new NixOS release.
  #
  # This value does NOT affect the Nixpkgs version your packages and OS are pulled from,
  # so changing it will NOT upgrade your system - see https://nixos.org/manual/nixos/stable/#sec-upgrading for how
  # to actually do that.
  #
  # This value being lower than the current NixOS release does NOT mean your system is
  # out of date, out of support, or vulnerable.
  #
  # Do NOT change this value unless you have manually inspected all the changes it would make to your configuration,
  # and migrated your data accordingly.
  #
  # For more information, see `man configuration.nix` or https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion .
  system.stateVersion = "25.11"; # Did you read the comment?
}
