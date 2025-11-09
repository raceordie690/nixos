{ pkgs, unstablePkgs, ... }:

{
  # Use an overlay to get the latest ROCm packages from nixpkgs-unstable.
  # This is crucial for supporting brand-new GPUs and is shared by any host needing ROCm.
  nixpkgs.overlays = [
    (final: prev: { rocmPackages = unstablePkgs.rocmPackages; })
  ];
}