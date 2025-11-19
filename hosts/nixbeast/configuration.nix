# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).
{ config, lib, pkgs, unstablePkgs, ... }:

{
  imports = [
    (../../modules/amdgpu.nix)
    ../../modules/rocm.nix
  ];

  # optimizations for AI Max+ 395 LLM usage
  boot.kernelParams = [
    "splash"
    "amd_iommu=off"
    "amdgpu.gttsize=131072"
    "ttm.pages_limit=33554432"
  ];

  # Enable the base AMD GPU drivers (from amdgpu.nix).
  drivers.amdgpu.enable = true;
  # Enable the ROCm compute stack specifically for this host (from rocm.nix).
  drivers.rocm.enable = true;

 
  nix.settings = {
    max-jobs = "auto";
    cores = 32;
  };
  # Use a specific kernel version for this host.
  # The unstable kernel is aliased to `pkgs.linuxPackages_latest`
  boot.kernelPackages = pkgs.linuxPackages_6_17;
   # Use the systemd-boot EFI boot loader.
  boot.loader = {
    systemd-boot.enable = true;
    efi.canTouchEfiVariables = true;
  };

  # List packages installed in system profile.
  # You can use https://search.nixos.org/ to find more packages (and options).
  # GPU-related tools are now managed by the amdgpu.nix module.
  environment.systemPackages = [ ]; # Add other nixbeast-specific packages here

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
  system.stateVersion = "25.05"; # Did you read the comment?
}
