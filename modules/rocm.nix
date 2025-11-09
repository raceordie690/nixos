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
      # This high-level option correctly configures the necessary packages and kernel modules
      # for ROCm OpenCL support.
      hardware.amdgpu.opencl.enable = true;

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
