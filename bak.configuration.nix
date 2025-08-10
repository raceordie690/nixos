# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running `nixos-help`).

{ config, pkgs, ... }:

let 
  user = "robert";
  unstable = import <unstable> {};  
in
{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
      <nixos-hardware/common/cpu/amd/pstate.nix>
      <nixos-hardware/common/cpu/amd/default.nix>
      <nixos-hardware/common/gpu/amd/default.nix>
      <nixos-hardware/common/cpu/amd/raphael/igpu.nix>
      ./unstable-packages.nix
    ];
  #nix.package = pkgs.nixUnstable;
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nix.settings.allowed-users = [ "@wheel" ];
  nixpkgs.config.allowUnfree = true;

  boot.kernelPackages = pkgs.linuxPackages_6_12; 
  # Use the systemd-boot EFI boot loader.
  boot.loader = {  
    systemd-boot.enable = true;
    efi.canTouchEfiVariables = true;
  };
  #boot.loader.systemd-boot.enable = true;
  #boot.loader.efi.canTouchEfiVariables = true;

  networking.hostId = "e7a6ede7";
  networking.hostName = "nixboss"; # Define your hostname.
  # Pick only one of the below networking options.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.
  networking.networkmanager.enable = true;  # Easiest to use and most distros use this by default.

  services.zfs.autoScrub.enable = true;

  # Set your time zone.
  time.timeZone = "America/Chicago";

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";
  # console = {
  #   font = "Lat2-Terminus16";
  #   keyMap = "us";
  #   useXkbConfig = true; # use xkbOptions in tty.
  # };

  # Virt manager
  #virtualisation.libvirtd = {
  #  enable = true;
