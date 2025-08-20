{ config, lib, pkgs, ... }:
{
  # X11 + SDDM + Qtile (your current desktop)
  services.xserver = {
    enable = true;
    videoDrivers = [ "modesetting" ];
    xkb.layout = "us";
    desktopManager.plasma5.enable = false;
    desktopManager.xfce.enable = false;
    windowManager.qtile.enable = true;

    # You had DPI and cursor scaling in host; keep defaults here
  };

  services.displayManager.sddm = {
    enable = true;
    theme = "maya";
  };

  # Compositor for X11
  services.picom = {
    enable = true;
    backend = "glx";
    settings = {
      shadow = true;
      inactive_opacity = 0.8;
    };
  };

  # Graphics plumbing
  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [ ];
  };

  # XDG portal for X11 apps
  xdg.portal = {
    enable = true;
    config.common.default = "*";
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
  };

  # X11-friendly environment variables (scaling/themes)
  environment.variables = {
    #QT_AUTO_SCREEN_SCALE_FACTOR = "0";
    #QT_SCALE_FACTOR = "1.5";
    #QT_QPA_PLATFORMTHEME = "qt5ct";
    #QT_QPA_PLATFORM = "xcb";
    #GDK_SCALE = "1";
    #GDK_DPI_SCALE = "1.5";
    #_JAVA_OPTIONS = "-Dsun.java2d.uiScale=1.5";
    #XFT_DPI = builtins.toString 144;
  };

  programs = {
    thunar.enable = true;
    thunar.plugins = with pkgs.xfce; [ thunar-archive-plugin thunar-volman ];
    xfconf.enable = true;
  };

  # Desktop packages
  environment.systemPackages = with pkgs; [
    libsForQt5.breeze-qt5
    libsForQt5.breeze-gtk
    libsForQt5.qt5ct
    libsForQt5.plasma-integration
    xdg-desktop-portal-gtk

    # XFCE components you use
    xfce.xfwm4 xfce.xfdesktop xfce.orage xfce.xfconf
    xfce.xfwm4-themes
    xfce.xfce4-weather-plugin
    xfce.xfce4-volumed-pulse
    xfce.xfce4-pulseaudio-plugin
    xfce.xfce4-power-manager
    #xfce.thunar xfce.thunar-volman xfce.thunar-archive-plugin 
    xfce.mousepad xfce.tumbler

    # Your Python with qtile
    (python312.withPackages (ps: with ps; [ qtile crcmod ]))
    polkit_gnome
  ];
}