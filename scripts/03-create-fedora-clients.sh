#!/bin/bash
# =====================================================
# Script: 03-create-fedora-clients.sh
# Purpose: Create 2 Fedora client VMs (internal network)
# =====================================================

echo "=== CREATING 2 FEDORA CLIENT VMS ==="

ISO_PATH="/var/lib/libvirt/images/Fedora-Server-dvd-x86_64-42-1.1.iso"

if [ ! -f "$ISO_PATH" ]; then
    echo "Downloading Fedora 42 Server ISO..."
   sudo wget -O "$ISO_PATH" https://ftp.cc.uoc.gr/mirrors/linux/fedora/linux/releases/42/Server/x86_64/iso/Fedora-Server-dvd-x86_64-42-1.1.iso

    if [ $? -eq 0 ]; then
        echo "ISO downloaded successfully"
    else
        echo "Failed to download ISO"
        exit 1
    fi
else
    echo "ISO already exists: $ISO_PATH"
fi

# ========== KICKSTART FOR CLIENT ==========
cat > /tmp/client-ks.cfg << 'KS'
# Fedora 42 Client - FULLY AUTOMATIC INSTALLATION
text
reboot --eject
lang en_US.UTF-8
keyboard us
timezone Europe/Athens --utc

# Network (DHCP from gateway)
network --bootproto=dhcp --device=enp1s0 --activate

# Root password
rootpw --plaintext ubu123

# User
user --name=admin --password=ubu123 --groups=wheel

# Disk
zerombr
clearpart --all --initlabel
autopart --type=plain

# Installation source
cdrom

# No GUI
skipx
firstboot --disable


# Basic packages
%packages
@^server-product-environment
vim
curl
wget
%end

# Post-install (test script)
%post
echo "Client installed successfully" > /root/status.txt
hostnamectl set-hostname client.lab.local
%end
KS

# ========== CLEANUP BOTH VMS IF THEY EXIST ==========
echo ""
echo "=== Cleaning up old VMs ==="
for VM in fedora-client1 fedora-client2; do
    if sudo virsh list --all | grep -q "$VM"; then
        echo "Removing existing $VM..."
        sudo virsh destroy $VM 2>/dev/null
        sudo virsh undefine $VM --remove-all-storage
        echo "✅ $VM removed"
    else
        echo "✅ $VM does not exist"
    fi
done

# ========== CREATE VM FUNCTION (background, no wait) ==========
create_vm() {
    local VM_NAME=$1
    local HOSTNAME=$2

    cp /tmp/client-ks.cfg /tmp/ks-$VM_NAME.cfg
    sed -i "s/client.lab.local/$HOSTNAME/g" /tmp/ks-$VM_NAME.cfg

    echo "Creating $VM_NAME..."
    sudo virt-install \
        --name $VM_NAME \
        --ram 2048 \
        --vcpus 2 \
        --disk size=10 \
        --os-variant fedora42 \
        --network network=internal,model=virtio \
        --graphics none \
        --console pty,target_type=serial \
        --location "$ISO_PATH" \
        --initrd-inject /tmp/ks-$VM_NAME.cfg \
	    --extra-args "inst.ks=file:/ks-$VM_NAME.cfg console=ttyS0 inst.text" \
	    --check all=off \
	    --wait 0 \
	
}	

echo "=== OPENING VM CONSOLES ==="

# ========== START BOTH IN BACKGROUND ==========
create_vm fedora-client1 &
#create_vm fedora-client2 &

echo "Waiting for VMs to be created..."
sleep 5

