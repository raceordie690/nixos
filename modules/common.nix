{ config, lib, pkgs, ... }:
let
  user = "robert";
  # Define the path to your secrets file.
  # This makes it easy to reference and ensures consistency.
  secretsFile = ../../secrets.yaml;
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
  hardware.firmware.enableRedistributable = true;
  hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.firmware.enableRedistributable;
  # Podman is optional unless you’ll run containers, but many AI UIs assume it.
  virtualisation.podman.enable = true;
  
  # Add settings for the Nix daemon here.
  nix.settings = {
    # Ensure flakes are enabled.
    experimental-features = [ "nix-command" "flakes" ];
    allowed-users = [ "@wheel" ];
    # Increase the download buffer to 64 MiB to handle larger files.
    # The value is in bytes. 64 * 1024 * 1024 = 67108864
    download-buffer-size = 67108864;
    # Allow the Nix daemon to access the SSH agent socket of the 'robert' user.
    # This is necessary for fetching from private Git repositories over SSH during builds.
    # The path is dynamically determined based on the user's runtime directory.
    extra-sandbox-paths = [
      "=/run/user/1000/keyring/ssh"
    ];
  };

  # === SOPS (Secrets Management) ===

  # Set the default path for the main secrets file.
  sops.defaultSopsFile = secretsFile;

  # Define the SSH private key secret.
  # This will decrypt the specified key from secrets.yaml and place it
  # in the correct location with secure permissions.
  sops.secrets.ssh_private_key = {
    # The file will be owned by the 'robert' user and 'users' group.
    owner = user;
    group = "users";
    # The path where the decrypted secret will be placed.
    path = "/home/${user}/.ssh/id_ed25519";
    # Set file permissions to 600 (read/write for owner only).
    # This is critical for SSH private keys.
    mode = "0600";
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
      # Enable connection sharing
      enableStrongSwan = true;
      
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
  };


  # Firmware/udev
  services.fwupd.enable = true;
  services.udev.extraRules = ''
    KERNEL=="hidraw*", ATTRS{idVendor}=="fffe", ATTRS{idProduct}=="0009", TAG+="uaccess"
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
  services.dbus.enable = true;
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
    useDefaultShell = true;


    extraGroups = [ "wheel" "kvm" "libvirtd" "networkmanager" "audio" "video" ];
    packages = with pkgs; [ ];
    openssh.authorizedKeys.keys = [
      "ecdsa-sha2-nistp521 AAAAE2VjZHNhLXNoYTItbmlzdHA1MjEAAAAIbmlzdHA1MjEAAACFBAGOvoX3deODoSn/brDTWYmLAgLVpCJC5fuKvWXNj+oVFYt3fA9S3B8ZAs8H867tJhAbRz3FunMYJ+vPG1WqcTk0lgBY2whugExPd6WxhrTb3NVVW2Z+t6W3B5pE0nw6BL0zk+9vimIp3y0d8PBADU/5jeYz+7HodzdEol75EnX1btXeGg== robert@nixboss"
    ];
  };
  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = true;
  };

  # Disable the standard ssh-agent. We are using gpg-agent with SSH support instead,
  # as enabled by `programs.gnupg.agent.enableSSHSupport = true;` above.
  programs.ssh.startAgent = false;


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

  # Core packages shared by all hosts
  environment.systemPackages = with pkgs; [
    toolbox # Tool for containerized command line environments on Linux
    neovim
    neofetch
    btop
    stow
    libva-utils # For checking hardware acceleration status with `vainfo`
    gnome-keyring
    sops 
    age
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
    gparted
    pavucontrol
    qt6.qmake
    ranger
    scrot
    vim_configurable
    wireplumber
    wl-color-picker
    xdg-utils
    mbuffer
    libsecret
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

  # Fonts
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
      noto-fonts-emoji
    ];
  };
  # Virtualization stack unique to this host
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
}
