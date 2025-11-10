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
      # Use the standard hardware.opengl instead of hardware.amdgpu.hip
      hardware.opengl = {
        enable = true;
        extraPackages = with pkgs; [
          rocmPackages.clr.icd
          rocmPackages.rocm-runtime
        ];
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
        [
          "L+    /opt/rocm   -    -    -     -    ${rocmEnv}"
          "L+    /opt/rocm/hip   -    -    -     -    ${pkgs.rocmPackages.clr}"
        ];

      services.udev.extraRules = ''
        KERNEL=="kfd", GROUP="render", MODE="0664"
        KERNEL=="renderD*", GROUP="render", MODE="0664"
      '';

      # Add ROCm-specific tools to the system path from the unstable channel.
      environment.systemPackages = with pkgs; [
        rocmPackages.rocminfo
        rocmPackages.rocm-smi
        rocmPackages.amdsmi
        rocmPackages.rocm-core
      ];

      environment.variables = {
        # ENABLE High Performance Matrix Math for LLM performance
        ROCBLAS_USE_HIPBLASLT = 1;
      };
    };
  }
