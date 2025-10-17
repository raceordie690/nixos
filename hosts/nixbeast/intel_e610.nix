{ lib, config, pkgs, ... }:

let
  kernel = config.boot.kernelPackages.kernel;

  ixgbeVendor = pkgs.stdenv.mkDerivation rec {
    pname = "ixgbe-intel-vendor";
    version = "6.1.3";

    src = pkgs.fetchFromGitHub {
      owner = "intel";
      repo = "ethernet-linux-ixgbe";
      rev = "v${version}";
      hash = "sha256-oY9oB2mcr8ncrQqY8FXrMxf2RW1a2UKJMBx3v0IPcls=";
    };

    nativeBuildInputs = [
      pkgs.bash
      pkgs.gawk
      pkgs.coreutils
      pkgs.gnugrep
      pkgs.gnused
      pkgs.findutils
    ];
    buildInputs = [ kernel.dev ];

    KERNEL_SRC = "${kernel.dev}/lib/modules/${kernel.modDirVersion}/build";
    INSTALL_MOD_PATH = "$out";

    buildPhase = ''
      set -euo pipefail
      cd src
      set -x

      export KDIR="${KERNEL_SRC}"
      export KERNELDIR="${KERNEL_SRC}"
      export KSRC="${KERNEL_SRC}/source"

      # Parallel make honoring Nix’s allocation
      PARALLEL_MAKE="-j''${NIX_BUILD_CORES:-$(nproc)}"

      # Basic tools for the script (already in nativeBuildInputs, but ensure in PATH)
      export PATH=${pkgs.coreutils}/bin:${pkgs.gnugrep}/bin:${pkgs.gnused}/bin:${pkgs.findutils}/bin:${pkgs.gawk}/bin:${pkgs.bash}/bin:$PATH

      # Sanity checks
      test -f "${KERNEL_SRC}/Makefile"
      test -d "${KERNEL_SRC}/include"
      test -d "${KERNEL_SRC}/source"
      test -f "${KERNEL_SRC}/source/Makefile"

      # Kernel .config for the generator
      if [ -f "${KERNEL_SRC}/source/.config" ]; then
        export CONFIG_FILE="${KERNEL_SRC}/source/.config"
      elif [ -f "${KERNEL_SRC}/.config" ]; then
        export CONFIG_FILE="${KERNEL_SRC}/.config"
      else
        echo "Could not find kernel .config under ${KERNEL_SRC}/source or ${KERNEL_SRC}"
        exit 1
      fi

      # Some generators need initrd.kernelModules = ["ixgbe" ]; ARCH and CC; provide sensible defaults
      export ARCH="$(uname -m)"
      export CC="${pkgs.stdenv.cc.targetPrefix}gcc" || true

      echo "Running kcompat-generator.sh with KSRC="''${KSRC}" CONFIG_FILE="''${CONFIG_FILE}
      # Capture stdout to a file so we can create the header if that is how it emits
      bash ./kcompat-generator.sh > kcompat_generated_defs.h.tmp

      # If script printed a header, promote it. If it produced nothing on stdout,
      # try to locate the file it created elsewhere.
      if [ -s kcompat_generated_defs.h.tmp ]; then
        mv kcompat_generated_defs.h.tmp kcompat_generated_defs.h
      else
        rm -f kcompat_generated_defs.h.tmp
        # Look for a generated header anywhere under src/
        GEN=$(find . -maxdepth 3 -type f -name 'kcompat_generated_defs.h' | head -n1 || true)
        if [ -n "''${GEN}" ]; then
          cp -v "''${GEN}" ./kcompat_generated_defs.h
        else
          echo "kcompat-generator.sh did not produce kcompat_generated_defs.h"
          echo "Dumping its stdout/stderr for debugging:"
          # Re-run to show logs
          bash -x ./kcompat-generator.sh || true
          exit 1
        fi
      fi

      ls -l kcompat_generated_defs.h | cat
      export BUILD_SRC_DIR="$(pwd)"
      # Build the module via kbuild (verbose)
      make -C "${KERNEL_SRC}" M="$PWD" EXTRA_CFLAGS="-Wno-error" V=1 modules ''${PARALLEL_MAKE}
    '';

    installPhase = ''
      set -euo pipefail
      set -x

      # Use the directory recorded during buildPhase
      test -n "''${BUILD_SRC_DIR:-}" || { echo "BUILD_SRC_DIR not set; buildPhase may have failed"; exit 1; }
      test -d "$BUILD_SRC_DIR" || { echo "Expected build dir not found: $BUILD_SRC_DIR"; exit 1; }

      PARALLEL_MAKE="-j''${NIX_BUILD_CORES:-$(nproc)}"

      echo "KERNEL_SRC=${KERNEL_SRC}"
      echo "BUILD_SRC_DIR=$BUILD_SRC_DIR"
      echo "INSTALL_MOD_PATH=$out"

      # Optional: verify .ko exists before installing
      if ! find "$BUILD_SRC_DIR" -maxdepth 2 -type f -name '*.ko' | grep -q . ; then
        echo "No built .ko files under $BUILD_SRC_DIR; modules_install would be a no-op"
        find "$BUILD_SRC_DIR" -maxdepth 3 -type f -ls || true
        exit 1
      fi

      make -C "${KERNEL_SRC}" M="$BUILD_SRC_DIR" INSTALL_MOD_PATH="$out" V=1 ''${PARALLEL_MAKE} modules_install

      find "$out" -maxdepth 6 -type f -ls || true
    '';

    meta = with lib; {
      description = "Intel ixgbe out-of-tree driver ${version}";
      license = licenses.gpl2Only;
      platforms = platforms.linux;
      homepage = "https://github.com/intel/ethernet-linux-ixgbe";
    };
  };
in
{
  config.boot = {
    extraModulePackages = [ ixgbeVendor ];
    initrd.kernelModules = [  "ixgbe" ];
    blacklistedKernelModules = [ "ixgbe" ];
  };
}