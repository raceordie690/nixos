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

  # Create a script to copy wallpapers to /usr/share/wallpapers
  wallpaper-setup = pkgs.writeScriptBin "setup-wallpapers" ''
    #!/bin/bash
    
    # Create the wallpapers directory if it doesn't exist
    mkdir -p /usr/share/wallpapers
    
    # Copy wallpapers from your custom assets
    if [ -d "${custom-assets}/share/wallpapers" ]; then
      cp -f "${custom-assets}/share/wallpapers/"* /usr/share/wallpapers/ 2>/dev/null || true
    fi
    
    # Copy wallpapers from system packages
    for wallpaper_dir in \
      "/run/current-system/sw/share/wallpapers" \
      "/run/current-system/sw/share/backgrounds"; do
      if [ -d "$wallpaper_dir" ]; then
        find "$wallpaper_dir" -name "*.jpg" -o -name "*.jpeg" -o -name "*.png" -o -name "*.bmp" | \
        head -20 | while read -r file; do
          cp "$file" /usr/share/wallpapers/ 2>/dev/null || true
        done
      fi
    done
    
    # Ensure we have at least one wallpaper
    if [ ! "$(ls -A /usr/share/wallpapers 2>/dev/null)" ]; then
      # Create a simple gradient fallback
      ${pkgs.imagemagick}/bin/convert -size 1920x1080 gradient:#1e1e2e-#313244 /usr/share/wallpapers/default.jpg
    fi
    
    # Set proper permissions
    chmod 755 /usr/share/wallpapers
    chmod 644 /usr/share/wallpapers/* 2>/dev/null || true
    
    echo "Wallpapers copied to /usr/share/wallpapers:"
    ls -la /usr/share/wallpapers/
  '';

in {
  # Install required packages for the theme
  environment.systemPackages = with pkgs; [
    sddm-custom-theme
    wallpaper-setup
    custom-assets
    # Qt packages for SDDM theme support
    libsForQt5.qt5.qtdeclarative
    libsForQt5.qt5.qtgraphicaleffects
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
        HideUsers = "";
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
      ExecStart = "${wallpaper-setup}/bin/setup-wallpapers";
      RemainAfterExit = true;
    };
  };

  # Create the wallpapers directory structure
  system.activationScripts.sddm-wallpapers = ''
    mkdir -p /usr/share/wallpapers
    ${wallpaper-setup}/bin/setup-wallpapers
  '';
}