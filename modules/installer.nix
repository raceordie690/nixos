# This module configures a bootable ISO image for installation.
# It uses the nixpkgs input passed via specialArgs in flake.nix to remain pure.
{ config, pkgs, lib, nixpkgs, ... }:

{
  imports = [
    # Use the explicit path from the nixpkgs flake input instead of an impure lookup.
    "${nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix"
  ];

  # Enable flakes and nix-command in the installer environment.
  nix.extraOptions = ''
    experimental-features = nix-command flakes
  '';

  # Enable ZFS tools in the installer.
  boot.supportedFilesystems = [ "zfs" ];
  networking.hostId = "00000000"; # Required for ZFS on boot.

  # Add useful tools to the installer environment.
  environment.systemPackages = with pkgs; [ git vim zfs ];
}