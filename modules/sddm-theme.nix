{ config, lib, pkgs, ... }:

let
  # Package the custom SDDM theme
  sddm-custom-theme = pkgs.stdenv.mkDerivation {
    name = "sddm-custom-theme";
    src = ./sddm-custom-theme;
    installPhase = ''
      mkdir -p $out/share/sddm/themes/sddm-custom-theme
      cp -r $src/* $out/share/sddm/themes/sddm-custom-theme/
    '';
  };

  # Reference to your custom assets package (defined in desktop-wayland.nix)
  custom-assets = pkgs.stdenv.mkDerivation {
    name = "robert-assets";
    src = ./assets;
    installPhase = ''
      mkdir -p $out/share
      cp -r $src/* $out/share/
    '';
  };

  # Create a script to copy wallpapers to /usr/share/sddm-wallpapers
  wallpaper-setup = pkgs.writeShellScriptBin "setup-sddm-wallpapers" ''
    set -euo pipefail
    
    # Create the dedicated SDDM wallpapers directory
    mkdir -p /usr/share/sddm-wallpapers
    
    # Clear any existing wallpapers first
    rm -f /usr/share/sddm-wallpapers/*
    
    # Copy ONLY your custom wallpapers
    if [ -d "${custom-assets}/share/wallpapers" ]; then
      echo "Copying custom wallpapers to SDDM directory..."
      cp -f "${custom-assets}/share/wallpapers/"* /usr/share/sddm-wallpapers/ 2>/dev/null || true
    fi
    
    # Create a simple fallback wallpaper if none exist
    if [ ! "$(ls -A /usr/share/sddm-wallpapers 2>/dev/null)" ]; then
      echo "Creating fallback wallpaper..."
      ${pkgs.imagemagick}/bin/convert -size 1920x1080 gradient:#1e1e2e-#313244 /usr/share/sddm-wallpapers/default.jpg
    fi
    
    # Set proper permissions
    chmod 755 /usr/share/sddm-wallpapers
    chmod 644 /usr/share/sddm-wallpapers/* 2>/dev/null || true
    
    echo "SDDM wallpapers setup complete. Contents of /usr/share/sddm-wallpapers:"
    ls -la /usr/share/sddm-wallpapers/ || true
  '';

in {
  # Install required packages for the theme
  environment.systemPackages = with pkgs; [
    sddm-custom-theme
    wallpaper-setup
    custom-assets
    # Qt packages for SDDM theme support
    libsForQt5.qt5.qtdeclarative
    libsForQt5.qt5.qtgraphicaleffects  # Essential for proper blur
    libsForQt5.qt5.qtquickcontrols2
    qt6.qtdeclarative
    qt6.qt5compat  # For Qt5 compatibility in Qt6
    imagemagick  # For creating fallback wallpapers
  ];

  # Configure SDDM to use our custom theme
  services.displayManager.sddm = {
    enable = true;
    theme = "sddm-custom-theme";
    settings = {
      Theme = {
        Current = "sddm-custom-theme";
        CursorTheme = "breeze_cursors";
        CursorSize = "24";
        EnableAvatars = true;
        DisableAvatarsThreshold = 7;
      };
      General = {
        HaltCommand = "/run/current-system/systemd/bin/systemctl poweroff";
        RebootCommand = "/run/current-system/systemd/bin/systemctl reboot";
        Numlock = "none";
      };
      Users = {
        MaximumUid = 60000;
        MinimumUid = 1000;
        HideUsers = "nixbld";
        HideShells = "/bin/false,/usr/bin/nologin,/sbin/nologin";
      };
    };
  };

  # Ensure wallpapers directory is set up before SDDM starts
  systemd.services.sddm-wallpaper-setup = {
    description = "Setup wallpapers for SDDM custom theme";
    wantedBy = [ "display-manager.service" ];
    before = [ "display-manager.service" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${wallpaper-setup}/bin/setup-sddm-wallpapers";
      RemainAfterExit = true;
    };
  };

  # Create the wallpapers directory structure
  system.activationScripts.sddm-wallpapers = lib.mkAfter ''
    echo "Setting up dedicated SDDM wallpapers directory..."
    mkdir -p /usr/share/sddm-wallpapers
    
    # Clear any existing wallpapers first
    rm -f /usr/share/sddm-wallpapers/*
    
    # Copy ONLY your custom wallpapers
    if [ -d "${custom-assets}/share/wallpapers" ]; then
      echo "Copying your custom wallpapers..."
      cp -f "${custom-assets}/share/wallpapers/"* /usr/share/sddm-wallpapers/ 2>/dev/null || true
    fi
    
    # Create a simple fallback if no custom wallpapers exist
    if [ ! "$(ls -A /usr/share/sddm-wallpapers 2>/dev/null)" ]; then
      echo "Creating fallback wallpaper..."
      ${pkgs.imagemagick}/bin/convert -size 1920x1080 gradient:#1e1e2e-#313244 /usr/share/sddm-wallpapers/default.jpg || true
    fi
    
    # Set permissions
    chmod 755 /usr/share/sddm-wallpapers || true
    chmod 644 /usr/share/sddm-wallpapers/* 2>/dev/null || true
    
    echo "SDDM wallpapers setup complete. Available wallpapers:"
    ls -la /usr/share/sddm-wallpapers/ 2>/dev/null || true
  '';
}