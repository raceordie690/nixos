{
  description = "My NixOS configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixos-hardware.url = "github:NixOS/nixos-hardware";
  };

  outputs = { self, nixpkgs, nixpkgs-unstable, nixos-hardware, ... }:
  let
    # Define package sets for each system architecture.
    # This makes it easy to reference stable and unstable packages.
    pkgsFor = system: import nixpkgs {
      inherit system;
      config.allowUnfree = true;
    };
    unstablePkgsFor = system: import nixpkgs-unstable {
      inherit system;
      config.allowUnfree = true;
    };

    mkHost = { hostname, system ? "x86_64-linux", modules ? [ ] }:
      nixpkgs.lib.nixosSystem {
        inherit system;
        pkgs = pkgsFor system;
        specialArgs = { inherit hostname; unstablePkgs = unstablePkgsFor system; };
        modules = modules;
      };
  in {
    nixosConfigurations = {
      nixboss = mkHost {
        hostname = "nixboss";
        modules = [
          # Hardware (generic AMD + specific IGPU module you used)
          nixos-hardware.nixosModules.common-cpu-amd
          nixos-hardware.nixosModules.common-cpu-amd-pstate
          nixos-hardware.nixosModules.common-gpu-amd
          "${nixos-hardware}/common/cpu/amd/raphael/igpu.nix"
          ./modules/amdgpu.nix

          # Shared config and roles
          ./modules/common.nix
          ./modules/zfs-common.nix
          #./modules/roles/desktop-x11-qtile.nix
          # Switch to Wayland Qtile role
          ./modules/roles/desktop-wayland.nix  

          # Host-specific config
          ./hosts/nixboss/hardware-configuration.nix
          ./hosts/nixboss/configuration.nix
        ];
      };

      # Add future machines like:
      # atlas = mkHost {
      #   hostname = "atlas";
      #   modules = [
      #     nixos-hardware.nixosModules.common-cpu-amd
      #     nixos-hardware.nixosModules.common-cpu-amd-pstate
      #     nixos-hardware.nixosModules.common-gpu-amd
      #
      #     ./modules/common.nix
      #     ./modules/zfs-common.nix
      #     ./modules/roles/desktop-x11-qtile.nix
      #
      #     ./hosts/atlas/hardware-configuration.nix
      #     ./hosts/atlas/configuration.nix
      #   ];
      # };
    };
  };
}