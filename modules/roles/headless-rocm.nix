{ config, pkgs, unstablePkgs, lib, ... }:
{
  # 1. Disable Graphical Interface
  # This is a headless server, so we don't need a display server or login manager.
  services.xserver.enable = false;
  services.displayManager.sddm.enable = false;
  services.desktopManager.plasma6.enable = false;
  services.greetd.enable = false;

  # 2. Enable AMD ROCm for GPU Compute
  # Use the standard NixOS hardware configuration for AMD GPUs
  hardware.opengl = {
    enable = true;
    driSupport = true;
    extraPackages = with pkgs; [
      rocmPackages.clr.icd
      rocmPackages.rocm-runtime
    ];
  };

  # Enable ROCm support
  systemd.tmpfiles.rules = [
    "L+    /opt/rocm/hip   -    -    -     -    ${pkgs.rocmPackages.clr}"
  ];

  services.ollama = {
    enable = true;
    package = unstablePkgs.ollama-rocm;
    acceleration = "rocm";
  };

  # 3. Add users to the 'render' and 'video' groups to allow access to the GPU.
  users.users.robert.extraGroups = [ "render" "video" ];

  # Ensure proper permissions for ROCm devices
  services.udev.extraRules = ''
    KERNEL=="kfd", GROUP="render", MODE="0664"
    KERNEL=="renderD*", GROUP="render", MODE="0664"
  '';
}
