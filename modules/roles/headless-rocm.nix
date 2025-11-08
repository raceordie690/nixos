{ config, pkgs, ... }:

{
  # 1. Disable Graphical Interface
  # This is a headless server, so we don't need a display server or login manager.
  services.xserver.enable = false;
  services.display-manager.sddm.enable = false;
  services.desktopManager.plasma6.enable = false; # Assuming you might have this in common.nix
  services.greetd.enable = false; # Or any other greeter

  # 2. Enable AMD ROCm for GPU Compute
  # This enables the drivers and toolchain for running compute workloads on AMD GPUs.
  hardware.rocm.enable = true;

  # Ensure OpenGL is available for parts of the stack that might need it.
  hardware.opengl.enable = true;
  hardware.opengl.driSupport = true;

  # Enable Vulkan support for AMD GPUs. This will use the RADV driver by default.
  hardware.vulkan.enable = true;

  # 3. Add users to the 'render' and 'video' groups to allow access to the GPU.
  # This is necessary for non-root users to run ROCm applications.
  users.extraGroups.render.members = [ "robert" ];
  users.extraGroups.video.members = [ "robert" ];

  # 4. Install useful GPU monitoring tools
  environment.systemPackages = with pkgs; [
    rocm-smi # AMD's equivalent of nvidia-smi
    vulkan-tools # Provides `vulkaninfo` for verification
  ];
}