#
#    onShutdown = "suspend";
#    onBoot = "ignore";
#
#    qemu = {
#      package = pkgs.qemu_kvm;
#      ovmf.enable = true;
#      ovmf.packages = [ pkgs.OVMFFull.fd ];
#      swtpm.enable = true;
#      runAsRoot = false;
#    };
#  };

  programs.virt-manager.enable = true;
  virtualisation.libvirtd = {
    enable = true;
    onShutdown = "suspend";
    onBoot = "ignore";

    qemu = {
      package = pkgs.qemu_kvm;
      ovmf.enable = true;
      ovmf.packages = [ pkgs.OVMFFull.fd ];
      swtpm.enable = true;
      runAsRoot = false;
    };
  };

  virtualisation.spiceUSBRedirection.enable = true;

  environment.etc = {
    "ovmf/edk2-x86_64-secure-code.fd" = {
      source = config.virtualisation.libvirtd.qemu.package + "/share/qemu/edk2-x86_64-secure-code.fd";
    };  

    "ovmf/edk2-i386-vars.fd" = {
     source = config.virtualisation.libvirtd.qemu.package + "/share/qemu/edk2-i386-vars.fd";
    };
  };
  hardware.graphics = {
    enable = true;
    #driSupport = true;
    extraPackages = with unstable; [
      mesa
    ];
    #driSupport32Bit = true;
  };

  services = {
    libinput.enable = true;
    libinput.mouse.accelProfile = "adaptive";
    libinput.mouse.accelSpeed = "-0.425";
    displayManager.sddm = {
      enable = true;
      theme = "maya";
      #enableHidpi = true;
    };
  };
  #services.picom.enable = true;
  services.xserver = {
    dpi = 164;
    #dpi = 110;
    upscaleDefaultCursor = true;
    desktopManager.plasma5.enable = false;
    desktopManager.xfce.enable = false;
    #videoDrivers = [ "modesetting" ];
    videoDrivers = [ "amdgpu" ];
    xkb.layout = "us";
    #xkb.variant = "";
    enable = true;

    displayManager.setupCommands = ''
    
      #${pkgs.xorg.xrandr}/bin/xrandr --output DP-6 --mode 2560x2160 --output DP-7 --mode 2560x2160 --right-of DP-6 --setmonitor vDP-6 auto DP-6,DP-7 
      #${pkgs.xorg.xrandr}/bin/xrandr --output HDMI-1 --mode 2560x2160 --output HDMI-2 --mode 2560x2160 --right-of HDMI-1 --setmonitor vHDMI auto HDMI-1,HDMI-2 
      #${pkgs.xorg.xrandr}/bin/xrandr --output DP-4 --mode 3440x1440 --output DP-5 --off 
    '';
         
    windowManager.qtile = {

      enable = true;

      #backend = "x11";
      #backend = "wayland";
    };
    #displayManager.defaultSession = "none+qtile";
    #xrandrHeads = [ 
    #  {
    #    output = "DP-4";
    #    monitorConfig = ''
    #      DisplaySize 2560 2160
    #      Option "Enable" "True"
    #    '';
    #  }
    #  {
    #    output = "DP-5";
    #    monitorConfig = ''
    #      DisplaySize 2560 2160
    #      Option "RightOf" "DP-4"
    #      Option "Enable" "True"
    #    '';
    #  }
    #];
  };
  services.logind.extraConfig = ''
    # sleep when power button is short-pressed
    HandlePowerKey = "sleep";
    '';

  

  # Configure keymap in X11
  #services.xserver.layout = "us";
  #services.xserver.xkbOptions = "eurosign:e,caps:escape";

  programs.fish.enable = true;

  #programs.hyprland = {
  #   enable = true;
  #};

  #programs.hyprland.xwayland = {
  #   hidpi = true;
  #   enable = true;
  # };  
  # environment.sessionVariables.NIXOS_OZONE_WL = "1";

  # Enable CUPS to print documents.
  services.printing = {
    enable = true;
    drivers = [ pkgs.epson-escpr ];
    browsing = true;
    defaultShared = true;
  };
  
  services.blueman.enable = true;
  services.gnome.gnome-keyring.enable = true;

  hardware = {
    bluetooth.enable = true;
    bluetooth.powerOnBoot = true;
  };
  
  # Enable sound.
  # sound.enable = true;
  # hardware.pulseaudio.enable = true;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    # If you want to use JACK applications, uncomment this
    jack.enable = true;
  };

  
  # Enable touchpad support (enabled default in most desktopManager).
  # services.xserver.libinput.enable = true;

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.${user} = {
    shell = pkgs.fish;
    isNormalUser = true;
    initialPassword = "pwd";
    extraGroups = [ "wheel" "kvm" "libvirtd" "networkmanager" ]; # Enable ‘sudo’ for the user.
    packages = with pkgs; []; 
  };

  # List packages installed in system profile. To search, run:
  # $ nix search wget

  services.locate = {
    enable = true;
    package = pkgs.mlocate;
    localuser = null;
  };

  environment.etc = {
    "xdg/gtk-3.0" .source = ./gtk-3.0;
    "wireplumber/bluetooth.lua.d/51-bluez-config.lua".text = ''
	bluez_monitor.properties = {
	  ["bluez5.enable-sbc-xq"] = true,
          ["bluez5.enable-msbc"] = true,
	  ["bluez5.enable-hw-volume"] = true,
	  ["bluez5.headset-roles"] = "[ hsp_hs hsp_ag hfp_hf hfp_ag ]"
        }
    '';
    "wireplumber/main.lua.d/99-alsa-lowlatency.lua".text = ''
      alsa_monitor.rules = {
        {
          matches = {{{ "node.name", "matches", "alsa_output.*" }}};
          apply_properties = {
            ["audio.format"] = "S32LE",
            ["audio.rate"] = "96000", -- for USB soundcards it should be twice your desired rate
            ["api.alsa.period-size"] = 2, -- defaults to 1024, tweak by trial-and-error
            -- ["api.alsa.disable-batch"] = true, -- generally, USB soundcards use the batch mode
          },
        },
      }
    '';
  };

