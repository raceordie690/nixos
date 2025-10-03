{ config, pkgs, ... }:
{

  nix.settings = {
    max-jobs = "auto";
    cores = 16;
  }
  # Enable the comprehensive AMD GPU configuration from our new module.
  drivers.amdgpu.enable = true;

  networking.hostName = "nixboss";
  networking.hostId = "e7a6ede7";

  boot.kernelPackages = pkgs.linuxPackages_6_12;

  boot.loader = {
    systemd-boot.enable = true;
    efi.canTouchEfiVariables = true;
  };

 

  # Power key behavior
  services.logind.extraConfig = ''
    HandlePowerKey = "sleep";
  '';

  # This option defines the first version of NixOS you have installed on this particular machine,
  # and is used to maintain compatibility with application data (e.g. databases) created on older NixOS versions.
  #
  # Most users should NEVER change this value after the initial install, for any reason,
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
  system.stateVersion = "23.11";
}