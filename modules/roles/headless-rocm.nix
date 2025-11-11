{ config, pkgs, unstablePkgs, lib, ... }:
{
  imports = [ ../rocm.nix ];

  config = {
    # 1. Disable Graphical Interface for a headless server.
    services.xserver.enable = false;
    services.displayManager.sddm.enable = false;
    services.desktopManager.plasma6.enable = false;
    services.greetd.enable = false;

    # 2. Enable the consolidated ROCm module.
    drivers.rocm.enable = true;

    # 3. Configure Ollama for ROCm.
    services.ollama = {
      enable = true;
      package = unstablePkgs.ollama-rocm;
      acceleration = "rocm";
    };

    # 4. Add users to the 'render' and 'video' groups to allow access to the GPU.
    users.users.robert.extraGroups = [ "render" "video" ];
  };
}
