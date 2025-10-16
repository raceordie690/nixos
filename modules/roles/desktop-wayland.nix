{ config, lib, pkgs, unstablePkgs, ... }:
let
  # This derivation packages all custom assets into a Nix store path.
  # All folders from `../assets` are copied into `$out/share/`
  # within the resulting package (e.g., wallpapers -> $out/share/wallpapers).
  custom-assets = pkgs.stdenv.mkDerivation {
    name = "robert-assets";
    src = ../assets;
    installPhase = ''
      mkdir -p $out/share
      cp -r $src/* $out/share/
    '';
  };
in
{
  # This override ensures that any part of your system asking for the
  # `xdg-desktop-portal-hyprland` package gets the version from `unstablePkgs`. In a
  # flake-based system, we use an overlay instead of `packageOverrides`.
  # The `programs.hyprland` module from your stable channel will now automatically
  # include the correct (unstable) portal, aligning it with your unstable Hyprland package.
  nixpkgs.overlays = [
    (final: prev: {
      xdg-desktop-portal-hyprland = unstablePkgs.xdg-desktop-portal-hyprland;
    })
  ];

  # Login/display: SDDM with Wayland support and custom theme
  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true;
    settings = {
      General = {
        DisplayServer = "wayland";
        GreeterEnvironment = "QT_SCREEN_SCALE_FACTORS=1.3333,QT_AUTO_SCREEN_SCALE_FACTOR=1.3333";
      };
    };
  };

  systemd.user.services.xsettingsd = {
    description = "XSettings daemon for GTK theming";
    after = [ "graphical-session-pre.target" ];
    partOf = [ "graphical-session.target" ];
    wantedBy = [ "graphical-session.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.xsettingsd}/bin/xsettingsd --replace";
      Restart = "on-failure";
    };
  };

  # This is generally not needed and can interfere with session-specific
  # environment variables. It's better to let each session manage this.
  # systemd.services.display-manager.environment.XDG_CURRENT_DESKTOP = "X-NIXOS-SYSTEMD-AWARE";

  environment.etc."xdg/xsettingsd/xsettingsd.conf".text = ''
    Net/ThemeName "Adwaita-dark"
    Net/IconThemeName "Adwaita"
    Gtk/CursorThemeName "breeze_cursors"
    Gtk/CursorThemeSize 48
    Xft/DPI 147456
  '';

  # Make sure SDDM/X11 isn't also enabled in this role
  # services.displayManager.sddm.enable = lib.mkForce false;
  services.xserver.enable = lib.mkForce false;

  services.tumbler.enable = true;
  services.gvfs.enable = true;
  # Enable power management service
  services.upower.enable = true;

  # Wayland plumbing
  programs.xwayland.enable = true;    # XWayland for X11-only apps
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
    extraPackages = with pkgs; [
      # rocmPackages.clr.icd # OpenCL is now handled by the amdgpu.nix module
      libva # VA-API
    ];
  };

  # Hyprland system-level enablement (configuration managed by home-manager)
  programs.hyprland = {
    enable = true;
    # Use the package from nixpkgs-unstable for the latest features and fixes
    package = unstablePkgs.hyprland;
    xwayland.enable = true; # Also enabled globally, but good to be explicit for the module.
    # Note: Hyprland configuration is managed by home-manager
    # System-level configuration only enables the program and sets up portals
  };

  # Portals: hyprland backend for Hyprland
  xdg.portal = {
    enable = true;
    # xdg-desktop-portal will automatically choose the correct backend (hyprland)
    # based on the running session.
    extraPortals = [
      unstablePkgs.xdg-desktop-portal-hyprland
      pkgs.xdg-desktop-portal-gtk
    ];
    # Explicitly configure which portal handles which interface
    config = {
      common = {
        default = [
          "gtk"
        ];
      };
      hyprland = {
        default = [
          "hyprland"
          "gtk"
        ];
        # Ensure settings interface is handled by GTK portal
        "org.freedesktop.impl.portal.Settings" = [
          "gtk"
        ];
      };
    };
  };

  # Wayland-friendly environment. Avoid forcing X11 platforms.
  environment.variables = {
    QT_AUTO_SCREEN_SCALE_FACTOR = "1.3333";
    #QT_QPA_PLATFORM = "wayland";
    QT_QPA_PLATFORM = "wayland;xcb";
    # This is likely a typo for WLR_DRM_DEVICES, used by wlroots-based compositors.
    WLR_DRM_DEVICES = "/dev/dri/card1:/dev/dri/card0";

    XDG_SESSION_TYPE = "wayland";
    MOZ_ENABLE_WAYLAND = "1";
    NIXOS_OZONE_WL = "1";
  };

  # System-level Wayland tools and desktop support
  environment.systemPackages = with pkgs; [
    # Core WiFi and networking GUI tools (system-level)
    networkmanagerapplet
    
    # System utilities for Wayland
    unstablePkgs.wlr-randr
    adwaita-icon-theme
    qt6ct
    
    # SDDM theming
    libsForQt5.breeze-qt5
    libsForQt5.breeze-icons

    # Deploy custom assets to the system profile
    custom-assets
  ];
}
