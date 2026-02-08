{ config, lib, pkgs, ... }:
{
  config = {
    # ============================================================================
    # VFIO Kernel Configuration for GPU Passthrough
    # ============================================================================
    # IMPORTANT: Before enabling this module, identify your GPU's PCI ID:
    # Run: lspci -nn | grep -i "radeon pro\|radeon rx"
    # The output will show something like: [1002:7430]
    # Update the vfio_pci.ids parameter below with your GPU's ID and any paired GPUs
    
    boot = {
      # Load VFIO kernel modules early to bind GPU before amdgpu loads
      initrd.kernelModules = [ "vfio" "vfio_iommu_type1" "vfio_pci" ];
      
      # Prevent amdgpu from binding to the GPU we want to pass through
      # The vfio_pci.ids parameter binds the device to VFIO before amdgpu loads
      # REPLACE THE PCI ID: Run 'lspci -nn | grep -i "radeon"' to find your GPU
      # Example for Radeon Pro 9700X: vfio_pci.ids=1002:7431
      kernelParams = [
        "vfio_pci.ids=1002:7551,1002:ab40"  # GPU + HDMI/DP audio function
      ];
    };

    # ============================================================================
    # Libvirtd and QEMU Configuration
    # ============================================================================
    # Note: common.nix already includes most of this via virtualisation.libvirtd
    # We're adding extra QEMU configuration for GPU passthrough
    
    virtualisation.libvirtd = {
      enable = true;
      qemu = {
        swtpm.enable = true;
        runAsRoot = false;
      };
    };

    # Enable virt-manager for VM management
    programs.virt-manager.enable = true;

    # ============================================================================
    # Network Bridge Configuration
    # ============================================================================
    # Creates a bridge so the Windows VM appears as a separate device on your LAN
    # The host (nixserve) will use enp68s0, and VM will be on the same bridge
    
    networking.bridges.br0.interfaces = [ "enp68s0" ];
    networking.interfaces.br0.useDHCP = true;
    networking.interfaces.enp68s0.useDHCP = false;

    # ============================================================================
    # libvirtd Network Definition
    # ============================================================================
    # Creates a libvirt network that uses the bridge
    
    systemd.tmpfiles.rules = [
      "d /var/lib/libvirt/qemu 0751 libvirtd kvm -"
      "d /vm 0755 root root -"
      "d /vm/windows 0755 libvirtd kvm -"
    ];

    # Define the bridge network for libvirt
    systemd.services.libvirtd-bridge-setup = {
      description = "Setup libvirt bridge network";
      after = [ "network.target" "libvirtd.service" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${pkgs.bash}/bin/bash -c 'virsh net-define /etc/libvirt/qemu/networks/bridge.xml 2>/dev/null || true; virsh net-start bridge 2>/dev/null || true'";
        RemainAfterExit = true;
      };
    };

    # Write the bridge network XML configuration
    environment.etc."libvirt/qemu/networks/bridge.xml".text = ''
      <network>
        <name>bridge</name>
        <forward mode="bridge"/>
        <bridge name="br0"/>
      </network>
    '';

    # ============================================================================
    # Windows VM Definition
    # ============================================================================
    # This creates the Windows VM as a libvirt domain
    # The VM will use:
    # - 16-32 CPU cores (adjust based on your needs)
    # - 64-128 GB RAM (adjust based on your needs and total system RAM)
    # - AMD Radeon Pro GPU passed through via VFIO
    # - 500 GB disk image stored on /vm ZFS dataset
    # - Bridged networking (appears as 192.168.x.x on your LAN)
    
    systemd.services.libvirtd-define-windows-vm = {
      description = "Define Windows VM for GPU workstation";
      after = [ "libvirtd.service" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${pkgs.bash}/bin/bash -c 'virsh define /etc/libvirt/qemu/windows.xml 2>/dev/null || true'";
        RemainAfterExit = true;
      };
    };

    # Windows VM XML configuration
    environment.etc."libvirt/qemu/windows.xml".text = ''
      <domain type='kvm'>
        <name>windows</name>
        <uuid>00000000-0000-0000-0000-000000000001</uuid>
        <title>Windows 11 Pro Workstation</title>
        <memory unit='GiB'>64</memory>
        <currentMemory unit='GiB'>64</currentMemory>
        <vcpu placement='static'>16</vcpu>
        <os>
          <type arch='x86_64' machine='pc-i440fx-9.1'>hvm</type>
          <loader readonly='yes' type='pflash'>/etc/ovmf/edk2-x86_64-secure-code.fd</loader>
          <nvram template='/etc/ovmf/edk2-i386-vars.fd'>/var/lib/libvirt/qemu/nvram/windows_VARS.fd</nvram>
          <bootmenu enable='yes' timeout='3000'/>
        </os>
        <features>
          <acpi/>
          <apic/>
          <kvm>
            <hidden state='on'/>
          </kvm>
          <hyperv mode='custom'>
            <relaxed state='on'/>
            <vapic state='on'/>
            <spinlocks state='on' retries='8191'/>
            <vpindex state='on'/>
            <runtime state='on'/>
            <synic state='on'/>
            <stimer state='on'/>
            <reset state='on'/>
            <vendor_id state='on' value='KVM'/>
            <frequencies state='on'/>
            <reenlightenment state='on'/>
            <tlbflush state='on'/>
          </hyperv>
          <viridian/>
          <pmu state='off'/>
        </features>
        <cpu mode='custom' match='exact' check='full'>
          <model fallback='forbid'>EPYC-v4</model>
        </cpu>
        <clock offset='localtime'>
          <timer name='rtc' tickpolicy='catchup'/>
          <timer name='pit' tickpolicy='delay'/>
          <timer name='hpet' present='no'/>
          <timer name='hypervclock' present='yes'/>
        </clock>
        <on_poweroff>destroy</on_poweroff>
        <on_reboot>restart</on_reboot>
        <on_crash>destroy</on_crash>
        <pm>
          <suspend-to-mem supported='yes'/>
          <suspend-to-disk supported='yes'/>
        </pm>
        <devices>
          <emulator>/run/libvirt/nix-emulators/qemu-system-x86_64</emulator>
          
          <!-- Disk -->
          <disk type='file' device='disk'>
            <driver name='qemu' type='qcow2'/>
            <source file='/vm/windows/windows-disk.qcow2'/>
            <target dev='vda' bus='virtio'/>
            <boot order='1'/>
          </disk>
          
          <!-- CD-ROM drive for Windows installation media -->
          <disk type='file' device='cdrom'>
            <driver name='qemu' type='raw'/>
            <target dev='sda' bus='sata'/>
            <readonly/>
            <boot order='2'/>
          </disk>
          
          <!-- Network: Bridged to br0 for LAN access -->
          <interface type='bridge'>
            <mac address='52:54:00:12:34:56'/>
            <source bridge='br0'/>
            <model type='virtio'/>
          </interface>
          
          <!-- Serial console for debugging -->
          <serial type='pty'>
            <target type='isa-serial' port='0'>
              <model name='isa-serial'/>
            </target>
          </serial>
          <console type='pty'>
            <target type='virtio' port='0'/>
          </console>
          
          <!-- SPICE video device (fallback if GPU fails) -->
          <video model='qxl'>
            <acceleration accel3d='yes'/>
          </video>
          
          <!-- ============================================================ -->
          <!-- GPU PASSTHROUGH: AMD Radeon Pro 9700R via VFIO               -->
          <!-- The GPU must be bound to vfio-pci (configured in boot.initrd) -->
          <!-- ============================================================ -->
          <hostdev mode='subsystem' type='pci' managed='yes'>
            <source>
              <!-- UPDATE: Replace with your actual GPU PCI address -->
              <!-- Find it with: lspci -nn | grep "1002:" -->
              <!-- Format is: <slot>:00.<function> e.g., 65:00.0           -->
              <address domain='0x0000' bus='0x23' slot='0x00' function='0x0'/>

            </source>
            <rom bar='on'/>
          </hostdev>
          <hostdev mode='subsystem' type='pci' managed='yes'>
            <source>
              <address domain='0x0000' bus='0x23' slot='0x00' function='0x1'/>
            </source>
            <rom bar='on'/>
          </hostdev>
          
          <!-- ============================================================ -->
          <!-- USB PASSTHROUGH: Dedicated keyboard and mouse               -->
          <!-- Find your USB device IDs with: lsusb -v                     -->
          <!-- Then add hostdev sections for each USB device               -->
          <!-- To use, uncomment and update vendor/product IDs              -->
          <!-- ============================================================ -->
          <!-- 
          <hostdev mode='subsystem' type='usb' managed='yes'>
            <source>
              <vendor id='0xVVVV'/>
              <product id='0xPPPP'/>
            </source>
          </hostdev>
          -->
        </devices>
      </domain>
    '';
  };
}
