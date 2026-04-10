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

  # ============================================================================
  # Boot
  # ============================================================================
  boot.plymouth.enable = true;

  # ============================================================================
  # Input
  # ============================================================================
  services.libinput = {
    enable = true;
    mouse.accelProfile = "adaptive";
    mouse.accelSpeed = "-0.425";
  };

  # ============================================================================
  # Sound / PipeWire
  # ============================================================================
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    jack.enable = true;
  };

  # WirePlumber tuning
  services.pipewire.wireplumber.extraConfig.bluetoothEnhancements = {
    "monitor.bluez.properties" = {
      "bluez5.enable-sbc-xq" = true;
      "bluez5.enable-msbc" = true;
      "bluez5.enable-hw-volume" = true;
      "bluez5.roles" = [ "hsp_hs" "hsp_ag" "hfp_hf" "hfp_ag" ];
    };
  };
  services.pipewire.extraConfig.pipewire-pulse."92-low-latency" = {
    context.modules = [
      {
        name = "libpipewire-module-protocol-pulse";
        args = {
          pulse.min.req = "32/48000";
          pulse.default.req = "32/48000";
          pulse.max.req = "32/48000";
          pulse.min.quantum = "32/48000";
          pulse.max.quantum = "32/48000";
        };
      }
    ];
    stream.properties = {
      node.latency = "32/48000";
      resample.quality = 1;
    };
  };

  # ============================================================================
  # Bluetooth
  # ============================================================================
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };
  services.blueman.enable = true;

  environment.etc."wireplumber/bluetooth.lua.d/51-bluez-config.lua".text = ''
    bluez_monitor.properties = {
      ["bluez5.enable-sbc-xq"] = true,
      ["bluez5.enable-msbc"] = true,
      ["bluez5.enable-hw-volume"] = true,
      ["bluez5.headset-roles"] = "[ hsp_hs hsp_ag hfp_hf hfp_ag ]"
    }
  '';

  environment.etc."wireplumber/main.lua.d/99-alsa-lowlatency.lua".text = ''
    alsa_monitor.rules = {
      {
        matches = {{{ "node.name", "matches", "alsa_output.*" }}};
        apply_properties = {
          ["audio.format"] = "S32LE",
          ["audio.rate"] = "96000",
          ["api.alsa.period-size"] = 2,
        },
      },
    }
  '';

  # ============================================================================
  # Printing & Scanning (Epson)
  # ============================================================================
  services.printing = {
    enable = true;
    drivers = [ pkgs.epson-escpr ];
    browsing = true;
    defaultShared = true;
  };

  hardware.sane = {
    enable = true;
    extraBackends = [ pkgs.epkowa ];
  };

  services.saned.enable = true;

  environment.etc."sane.d/net.conf".text = ''
    172.19.168.30
  '';

  environment.etc."sane.d/epkowa.conf".text = ''
    # Enable network scanning for Epson scanners
    net autodiscovery
    net 172.19.168.30:9100
  '';

  environment.etc."sane.d/epsonscan.conf".text = ''
    192.168.1.0/24
    172.19.168.0/24
  '';

  # ============================================================================
  # Keyring (GNOME keyring unlocked at login for desktop sessions)
  # ============================================================================
  services.gnome.gnome-keyring.enable = true;
  security.pam.services.login.enableGnomeKeyring = true;

  # ============================================================================
  # Login / Display manager
  # ============================================================================
  services.greetd = {
    enable = true;
    settings = {
      default_session = {
        command = "${pkgs.tuigreet}/bin/tuigreet --cmd hyprland";
        user = "greeter";
        vt = 1;
      };
    };
  };

  security.pam.services.greetd.enableGnomeKeyring = true;

  # Make sure X11 isn't also enabled in this role
  services.xserver.enable = lib.mkForce false;

  services.tumbler.enable = true;
  services.gvfs.enable = true;
  services.upower.enable = true;

  # ============================================================================
  # Hyprland / Wayland
  # ============================================================================
  programs.xwayland.enable = true;

  programs.hyprland = {
    enable = true;
    package = unstablePkgs.hyprland;
    xwayland.enable = true;
  };

  xdg.portal = {
    enable = true;
    extraPortals = [
      unstablePkgs.xdg-desktop-portal-hyprland
      pkgs.xdg-desktop-portal-gtk
    ];
  };

  # Wayland-friendly environment variables
  environment.variables = {
    QT_AUTO_SCREEN_SCALE_FACTOR = "1.3333";
    QT_SCREEN_SCALE_FACTORS = "1.3333";
    QT_QPA_PLATFORM = "wayland;xcb";
    GDK_SCALE = "1.3333";
    XDG_SESSION_TYPE = "wayland";
    MOZ_ENABLE_WAYLAND = "1";
    NIXOS_OZONE_WL = "1";
  };

  # GTK file chooser defaults
  environment.etc."xdg/gtk-2.0/gtkfilechooser.ini".text = ''
    [Filechooser Settings]
    LocationMode=path-bar
    ShowHidden=false
    ShowSizeColumn=true
    GeometryX=0
    GeometryY=79
    GeometryWidth=948
    GeometryHeight=643
    SortColumn=name
    SortOrder=ascending
    StartupMode=recent
  '';

  # ============================================================================
  # Desktop packages
  # ============================================================================
  environment.systemPackages = with pkgs; [
    # Theming / GTK
    gnome-keyring
    gtk3
    gtk4
    adwaita-icon-theme
    qt6Packages.qt6ct
    gtklock
    xsettingsd

    # Media
    vlc
    mpv

    # Terminal / shell extras
    kitty
    figlet
    ranger

    # GUI utilities
    networkmanagerapplet
    pavucontrol
    gparted
    fontpreview
    gcolor3
    wl-color-picker
    scrot
    ddcutil
    via           # QMK keyboard config

    # WiFi GUI tools
    iwgtk
    wpa_supplicant_gui

    # Wayland utilities
    unstablePkgs.wlr-randr
    wireplumber   # CLI tool (service is managed by pipewire module)
    blueman

    # Scanner
    epsonscan2

    # Greeter
    tuigreet

    # Custom assets (wallpapers, etc.)
    custom-assets
  ];
}
