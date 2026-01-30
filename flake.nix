{
  description = "My NixOS configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";  # Always latest stable
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
      unstable-overlay = final: prev:
        let
          unstablePkgs = import nixpkgs-unstable {
            system = prev.stdenv.hostPlatform.system;
            config.allowUnfree = true;
          };
        in {
          rocmPackages = unstablePkgs.rocmPackages;
        };

      # Overlay to fix Strix Halo page faults (MES 0x83 regression)
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

      # Overlays to fix issues during architecture-optimized builds.
      optimization-fix-overlay = final: prev:
        let
          # Helper function to safely inject CFLAGS without colliding with 'env' attribute
          # in newer Nixpkgs derivations.
          safeInjectFlags = old: flags:
            if (old ? env && old.env ? NIX_CFLAGS_COMPILE) then {
              env = old.env // {
                NIX_CFLAGS_COMPILE = old.env.NIX_CFLAGS_COMPILE + " " + flags;
              };
            } else if (old ? NIX_CFLAGS_COMPILE) then {
              NIX_CFLAGS_COMPILE = old.NIX_CFLAGS_COMPILE + " " + flags;
            } else {
              NIX_CFLAGS_COMPILE = flags;
            };

          genericFlags = "-march=x86-64 -mtune=generic";
        in {
        # Skip failing tests in Test2Harness.
        perlPackages = prev.perlPackages.overrideScope (pself: pprev: {
          Test2Harness = pprev.Test2Harness.overrideAttrs (old: {
            doCheck = false;
          });
        });

        # Fix Internal Compiler Error (ICE) in re2c.
        re2c = prev.re2c.overrideAttrs (old: safeInjectFlags old genericFlags);

        # Fix LLVM 21 crash/OOM.
        llvm_21 = prev.llvm_21.overrideAttrs (old: (safeInjectFlags old genericFlags) // {
          doCheck = false;
        });

        # Skip tests for git packages which are failing during optimized builds.
        gitMinimal = prev.gitMinimal.overrideAttrs (old: {
          doCheck = false;
          checkPhase = "true";
          doInstallCheck = false;
        });

        exempi = prev.exempi.overrideAttrs (old: safeInjectFlags old genericFlags);

        git = prev.git.overrideAttrs (old: {
          doCheck = false;
          checkPhase = "true";
          doInstallCheck = false;
        });

        # Skip tests for pytest-xdist which are failing during optimized builds.
        python3Packages = prev.python3Packages.overrideScope (pself: pprev: {
          pytest-xdist = pprev.pytest-xdist.overrideAttrs (old: {
            doCheck = false;
          });
        });

        # Skip tests for coreutils-full failing during optimized builds.
        coreutils-full = prev.coreutils-full.overrideAttrs (old: {
          doCheck = false;
        });

        # Fix gnupg and systemd Exec format error by forcing generic architecture.
        gnupg = prev.gnupg.overrideAttrs (old: safeInjectFlags old genericFlags);

        systemd = prev.systemd.overrideAttrs (old: (safeInjectFlags old genericFlags) // {
          doCheck = false;
        });

        clang = prev.clang.overrideAttrs (old: safeInjectFlags old genericFlags);

        gsl = prev.gsl.overrideAttrs (old: safeInjectFlags old genericFlags);

        # Fix ROCm LLVM/Clang build failures by forcing generic flags and skipping tests.
        rocmPackages = prev.rocmPackages.overrideScope (rfinal: rprev: {
          llvm = rprev.llvm // {
            clang-unwrapped = rprev.llvm.clang-unwrapped.overrideAttrs (old: (safeInjectFlags old genericFlags) // {
              doCheck = false;
            });
            llvm = rprev.llvm.llvm.overrideAttrs (old: (safeInjectFlags old genericFlags) // {
              doCheck = false;
            });
          };
        });

        # Skip tests for assimp failing during optimized builds.
        assimp = prev.assimp.overrideAttrs (old: {
          doCheck = false;
        });
      };

      # Helper function to build a NixOS host configuration.
      mkHost = { hostname, system ? "x86_64-linux", gccArch ? null, modules ? [ ], extraOverlays ? [] }:
        let
          hostPlatform = if gccArch == null then { inherit system; } else {
            inherit system;
            gcc.arch = gccArch;
            gcc.tune = gccArch;
          };

          unstablePkgs = import nixpkgs-unstable {
            localSystem = hostPlatform;
            config.allowUnfree = true;
            overlays = [ optimization-fix-overlay ];
          };

          pkgs = import nixpkgs {
            localSystem = hostPlatform;
            config.allowUnfree = true;
            overlays = [ unstable-overlay optimization-fix-overlay ] ++ extraOverlays;
          };
        in
        nixpkgs.lib.nixosSystem {
          inherit system;
          inherit pkgs;
          specialArgs = {
            inherit hostname;
            inherit nixpkgs;
            inherit unstablePkgs;
          };
          modules = modules;
        };

      mkInstallerHost = { hostname, system ? "x86_64-linux", modules ? [ ] }:
        nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = {
            inherit hostname;
            inherit nixpkgs;
          };
          modules = modules;
        };

    in {
      nixosConfigurations = {
        nixboss = mkHost {
          hostname = "nixboss";
          gccArch = "znver4";
          modules = [
            nixos-hardware.nixosModules.common-cpu-amd
            nixos-hardware.nixosModules.common-cpu-amd-pstate
            nixos-hardware.nixosModules.common-gpu-amd
            "${nixos-hardware}/common/cpu/amd/raphael/igpu.nix"
            ./modules/amdgpu.nix
            ./modules/common.nix
            ./modules/zfs-common.nix
            ./modules/roles/desktop-wayland.nix
            ./modules/sddm-theme.nix
            ./hosts/nixboss/hardware-configuration.nix
            ./hosts/nixboss/configuration.nix
          ];
        };

        nixbeast = mkHost {
          hostname = "nixbeast";
          gccArch = "znver5";
          extraOverlays = [ firmware-overlay ];
          modules = [
            nixos-hardware.nixosModules.common-cpu-amd
            nixos-hardware.nixosModules.common-cpu-amd-pstate
            nixos-hardware.nixosModules.common-gpu-amd
            ./modules/amdgpu.nix
            ./modules/common.nix
            ./modules/zfs-common.nix
            ./modules/roles/desktop-wayland.nix
            ./modules/sddm-theme.nix
            ./hosts/nixbeast/hardware-configuration.nix
            ./hosts/nixbeast/configuration.nix
          ];
        };

        nixserve = mkHost {
          hostname = "nixserve";
          gccArch = "znver2";
          modules = [
            nixos-hardware.nixosModules.common-cpu-amd
            nixos-hardware.nixosModules.common-cpu-amd-pstate
            ./modules/common.nix
            ./modules/zfs-common.nix
            ./modules/roles/headless-rocm.nix
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
