{ config, lib, pkgs, unstablePkgs, ... }:
let
  # Get the original qtile package from unstable
  originalQtile = unstablePkgs.python312Packages.qtile;

  # Override the package to customize its .desktop file directly.
  # This is cleaner than creating a separate file and avoids potential collisions.
  qtileEnv = originalQtile.overrideAttrs (oldAttrs: {
    # The original postInstall creates the .desktop file. We'll run after it
    # and modify the file in place to add dbus-run-session. The qtile package
    # recently changed its build system, which also changed the .desktop filename
    # and its contents. We update the path and the search string to match.
    postInstall = (oldAttrs.postInstall or "") + ''
      # The original postInstall substitutes "Exec=qtile..." with "Exec=$out/bin/qtile...".
      # We need to match that full string to modify it further.
      # Using double quotes for the shell allows the $out variable to be expanded.
      substituteInPlace $out/share/wayland-sessions/qtile-wayland.desktop \
        --replace "Exec=$out/bin/qtile start -b wayland" "Exec=${unstablePkgs.dbus}/bin/dbus-run-session $out/bin/qtile start -b wayland"
    '';
  });
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

  # Login/display: greetd launching Qtile (Wayland backend)
  services.greetd = {
    enable = true;
    # Setting restart to true is intended for development and can cause
    # instability during a `nixos-rebuild switch`. The default is false.
    restart = false;
    settings = {
      default_session = {
        # By removing --cmd, tuigreet will look for .desktop files in /usr/share/wayland-sessions
        # This gives you a menu to choose between Qtile, Hyprland, etc.
        command = "${pkgs.greetd.tuigreet}/bin/tuigreet --remember --time";
        user = "greeter";
      };
    };
  };

  # Make display manager sessions available to greetd so it can find Qtile.
  services.displayManager.sessionPackages = [ qtileEnv ];

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
  services.displayManager.sddm.enable = lib.mkForce false;
  services.xserver.enable = lib.mkForce false;

  services.tumbler.enable = true;
  services.gvfs.enable = true;

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

  # Hyprland configuration
  programs.hyprland = {
    enable = true;
    # Use the package from nixpkgs-unstable for the latest features and fixes
    package = unstablePkgs.hyprland;
    xwayland.enable = true; # Also enabled globally, but good to be explicit for the module.
    # To migrate your configuration from home-manager, find the
    # `wayland.windowManager.hyprland.extraConfig` section in your
    # `/home/robert/.config/home-manager/hyprland.nix` file and
    # copy its contents between the triple quotes below.
  };

  # Portals: wlr backend for wlroots compositors (Qtile Wayland)
  xdg.portal = {
    enable = true;
    # By removing the hardcoded default, xdg-desktop-portal will automatically
    # choose the correct backend (hyprland or wlr) based on the running session.
    # config.common.default = "wlr";
    extraPortals = [
      unstablePkgs.xdg-desktop-portal-wlr # For Qtile
      pkgs.xdg-desktop-portal-gtk
    ];
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

  # Handy Wayland tools and desktop apps
  environment.systemPackages = with pkgs; [

    qtileEnv # Install our modified qtile package, which includes the custom session file.

    unstablePkgs.wlr-randr
    adwaita-icon-theme
    qt6ct
  ];
}
