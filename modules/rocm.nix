{
  config,
  lib,
  pkgs,
  ...
}:
  let
    cfg = config.drivers.rocm;
  in
  {
    options.drivers.rocm = {
      enable = lib.mkEnableOption "Enable ROCm support for compute/AI workloads";
    };

    config = lib.mkIf cfg.enable {
      # This ensures the amdgpu kernel module is loaded early.
      boot.initrd.kernelModules = [ "amdgpu" ];

      # Enable OpenGL and Vulkan support, adding ROCm's ICD for Vulkan compute.
      hardware.graphics = {
        enable = true;
        extraPackages = with pkgs; [
          rocmPackages.clr.icd
        ];
      };

      # Create a symlink for applications that expect HIP to be at /opt/rocm/hip
      systemd.tmpfiles.rules = [
        "L+    /opt/rocm/hip   -    -    -     -    ${pkgs.rocmPackages.hipcc}"
      ];

      # Ensure correct permissions for GPU devices.
      services.udev.extraRules = ''
        KERNEL=="kfd", GROUP="render", MODE="0664"
        KERNEL=="renderD*", GROUP="render", MODE="0664"
      '';

      # Add ROCm-specific tools to the system path.
      environment.systemPackages = with pkgs; [
        rocmPackages.rocminfo
        rocmPackages.rocm-smi
      ];
    };
  }
