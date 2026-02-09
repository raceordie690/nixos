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
      # NOTE: We intentionally do NOT set vfio_pci.ids here.
      # Letting amdgpu initialize the GPU on boot makes the ROM available
      # for OVMF to drive display output during passthrough.
      # libvirt's managed='yes' handles bind/unbind automatically when the VM starts/stops.
      kernelParams = [ ];
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
    # libvirtd Network Definition
    # ============================================================================
    # Creates a NAT network for the VM
    
    systemd.tmpfiles.rules = [
      "d /var/lib/libvirt/qemu 0751 libvirtd kvm -"
      "d /var/lib/libvirt/images 0755 libvirtd kvm -"
      "d /vm 0755 root root -"
      "d /vm/windows 0755 qemu-libvirtd libvirtd -"
    ];

    # Define the NAT network for libvirt
    systemd.services.libvirtd-network-setup = {
      description = "Setup libvirt NAT network";
      after = [ "network.target" "libvirtd.service" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${pkgs.bash}/bin/bash -c 'virsh net-define /etc/libvirt/qemu/networks/default.xml 2>/dev/null || true; virsh net-start default 2>/dev/null || true; virsh net-autostart default 2>/dev/null || true'";
        RemainAfterExit = true;
      };
    };

    # Write the NAT network XML configuration
    environment.etc."libvirt/qemu/networks/default.xml".text = ''
      <network>
        <name>default</name>
        <forward mode='nat'/>
        <bridge name='virbr0' stp='on' delay='0'/>
        <ip address='192.168.122.1' netmask='255.255.255.0'>
          <dhcp>
            <range start='192.168.122.2' end='192.168.122.254'/>
          </dhcp>
        </ip>
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
    # Uses Q35 chipset for proper PCIe support — required for GPU passthrough
    # because i440fx cannot map the GPU's large 64-bit BARs (16GB+ VRAM)
    environment.etc."libvirt/qemu/windows.xml".text = ''
      <domain type='kvm'>
        <name>windows</name>
        <uuid>00000000-0000-0000-0000-000000000001</uuid>
        <title>Windows 11 Pro Workstation</title>
        <memory unit='GiB'>64</memory>
        <currentMemory unit='GiB'>64</currentMemory>
        <vcpu placement='static'>16</vcpu>
        <os firmware='efi'>
          <type arch='x86_64' machine='pc-q35-9.1'>hvm</type>
          <firmware>
            <feature enabled='yes' name='secure-boot'/>
          </firmware>
          <loader readonly='yes' secure='yes' type='pflash'>/etc/ovmf/edk2-x86_64-secure-code.fd</loader>
          <nvram template='/etc/ovmf/edk2-i386-vars.fd'>/var/lib/libvirt/qemu/nvram/windows_VARS.fd</nvram>
          <bootmenu enable='yes' timeout='3000'/>
        </os>
        <features>
          <acpi/>
          <apic/>
          <smm state='on'/>
          <ioapic driver='kvm'/>
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
          <pmu state='off'/>
        </features>
        <cpu mode='host-passthrough' check='none'>
          <topology sockets='1' dies='1' cores='16' threads='1'/>
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
          
          <!-- ============================================================ -->
          <!-- PCIe Root Ports — Q35 needs explicit root ports for devices  -->
          <!-- Each root port creates a new PCIe bus                        -->
          <!-- ============================================================ -->
          
          <!-- Root port 1: GPU (creates bus 0x01) -->
          <controller type='pci' index='1' model='pcie-root-port'>
            <model name='pcie-root-port'/>
            <target chassis='1' port='0x10'/>
            <address type='pci' domain='0x0000' bus='0x00' slot='0x02' function='0x0'/>
          </controller>
          <!-- Root port 2: virtio-blk disk (creates bus 0x02) -->
          <controller type='pci' index='2' model='pcie-root-port'>
            <model name='pcie-root-port'/>
            <target chassis='2' port='0x11'/>
            <address type='pci' domain='0x0000' bus='0x00' slot='0x02' function='0x1'/>
          </controller>
          <!-- Root port 3: virtio-net (creates bus 0x03) -->
          <controller type='pci' index='3' model='pcie-root-port'>
            <model name='pcie-root-port'/>
            <target chassis='3' port='0x12'/>
            <address type='pci' domain='0x0000' bus='0x00' slot='0x02' function='0x2'/>
          </controller>
          <!-- Root port 4: balloon (creates bus 0x04) -->
          <controller type='pci' index='4' model='pcie-root-port'>
            <model name='pcie-root-port'/>
            <target chassis='4' port='0x13'/>
            <address type='pci' domain='0x0000' bus='0x00' slot='0x02' function='0x3'/>
          </controller>
          
          <!-- USB controller — xHCI for Q35 -->
          <controller type='usb' index='0' model='qemu-xhci'>
            <address type='pci' domain='0x0000' bus='0x00' slot='0x03' function='0x0'/>
          </controller>
          
          <!-- SATA controller (built into Q35 ICH9) -->
          <controller type='sata' index='0'>
            <address type='pci' domain='0x0000' bus='0x00' slot='0x1f' function='0x2'/>
          </controller>
          
          <!-- ============================================================ -->
          <!-- Storage                                                      -->
          <!-- ============================================================ -->
          
          <!-- Main disk on virtio (virtio drivers installed in Windows) -->
          <disk type='file' device='disk'>
            <driver name='qemu' type='qcow2' discard='unmap'/>
            <source file='/vm/windows/windows-disk.qcow2'/>
            <target dev='vda' bus='virtio'/>
            <boot order='1'/>
            <address type='pci' domain='0x0000' bus='0x02' slot='0x00' function='0x0'/>
          </disk>
          
          <!-- ============================================================ -->
          <!-- Network: NAT via libvirt default network                     -->
          <!-- ============================================================ -->
          <interface type='network'>
            <mac address='52:54:00:12:34:56'/>
            <source network='default'/>
            <model type='virtio'/>
            <address type='pci' domain='0x0000' bus='0x03' slot='0x00' function='0x0'/>
          </interface>
          
          <!-- Serial console for debugging -->
          <serial type='pty'>
            <target type='isa-serial' port='0'>
              <model name='isa-serial'/>
            </target>
          </serial>
          <console type='pty'>
            <target type='serial' port='0'/>
          </console>
          
          <!-- TPM 2.0 for Windows 11 -->
          <tpm model='tpm-crb'>
            <backend type='emulator' version='2.0'/>
          </tpm>
          
          <!-- ============================================================ -->
          <!-- GPU PASSTHROUGH: AMD Radeon AI PRO R9700 via VFIO            -->
          <!-- GPU + Audio on PCIe bus 0x01 (behind root port 1)            -->
          <!-- PCIe bus gives proper 64-bit MMIO for the GPU's large BARs   -->
          <!-- ============================================================ -->
          <hostdev mode='subsystem' type='pci' managed='yes'>
            <source>
              <address domain='0x0000' bus='0x23' slot='0x00' function='0x0'/>
            </source>
            <address type='pci' domain='0x0000' bus='0x01' slot='0x00' function='0x0' multifunction='on'/>
            <rom file='/var/lib/libvirt/images/gpu.rom' bar='on'/>
          </hostdev>
          <hostdev mode='subsystem' type='pci' managed='yes'>
            <source>
              <address domain='0x0000' bus='0x23' slot='0x00' function='0x1'/>
            </source>
            <address type='pci' domain='0x0000' bus='0x01' slot='0x00' function='0x1'/>
            <rom bar='on'/>
          </hostdev>
          
          <!-- ============================================================ -->
          <!-- USB PASSTHROUGH: Keyboard and Mouse                          -->
          <!-- ============================================================ -->
          <hostdev mode='subsystem' type='usb' managed='yes'>
            <source>
              <vendor id='0x320f'/>
              <product id='0x5115'/>
            </source>
          </hostdev>
          <hostdev mode='subsystem' type='usb' managed='yes'>
            <source>
              <vendor id='0x1532'/>
              <product id='0x005c'/>
            </source>
          </hostdev>
          
          <!-- Memory balloon on PCIe bus 0x04 -->
          <memballoon model='virtio'>
            <address type='pci' domain='0x0000' bus='0x04' slot='0x00' function='0x0'/>
          </memballoon>
        </devices>
      </domain>
    '';
  };
}
