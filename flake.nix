{
  description = "My NixOS configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";  # Always latest stable
    #nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";  # Always latest stable
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixos-hardware.url = "github:NixOS/nixos-hardware";
    home-manager.url = "github:nix-community/home-manager";    
    # Point home-manager to the same nixpkgs as the system for consistency.
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, nixpkgs-unstable, nixos-hardware, home-manager, ... }:
    let
      # Define package sets for each system architecture.
      # This overlay adds packages from nixpkgs-unstable into the stable package set.
      # It's a clean way to mix stable and unstable.
      unstable-overlay = final: prev:
        let
          # Import unstable pkgs once to avoid duplication and for clarity.
          unstablePkgs = import nixpkgs-unstable {
            system = prev.system;
            config.allowUnfree = true;
          };
        in {
          # Overlay rocmPackages from unstable.
          rocmPackages = unstablePkgs.rocmPackages;
        };

      # Helper function to build a NixOS host configuration.
      # All hosts will now use the stable 'nixpkgs' by default, with the
      # 'unstable-overlay' applied to provide access to unstable packages.
      mkHost = { hostname, system ? "x86_64-linux", modules ? [ ] }:
        let
          # Import unstable pkgs once to pass to modules via specialArgs.
          unstablePkgs = import nixpkgs-unstable { inherit system; config.allowUnfree = true; };
          # Create the final pkgs set with the stable+unstable overlay.
          pkgs = import nixpkgs { inherit system; config.allowUnfree = true; overlays = [ unstable-overlay ]; };
        in
        nixpkgs.lib.nixosSystem {
          inherit system;
          inherit pkgs; # Use the provided or default 'pkgs'.
          specialArgs = {
            inherit hostname;
            # Pass the nixpkgs flake input to modules.
            inherit nixpkgs;
            # Pass the unstable package set to modules that need it.
            inherit unstablePkgs;
          };
          modules = modules;
        };

      # A simplified helper for the installer ISO.
      # This version does NOT apply the unstable-overlay, which prevents a
      # mismatch between the unstable ZFS package and the stable kernel
      # used by the installer base image.
      mkInstallerHost = { hostname, system ? "x86_64-linux", modules ? [ ] }:
        nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = {
            inherit hostname;
            # Pass the nixpkgs flake input to modules.
            inherit nixpkgs;
          };
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
            ./modules/sddm-theme.nix  

            # Host-specific config
            ./hosts/nixboss/hardware-configuration.nix
            ./hosts/nixboss/configuration.nix
          ];
        };

        nixbeast = mkHost {
          hostname = "nixbeast";
          modules = [
            # Hardware
            nixos-hardware.nixosModules.common-cpu-amd
            nixos-hardware.nixosModules.common-cpu-amd-pstate
            nixos-hardware.nixosModules.common-gpu-amd
            ./modules/amdgpu.nix

            # Shared config and roles            
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
          modules = [
            # Hardware (assuming AMD CPU)
            nixos-hardware.nixosModules.common-cpu-amd
            nixos-hardware.nixosModules.common-cpu-amd-pstate

            # Shared config and roles            
            ./modules/common.nix
            ./modules/zfs-common.nix # Assuming the server also uses ZFS
            ./modules/roles/headless-rocm.nix

            # Host-specific config
            ./hosts/nixserve/hardware-configuration.nix
            ./hosts/nixserve/configuration.nix
          ];
        };

      # A special configuration to build a bootable ISO installer.
      installer = mkInstallerHost {
        hostname = "installer"; # A dummy hostname for the build.
        modules = [
          # This module contains all the ISO-specific settings.
          ./modules/installer.nix
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

      # Add a devShell for convenience
      devShells.x86_64-linux.default =
        let
          pkgs = nixpkgs.legacyPackages.x86_64-linux;
        in
        pkgs.mkShell {
          name = "nixos-config-shell";
          nativeBuildInputs = [ pkgs.nixos-rebuild ];
          shellHook = ''
            echo "Welcome to the NixOS configuration shell."
            echo
            echo "Available hosts: nixboss, nixbeast, nixserve"
            echo
            echo "Use 'rebuild <hostname> <action>' to manage your systems."
            echo "Example: rebuild nixboss switch"
            
            rebuild() {
              nixos-rebuild "$2" --flake ".#$1" --use-remote-sudo
            }
          '';
        };
    };
}
