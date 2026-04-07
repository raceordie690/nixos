{
  description = "My NixOS configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixos-hardware.url = "github:NixOS/nixos-hardware";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, nixpkgs-unstable, nixos-hardware, home-manager, ... }:
    let
      # Simple overlay to pull specific packages from unstable
      unstable-overlay = final: prev: {
        unstablePkgs = import nixpkgs-unstable {
          system = prev.stdenv.hostPlatform.system;
          config.allowUnfree = true;
        };
        # Ensure ROCm is always fresh from unstable
        rocmPackages = final.unstablePkgs.rocmPackages;
      };

      # Hardware-specific firmware overlay
      firmware-overlay = final: prev: {
        linux-firmware = prev.linux-firmware.overrideAttrs (old: {
          preInstall = (old.preInstall or "") + ''
             cp ${final.fetchurl {
               url = "https://git.kernel.org/pub/scm/linux/kernel/git/firmware/linux-firmware.git/plain/amdgpu/gc_11_5_1_mes_2.bin?id=c092c7487eb7c3d58697f490ff605bc38f4cc947";
               sha256 = "02isjq7ijbi15cgssakx1sp3pym587c365i2zi1pcyyq30n861wf";
               name = "gc_11_5_1_mes_2.bin";
             }} amdgpu/gc_11_5_1_mes_2.bin
          '';
        });
      };

      # Standard host builder helper
      mkHost = { hostname, system ? "x86_64-linux", modules ? [ ], extraOverlays ? [ ], withHomeManager ? false }:
        nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = {
            inherit hostname nixpkgs;
            unstablePkgs = import nixpkgs-unstable { inherit system; config.allowUnfree = true; };
          };
          modules = [
            {
              nixpkgs.overlays = [ unstable-overlay ] ++ extraOverlays;
              nixpkgs.config.allowUnfree = true;
            }
          ] ++ modules ++ (if withHomeManager then [
            home-manager.nixosModules.home-manager
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.backupFileExtension = "backup_hm";
              home-manager.users.robert = import ./home.nix;
            }
          ] else []);
        };

      # Helper for installer ISOs
      mkInstallerHost = { hostname, system ? "x86_64-linux", modules ? [ ] }:
        nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = { inherit hostname nixpkgs; };
          modules = modules;
        };

    in {
      nixosConfigurations = {
        nixboss = mkHost {
          hostname = "nixboss";
          withHomeManager = false;
          modules = [
            nixos-hardware.nixosModules.common-cpu-amd
            nixos-hardware.nixosModules.common-cpu-amd-pstate
            nixos-hardware.nixosModules.common-gpu-amd
            "${nixos-hardware}/common/cpu/amd/raphael/igpu.nix"
            ./modules/amdgpu.nix
            ./modules/common.nix
            ./modules/zfs-common.nix
            ./modules/roles/desktop-wayland.nix
            ./hosts/nixboss/hardware-configuration.nix
            ./hosts/nixboss/configuration.nix
          ];
        };

        nixbeast = mkHost {
          hostname = "nixbeast";
          withHomeManager = false;
          extraOverlays = [ firmware-overlay ];
          modules = [
            nixos-hardware.nixosModules.common-cpu-amd
            nixos-hardware.nixosModules.common-cpu-amd-pstate
            nixos-hardware.nixosModules.common-gpu-amd
            ./modules/amdgpu.nix
            ./modules/common.nix
            ./modules/zfs-common.nix
            ./modules/roles/desktop-wayland.nix
            ./hosts/nixbeast/hardware-configuration.nix
            ./hosts/nixbeast/configuration.nix
          ];
        };

        nixserve = mkHost {
          hostname = "nixserve";
          modules = [
            nixos-hardware.nixosModules.common-cpu-amd
            nixos-hardware.nixosModules.common-cpu-amd-pstate
            ./modules/common.nix
            ./modules/zfs-common.nix
            ./modules/roles/headless-rocm.nix
            ./modules/roles/rstudio-server.nix # Add the new RStudio system service
            ./hosts/nixserve/hardware-configuration.nix
            ./hosts/nixserve/configuration.nix
          ];
        };

        installer = mkInstallerHost {
          hostname = "installer";
          modules = [ ./modules/installer.nix ];
        };
      };

      devShells.x86_64-linux.default =
        let
          pkgs = nixpkgs.legacyPackages.x86_64-linux;
        in
        pkgs.mkShell {
          name = "nixos-config-shell";
          nativeBuildInputs = [ pkgs.nixos-rebuild ];
          shellHook = ''
            echo "Welcome to the NixOS configuration shell."
            rebuild() {
              nixos-rebuild "$2" --flake ".#$1" --use-remote-sudo
            }
          '';
        };
    };
}