# Environment variables
  environment = {
    variables = {
      QT_AUTO_SCREEN_SCALE_FACTOR = "1.75";
      QT_QPA_PLATFORMTHEME = "qt5ct";
      QT_QPA_PLATFORM = "xcb"; /* obs";*/
      GDK_SCALE = "1";
      GDK_DPI_SCALE = "1";
      _JAVA_OPTIONS= "-Dsun.java2d.uiScale=1";
    };
  };

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = true;
  };

  # List services that you want to enable:
  environment.systemPackages = with pkgs; [
    #xorg.xf86videoamdgpu    
    swtpm
    xsettingsd
    picom
    service-wrapper
    htop
    git
    vim_configurable # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
    wget
    google-chrome
    blueman
    dracula-theme
  #  eww-wayland
    fontpreview
    gcolor3
    glibc
    gnome.gnome-keyring
    gnumake
    gparted
    gtk3
    gtk4
  #  hyprland
  #  hyprpaper
  #  hyprpicker
    libsecret
    neofetch
    networkmanagerapplet
    pavucontrol
    pipewire
    pkg-config
    polkit_gnome
  #  qt5.qtwayland
    qt6.qmake
  #  qt6.qtwayland
    ranger
    ripgrep
  #  rofi-wayland
    scrot
    tldr
    trash-cli
    unzip
  #  waybar
    zsh
    zsh-vi-mode
    wireplumber
    wl-color-picker
  #  wofi
  #  wlroots
  #  xdg-desktop-portal-hyprland
    xdg-desktop-portal-gtk
    xdg-utils
  #  xwayland
    zoxide
    python311
    python311Packages.crcmod
    #python311Packages.qtile-extras
    xfce.xfce4-power-manager
    dunst
    #polybar
    #polybar-pulseaudio-control
    brave
    xfce.thunar
    xfce.thunar-volman
    xfce.thunar-archive-plugin
    xfce.mousepad
    xfce.tumbler
    alacritty
    rofi
    figlet
    libsForQt5.breeze-qt5
    libsForQt5.breeze-gtk
    lxappearance
    vlc
    mpv
    starship
    nitrogen 
    scrot
    slock
    pywal
    libnotify
    libsForQt5.qt5ct
    xfce.xfwm4
    xfce.xfdesktop
    xfce.orage
    xfce.xfconf
    xfce.xfwm4-themes
    xfce.xfce4-weather-plugin
    xfce.xfce4-volumed-pulse
    xfce.xfce4-pulseaudio-plugin
    libsForQt5.plasma-integration
    mbuffer
  ];

  fonts.fontDir.enable = true;
  fonts.packages = with pkgs; [  
    monoid
    victor-mono
    cascadia-code
    fira-code
    nerdfonts
    font-awesome
    google-fonts
    dejavu_fonts
    open-sans
  ];
  services = {
    gvfs.enable = true;
    dbus.enable = true;
    envfs.enable = true;
  };

  xdg.portal = {
    config.common.default = "*";
    enable = true;
    extraPortals = [ 
    pkgs.xdg-desktop-portal-gtk
    ];
  }; 
  # Enable the OpenSSH daemon.
  # services.openssh.enable = true;
  services.openssh = {
    enable = true;
    # require public key authentication for better security
    settings.PasswordAuthentication = false;
    settings.KbdInteractiveAuthentication = false;
    #settings.PermitRootLogin = "yes";
  };

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  networking.firewall.enable = false;
  networking.extraHosts = 
  ''
  '';

  # Copy the NixOS configuration file and link it from the resulting system{ config, pkgs, ... }:
  # (/run/current-system/configuration.nix). This is useful in case you
  # accidentally delete configuration.nix.
  # system.copySystemConfiguration = true;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It's perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "23.11"; # Did you read the comment?


  #nixpkgs.overlays = [
  #  ( final: previous: {
  #    viber = final.unstable.viber.override (oldAttrs: {
  #      src = final.fetchurl {
  #        url = "https://web.archive.org/web/20240114085219/https://download.cdn.viber.com/cdn/desktop/Linux/viber.deb";
  #        sha256 = "sha256-RrObmN21QOm5nk0R2avgCH0ulrfiUIo2PnyYWvQaGVw"; # same hash as original commit in this PR https://github.com/NixOS/nixpkgs/pull/323215
  #      };
  #    });
  #  })
  #];
}
