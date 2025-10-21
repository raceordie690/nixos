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

    # Add ROCm-specific tools to the system path.
    environment.systemPackages = with pkgs; [
      rocmPackages.rocminfo
      rocmPackages.rocm-smi
    ];
  };
}
