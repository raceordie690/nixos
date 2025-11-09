{ config, pkgs, unstablePkgs, lib, ... }:

{
  imports = [
    ../rocm-overlay.nix
  ];
  # 1. Disable Graphical Interface
  # This is a headless server, so we don't need a display server or login manager.
  services.xserver.enable = false;
  services.displayManager.sddm.enable = false;
  services.desktopManager.plasma6.enable = false; # Assuming you might have this in common.nix
  services.greetd.enable = false; # Or any other greeter

  # 2. Enable AMD ROCm for GPU Compute
  # This enables the drivers and toolchain for running compute workloads on AMD GPUs.
  drivers.rocm.enable = true;

  services.ollama = {
    enable = true;
    # Use the ollama package from unstable for the latest features and fixes.
    package = unstablePkgs.ollama;
    acceleration = "rocm";
  };

  # Add environment variable to the ollama systemd service to support newer
  # AMD GPUs (like gfx1201/RDNA4) that are not yet officially supported.
  systemd.services.ollama.serviceConfig = {
    Environment = lib.mkMerge [
      "HSA_OVERRIDE_GFX_VERSION=11.0.0"
    ];
  };

  # 3. Add users to the 'render' and 'video' groups to allow access to the GPU.
  # This is necessary for non-root users to run ROCm applications.
  users.extraGroups.render.members = [ "robert" ];
  users.extraGroups.video.members = [ "robert" ];
}
