# /home/robert/nixos/modules/installer.nix
#
# This module configures a bootable NixOS ISO installer.
{ pkgs, ... }:

{
  imports = [
    # This is the base configuration for a minimal NixOS installation ISO.
    <nixpkgs/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix>
  ];

  # Set a name for the generated ISO file.
  isoImage.isoName = "nixos-custom-installer.iso";

  # CRITICAL: Enable flakes for the live environment. This allows you to
  # run `nixos-install --flake ...` from the installer.
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # Since your systems are ZFS-based, include ZFS support in the installer.
  boot.supportedFilesystems = [ "zfs" ];

  # Add essential packages to the live environment for installation.
  environment.systemPackages = with pkgs; [
    git      # To clone your configuration repository
    neovim   # Your preferred editor
    gparted  # For disk partitioning
    zfs      # ZFS user-space tools for pool creation/management
  ];
}