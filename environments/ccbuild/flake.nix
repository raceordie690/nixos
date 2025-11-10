{
  description = "A C/C++ development environment optimized for high-performance computing on modern AMD CPUs and GPUs.";

  inputs = {
    # We point to nixpkgs-unstable to get recent versions of compilers and libraries
    # like ROCm, which is crucial for performance and hardware support.
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      # This flake is designed for x86_64 Linux systems.
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };
    in
    {
      # The devShell provides the compiler, tools, and environment variables.
      devShells.${system}.default = pkgs.mkShell {
        # A message to show when entering the shell.
        shellHook = ''
          export MAKEFLAGS="-j$(nproc)"
          echo "C/C++ HPC Build Environment Ready."
          echo "Compiler flags are set for native architecture optimizations (AVX, etc.)."
          echo "MAKEFLAGS are set for parallel builds: $MAKEFLAGS"
          echo "For CMake, use: cmake --build . --parallel"
        '';

        # List of packages to make available in the shell.
        packages = with pkgs; [
          # Modern compiler toolchain. Clang is often preferred for its diagnostics
          # and performance, especially with LTO.
          llvmPackages_latest.clang
          llvmPackages_latest.lld

          # Essential build tools for C/C++ projects.
          cmake
          gnumake
          pkg-config
          coreutils # Provides 'nproc' for parallel job counting

          # ROCm SDK for GPU programming with HIP. This is what llama.cpp uses
          # for AMD GPU acceleration.
          rocmPackages.hipcc

          # ROCm tools for monitoring the GPU.
          rocmPackages.rocm-smi
          rocmPackages.rocminfo

          # A high-performance BLAS library that llama.cpp can leverage.
          openblas
        ];

        # Environment variables to configure the build.
        # NIX_CFLAGS_COMPILE is the standard way to pass flags in a Nix shell.
        NIX_CFLAGS_COMPILE = [
          # -O3: Enable aggressive optimizations for performance.
          "-O3"

          # -march=native: The key optimization. This tells the compiler to detect the
          # host CPU (e.g., Zen 3, Zen 4) and enable all available instruction sets,
          # including AVX, AVX2, and AVX512.
          "-march=native"

          # -flto=thin: Enable Thin Link-Time Optimization. This performs optimizations
          # across the entire program at link time, improving inlining and performance,
          # with a better compile time cost than full LTO.
          "-flto=thin"

          # -pipe: Use pipes instead of temporary files for compilation stages.
          "-pipe"
        ];
      };
    };
}
