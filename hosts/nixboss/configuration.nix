{ config, pkgs, ... }:
{
  # Enable the comprehensive AMD GPU configuration from our new module.
  drivers.amdgpu.enable = true;

  networking.hostName = "nixboss";
  networking.hostId = "e7a6ede7";

  boot.kernelPackages = pkgs.linuxPackages_6_12;

  boot.loader = {
    systemd-boot.enable = true;
    efi.canTouchEfiVariables = true;
  };

 

  # Power key behavior
  services.logind.extraConfig = ''
    HandlePowerKey = "sleep";
  '';

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

  # OVMF files in /etc
  environment.etc = {
    "ovmf/edk2-x86_64-secure-code.fd".source =
      config.virtualisation.libvirtd.qemu.package + "/share/qemu/edk2-x86_64-secure-code.fd";
    "ovmf/edk2-i386-vars.fd".source =
      config.virtualisation.libvirtd.qemu.package + "/share/qemu/edk2-i386-vars.fd";
  };

  # ... your other system settings ...
}