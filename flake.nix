{
  description = "My NixOS configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixos-hardware.url = "github:NixOS/nixos-hardware";
    home-manager.url = "github:nix-community/home-manager";
    sops-nix.url = "github:Mic92/sops-nix";
    # Point home-manager to nixpkgs-unstable. This is crucial to ensure that
    # the pkgs used by home-manager are consistent with the pkgs used by the hosts.
    home-manager.inputs.nixpkgs.follows = "nixpkgs-unstable";
  };

  outputs = { self, nixpkgs, nixpkgs-unstable, nixos-hardware, home-manager, sops-nix, ... }:
    let
      # Define package sets for each system architecture.
      # This makes it easy to reference stable and unstable packages.
      pkgsFor = system: import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };
      unstablePkgsFor = system:
        let
          # This overlay ensures that rocmPackages are sourced from nixpkgs-unstable.
          # This is the correct place to define overlays, not in a module.
          rocmOverlay = final: prev: {
            rocmPackages = (import nixpkgs-unstable { inherit system; }).rocmPackages;
          };
        in import nixpkgs-unstable {
          inherit system;
          config.allowUnfree = true;
          overlays = [ rocmOverlay ];
        };

      # Helper function to build a NixOS host configuration.
      # It now accepts an optional 'pkgs' argument to allow overriding the
      # default (stable) nixpkgs set for a specific host.
      mkHost = { hostname, system ? "x86_64-linux", pkgs ? pkgsFor system, modules ? [ ] }:
        nixpkgs.lib.nixosSystem {
          inherit system;
          inherit pkgs; # Use the provided or default 'pkgs'.
          specialArgs = { inherit hostname; unstablePkgs = unstablePkgsFor system; };
          modules = modules;
        };
    in {
      nixosConfigurations = {
        nixboss = mkHost {
          hostname = "nixboss";
          # Override the default 'pkgs' to use the unstable channel.
          # This is necessary for the latest ROCm/HIP support, as this host's
          # configuration enables the rocm.nix module.
          pkgs = unstablePkgsFor "x86_64-linux";
          modules = [
            # Hardware (generic AMD + specific IGPU module you used)
            nixos-hardware.nixosModules.common-cpu-amd
            nixos-hardware.nixosModules.common-cpu-amd-pstate
            nixos-hardware.nixosModules.common-gpu-amd
            "${nixos-hardware}/common/cpu/amd/raphael/igpu.nix"
            ./modules/amdgpu.nix

            # Shared config and roles
            sops-nix.nixosModules.sops
            ./modules/common.nix
            ./modules/zfs-common.nix
            #./modules/roles/desktop-x11-qtile.nix
            # Switch to Wayland Qtile role
            ./modules/roles/desktop-wayland.nix
            ./modules/sddm-theme.nix  

            # Host-specific config
            ./hosts/nixboss/hardware-configuration.nix
            ./hosts/nixboss/configuration.nix
          ];
        };

        nixbeast = mkHost {
          hostname = "nixbeast";
          # Override the default 'pkgs' to use the unstable channel.
          # This is necessary for the latest ROCm/HIP support.
          pkgs = unstablePkgsFor "x86_64-linux";
          modules = [
            # Hardware
            nixos-hardware.nixosModules.common-cpu-amd
            nixos-hardware.nixosModules.common-cpu-amd-pstate
            nixos-hardware.nixosModules.common-gpu-amd
            ./modules/amdgpu.nix

            # Shared config and roles
            sops-nix.nixosModules.sops
            ./modules/common.nix
            ./modules/zfs-common.nix
            ./modules/roles/desktop-wayland.nix
            ./modules/sddm-theme.nix  

            # Host-specific config
            ./hosts/nixbeast/hardware-configuration.nix
            ./hosts/nixbeast/configuration.nix
          ];
        };

        nixserve = mkHost {
          hostname = "nixserve";
          # Override the default 'pkgs' to use the unstable channel.
          # This is necessary for the latest ROCm/HIP support.
          pkgs = unstablePkgsFor "x86_64-linux";
          modules = [
            # Hardware (assuming AMD CPU)
            nixos-hardware.nixosModules.common-cpu-amd
            nixos-hardware.nixosModules.common-cpu-amd-pstate

            # Shared config and roles
            sops-nix.nixosModules.sops
            ./modules/common.nix
            ./modules/zfs-common.nix # Assuming the server also uses ZFS
            ./modules/roles/headless-rocm.nix

            # Host-specific config
            ./hosts/nixserve/hardware-configuration.nix
            ./hosts/nixserve/configuration.nix
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
