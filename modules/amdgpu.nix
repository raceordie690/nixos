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
  options.drivers.amdgpu.enable = lib.mkEnableOption "Enable comprehensive AMD GPU driver configuration";

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
      ];
    };

    # Explicitly set the default Vulkan driver to RADV (the default open-source driver).
    # This is useful if you also enable AMDVLK and want to control which driver is used.
    environment.variables = {
      # Forcing RADV. To use AMDVLK, you would change this to:
      # "/run/opengl-driver-amdvlk/share/vulkan/icd.d/amd_icd64.json"
      VK_ICD_FILENAMES = "/run/opengl-driver/share/vulkan/icd.d/amd_icd64.json";
    };

    # NixOS options for AMD GPU features.
    hardware.amdgpu = {
      # Enable ROCm OpenCL support. This is a high-level option that correctly
      # configures the necessary packages.
      opencl.enable = true;

      # Optionally enable the alternative AMDVLK Vulkan driver.
      # RADV is generally recommended for gaming, but AMDVLK can be better for
      # some professional applications.
      amdvlk.enable = true;
    };

    # These settings are for an X11 session. They won't have an effect
    # with your current Wayland setup but are good to have for a complete module
    # in case you switch to an X11 session later.
    services.xserver = {
      videoDrivers = [ "amdgpu" ];
      # TearFree is an X11-specific option to reduce screen tearing.
      # It's not needed on Wayland, as Wayland handles this by design.
      enableTearFree = true;
    };

    # Create a linked path /opt/rocm for ROCm libraries. Some applications
    # may have this path hardcoded.
    systemd.tmpfiles.rules =
      let
        rocmEnv = pkgs.symlinkJoin {
          name = "opt-rocm";
          paths = with pkgs.rocmPackages; [ rocblas hipblas clr ];
        };
      in
      [ "L+    /opt/rocm   -    -    -     -    ${rocmEnv}" ];

    # Add the ROCm System Management Interface tool to your system.
    # You can run `rocm-smi` to monitor GPU status.
    environment.systemPackages = with pkgs; [ rocmPackages.rocm-smi ];

    # The following are commented out but can be useful:

    # `lact` is a useful GUI tool for controlling and monitoring your AMD GPU.
    # environment.systemPackages = [ pkgs.lact ];
    # services.lactd.enable = true;
  };
}