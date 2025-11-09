{ config, pkgs, ... }:

{
  # 1. Disable Graphical Interface
  # This is a headless server, so we don't need a display server or login manager.
  services.xserver.enable = false;
  services.displayManager.sddm.enable = false;
  services.desktopManager.plasma6.enable = false; # Assuming you might have this in common.nix
  services.greetd.enable = false; # Or any other greeter

  # 2. Enable AMD ROCm for GPU Compute
  # This enables the drivers and toolchain for running compute workloads on AMD GPUs.
  drivers.rocm.enable = true;

  # Ensure OpenGL is available for parts of the stack that might need it.
  hardware.graphics.enable = true;

  # 3. Add users to the 'render' and 'video' groups to allow access to the GPU.
  # This is necessary for non-root users to run ROCm applications.
  users.extraGroups.render.members = [ "robert" ];
  users.extraGroups.video.members = [ "robert" ];
}
