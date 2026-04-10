# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).
{ config, lib, pkgs, unstablePkgs, ... }:

{


  imports = [
    # common.nix and headless-rocm.nix are already included via flake.nix
    (../../modules/amdgpu.nix)
    ../../modules/roles/windows-vm.nix
  ];

  # Optimizations for Zen 2 (Threadripper 3000) and AI/LLM usage
  boot.kernelParams = [
    "iommu=pt"
    "transparent_hugepage=always"
    "ttm.pages_limit=33554432"
    "amd_pstate=passive"
  ];

  # ============================================================================
  # Network Bridge for VM (br0 bridges the LAN interface to the VM)
  # ============================================================================
  # Disable NetworkManager - it conflicts with manual bridge configuration
  networking.networkmanager.enable = lib.mkForce false;
  
  # Use systemd-networkd to manage the bridge
  networking.useNetworkd = true;
  
  # Configure the bridge and physical interface
  networking.bridges.br0.interfaces = [ "enp69s0" ];
  networking.interfaces.br0.useDHCP = true;
  networking.interfaces.enp69s0.useDHCP = false;
  
  # Enable systemd-networkd service
  systemd.network.enable = true;

  # Enable the base AMD GPU drivers (from amdgpu.nix).
  drivers.amdgpu.enable = true;

  nix = {
    settings = {
      max-jobs = "auto";
      cores = 0;
      system-features = [ "gccarch-znver2" "benchmark" "big-parallel" "kvm" "nixos-test" ];
    };

    gc = {
      automatic = true;
      dates = [ "weekly" ];
    };
  };

  # Enable Docker daemon
  virtualisation.docker.enable = true;

  # Ensure the 'docker' group exists (usually created automatically by the module,
  # but this is explicit and works even if you don't rely on the module)
  users.groups.docker = { };

  # Your user must be in the 'docker' group
  users.users.robert = {
    extraGroups = [ "docker" ];
  };

  users.users.craig = {
    isNormalUser = true;
    home = "/home/craig";
    createHome = true;
    shell = pkgs.bash;
    extraGroups = [ "docker" ];
  };
  
  # Use a specific kernel version for this host.
  # Use the latest kernel from unstable for maximum hardware support.
  # Choose which ZFS you want (stable or bleeding-edge)
  #boot.zfs.package = pkgs.zfsUnstable;   # or: pkgs.zfsUnstable

  # Use the standard LTS kernel supported by ZFS in NixOS 25.11.
  boot.kernelPackages = pkgs.linuxPackages_6_12;
   # Use the systemd-boot EFI boot loader.
  boot.loader = {
    systemd-boot.enable = true;
    efi.canTouchEfiVariables = true;
    # This script runs during `nixos-rebuild switch` to back up the primary EFI partition.
    #systemd-boot.extraInstallCommands = ''
    #  set -euxo pipefail
    #  export PATH=${pkgs.coreutils}/bin:${pkgs.util-linux}/bin:${pkgs.rsync}/bin:$PATH

      # Define backup EFI partition
#      BACKUP_EFI_PART="/dev/disk/by-partuuid/dafe0025-dfd4-460c-a041-6ba57fd0858b"

      # Mount secondary EFI partition
#      mkdir -p /mnt/efibackup
#      mount "$BACKUP_EFI_PART" /mnt/efibackup

      # Mirror contents from primary EFI partition (/boot/efi) to the backup
#      rsync -a --delete /efi/ /mnt/efibackup/

#      umount /mnt/efibackup
#    '';
  };

  # List packages installed in system profile.
  # You can use https://search.nixos.org/ to find more packages (and options).
  # GPU-related tools are now managed by the amdgpu.nix module.
  environment.systemPackages = with pkgs;
    [
      lm_sensors # For monitoring CPU temperatures
      htop
    ]; # Add other nixserve-specific packages here

  # Merge udev rules from multiple modules.
  # The rules from headless-rocm.nix are included here, along with a new one
  # to enable Wake-on-LAN for ethernet devices.
  services.udev.extraRules = lib.mkMerge [
    (lib.mkBefore ''ACTION=="add", SUBSYSTEM=="net", ATTR{type}=="1", RUN+="${pkgs.ethtool}/bin/ethtool -s %k wol g"'')
  ];

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
