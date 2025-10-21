{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.drivers.amdgpu;
in
{
  options.drivers.amdgpu = {
    enable = lib.mkEnableOption "Enable comprehensive AMD GPU driver configuration";
  };

  config = lib.mkIf cfg.enable {
    # This ensures the amdgpu kernel module is loaded early in the boot process,
    # which is crucial for features like Plymouth boot screens and stable display output.
    boot.initrd.kernelModules = [ "amdgpu" ];
    # Blacklist the older 'radeon' driver to prevent conflicts with 'amdgpu'.
    boot.blacklistedKernelModules = [ "radeon" ];

    # Core graphics packages and 32-bit support for gaming (e.g., Steam via Proton).
    hardware.graphics = {
      enable = true;
      enable32Bit = true;
      # The mesa drivers are essential. vulkan-tools provides useful utilities
      # for verifying your Vulkan installation (e.g., `vulkaninfo`).
      extraPackages = with pkgs; [
        mesa
        vulkan-tools
        libva # Video Acceleration API
      ];
    };

    # Explicitly set the default Vulkan driver to RADV (the default open-source driver).
    environment.variables = {
      # Forcing RADV. To use AMDVLK, you would change this to:
      # "/run/opengl-driver-amdvlk/share/vulkan/icd.d/amd_icd64.json"
      VK_ICD_FILENAMES = "/run/opengl-driver/share/vulkan/icd.d/amd_icd64.json";
    };

    # Enable the alternative AMDVLK Vulkan driver, available on all AMD GPU hosts.
    hardware.amdgpu.amdvlk.enable = true;

    # These settings are for an X11 session. They won't have an effect
    # with your current Wayland setup but are good to have for a complete module
    # in case you switch to an X11 session later.
    services.xserver = lib.mkIf config.services.xserver.enable {
      enableTearFree = true;
    };

    environment.systemPackages = with pkgs; [ clinfo ];

    # The following are commented out but can be useful:
    # `lact` is a useful GUI tool for controlling and monitoring your AMD GPU.
    # environment.systemPackages = [ pkgs.lact ];
    # services.lactd.enable = true;
  };
}