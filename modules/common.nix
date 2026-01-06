{ config, lib, pkgs, ... }:
let
  user = "robert";
in
{

  boot = {
    # silence first boot output
    consoleLogLevel = 3;

    kernelParams = [
        "quiet"
        "boot.shell_on_fail"
        "udev.log_priority=3"
        "rd.systemd.show_status=auto"
    ];

    # plymouth, showing after LUKS unlock
    plymouth.enable = true;
  };


  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  # Use the recommended setting for firmware. This includes most common firmware
  # (including Realtek rtw88) without pulling in everything, which can cause
  # breakages when packages are removed from nixpkgs.
  hardware.uinput.enable = true;

  hardware.enableRedistributableFirmware = true;
  # Podman is optional unless you’ll run containers, but many AI UIs assume it.
  virtualisation.podman.enable = true;
  
  # Add settings for the Nix daemon here.
  nix.settings = {
    # Ensure flakes are enabled.
    experimental-features = [ "nix-command" "flakes" ];
    # Add 'robert' to trusted-users to allow user-level flake evaluation and builds.
    #trusted-users = [ "root" user ];
    allowed-users = [ "@wheel" ];
    sandbox = true;
    # Increase the download buffer to 64 MiB to handle larger files.
    # The value is in bytes. 96 * 1024 * 1024 = 100,663,296
    download-buffer-size = 100663296;
  };


  # Locale/time
  time.timeZone = "America/Chicago";
  services.timesyncd.enable = true;
  i18n.defaultLocale = "en_US.UTF-8";




  # Networking with WiFi support
  networking = {
    useDHCP = lib.mkDefault true;
    networkmanager = {
      enable = true;
      wifi = {
        powersave = false;  # Disable WiFi power saving for better performance
        backend = "wpa_supplicant";
      };
      # Add plugins to NetworkManager.
      plugins = [  ];
      
      # Force specific DNS servers and ignore auto-DNS from DHCP/IPv6 RA
      dns = "none";  # Disable NetworkManager's DNS management
    };
    
    # Manually set DNS servers and search domains
    nameservers = [ "192.168.1.254" ];
    search = [ "attlocal.net" "lan" ];
    
    firewall.enable = false;
  };
  # Enable wireless regulatory domain for WiFi
  hardware.wirelessRegulatoryDatabase = true;

  services.avahi = {
    enable = true;
    nssmdns4 = true;  # Enable IPv4 mDNS in NSS
    nssmdns6 = true;  # Enable IPv6 mDNS in NSS (optional)
    ipv4 = true;
    ipv6 = true;
    publish = {
      enable = true;
      addresses = true;
      workstation = true;
    };
    # This is the key to resolving single-label hostnames (e.g., "nixserve")
    # without needing to append ".local". It configures nss-mdns to handle them.
    extraConfig = ''
      [server]
      domain-name=.local
    '';
  };

  # Firmware/udev
  services.fwupd.enable = true;
  services.udev.extraRules = ''
    KERNEL=="hidraw*", ATTRS{idVendor}=="fffe", ATTRS{idProduct}=="0009", TAG+="uaccess"
    KERNEL=="uinput", MODE="0660", GROUP="uinput"
  '';


  # Input
  services.libinput = {
    enable = true;
    mouse.accelProfile = "adaptive";
    mouse.accelSpeed = "-0.425";
  };

  # Sound/media
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    jack.enable = true;
  };

  # WirePlumber tuning (shared)
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

  # Services/utilities
  services.blueman.enable = true;
  services.printing = {
    enable = true;
    drivers = [ pkgs.epson-escpr ];
    browsing = true;
    defaultShared = true;
  };

  services.gvfs.enable = true;
  services.envfs.enable = true;

  # SSH and locate
  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = true;
    settings.KbdInteractiveAuthentication = true;
    openFirewall = true;
  };
  services.locate = {
    enable = true;
    package = pkgs.plocate;
  };

  # User
  users.users.${user} = {
    isNormalUser = true;
    initialPassword = "pwd";

    # Enable the user-level ssh-agent service. This ensures that an SSH agent
    # is running for the 'robert' user, which is required for the Nix daemon
    # to use their SSH keys for fetching private sources.
    #useDefaultShell = true;


 
    extraGroups = [ "wheel" "kvm" "libvirtd" "networkmanager" "audio" "video" "render" "netdev" "input" "uinput" ];
    packages = with pkgs; [ ];
    openssh.authorizedKeys.keys = [
      "ecdsa-sha2-nistp521 AAAAE2VjZHNhLXNoYTItbmlzdHA1MjEAAAAIbmlzdHA1MjEAAACFBAGOvoX3deODoSn/brDTWYmLAgLVpCJC5fuKvWXNj+oVFYt3fA9S3B8ZAs8H867tJhAbRz3FunMYJ+vPG1WqcTk0lgBY2whugExPd6WxhrTb3NVVW2Z+t6W3B5pE0nw6BL0zk+9vimIp3y0d8PBADU/5jeYz+7HodzdEol75EnX1btXeGg== robert@nixboss"
    ];
  };

  users.users.nm-openconnect = {
    group = "nm-openconnect";
    isSystemUser = true;
  };
  users.groups.nm-openconnect = {};
  users.groups.netdev = {};

  # The GPG agent with SSH support should be managed by home-manager for the user,
  # not at the system level. This prevents sudo/root from trying to access the
  # user's agent socket during builds.
  # programs.ssh.startAgent should also be managed by home-manager.

  # OVMF files for libvirt
  environment.etc."ovmf/edk2-x86_64-secure-code.fd".source =
    config.virtualisation.libvirtd.qemu.package + "/share/qemu/edk2-x86_64-secure-code.fd";
  environment.etc."ovmf/edk2-i386-vars.fd".source =
    config.virtualisation.libvirtd.qemu.package + "/share/qemu/edk2-i386-vars.fd";

  hardware.bluetooth =  {
    enable = true;
    powerOnBoot = true;
  };


  # Common etc files
  environment.etc = {
    "wireplumber/bluetooth.lua.d/51-bluez-config.lua".text = ''
      bluez_monitor.properties = {
        ["bluez5.enable-sbc-xq"] = true,
        ["bluez5.enable-msbc"] = true,
        ["bluez5.enable-hw-volume"] = true,
        ["bluez5.headset-roles"] = "[ hsp_hs hsp_ag hfp_hf hfp_ag ]"
      }
    '';
    # Fixed the path here: xdg/gtk-2.0 (slash, not dot)
    "xdg/gtk-2.0/gtkfilechooser.ini".text = ''
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
    "wireplumber/main.lua.d/99-alsa-lowlatency.lua".text = ''
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
    # NOTE: The GTK3 settings.ini has been removed from here.
    # Theming is now managed centrally by `programs.xsettingsd` in the
    # `desktop-wayland.nix` role to avoid conflicts and provide a
    # single source of truth for the graphical session.
    #
    # If you need to set themes, please modify the `programs.xsettingsd.settings`
    # attribute set in `/home/robert/nixos/modules/roles/desktop-wayland.nix`.

  };

  # 1. Enable the daemon system-wide (This replaces the Home Manager service)
  services.gnome.gnome-keyring.enable = true;

  # 2. UNLOCK the keyring on login (The critical missing piece)
  security.pam.services.login.enableGnomeKeyring = true;

  # Core packages shared by all hosts
  environment.systemPackages = with pkgs; [
    gnome-keyring
    home-manager
    toolbox # Tool for containerized command line environments on Linux
    neovim
    neofetch
    btop
    stow
    libva-utils  # For checking hardware acceleration status with `vainfo`
    via 
    swtpm
    xsettingsd
    htop 
    git 
    wget 
    ripgrep 
    unzip 
    tldr 
    trash-cli 
    zoxide 
    glibc 
    gnumake 
    pkg-config
    blueman
    fontpreview 
    gcolor3
    gparted # Note: requires a graphical session to run
    pavucontrol
    qt6.qtbase # Provides qmake
    ranger
    scrot
    vim-full
    wireplumber # This is already enabled as a service via pipewire
    wl-color-picker
    xdg-utils
    mbuffer
    vlc

    # Apps
    mpv
    curl

    kitty
    gtk3
    gtk4
    figlet
    networkmanagerapplet
    gtklock
    
    # Additional WiFi and networking tools
    iwgtk              # Lightweight WiFi GUI
    wpa_supplicant_gui # WPA Supplicant GUI
    iw                # Modern wireless configuration tool
    wirelesstools     # iwconfig, iwlist, etc.
    ethtool           # Ethernet configuration
    speedtest-cli     # Network speed testing
    iperf3            # Network performance testing

    parallel

  ];


  # 25.05 (or later) Fonts
  fonts = {
    fontconfig.enable = true;
    fontDir.enable = true;
    packages = with pkgs; [
      monoid
      victor-mono
      cascadia-code
      font-awesome
      google-fonts
      dejavu_fonts
      open-sans
      nerd-fonts.jetbrains-mono
      nerd-fonts.symbols-only
      noto-fonts
      noto-fonts-color-emoji
    ];
  };

  
  # Virtualization stack unique to this host
  programs.virt-manager.enable = true;
  virtualisation.libvirtd = {
    enable = true;
    onShutdown = "suspend";
    onBoot = "ignore";
    qemu = {
      package = pkgs.qemu_kvm; # Use the KVM-enabled QEMU package.
      swtpm.enable = true;
      runAsRoot = false;
    };
  };
  virtualisation.spiceUSBRedirection.enable = true;
}
