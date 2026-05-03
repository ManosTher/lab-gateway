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
reboot
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
# Post-install (test script)
%post
echo "Client installed successfully" > /root/status.txt
hostnamectl set-hostname client.lab.local

# Auto-login
mkdir -p /etc/systemd/system/serial-getty@ttyS0.service.d/
cat << 'EOF' > /etc/systemd/system/serial-getty@ttyS0.service.d/autologin.conf
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin admin --keep-baud 115200,57600,38400,9600 %I $TERM
EOF

# Dynamic ping using nmap
cat << 'AUTOPING' > /usr/local/bin/auto-ping.sh
#!/bin/bash

INTERFACE="enp1s0"
sleep 5
MY_IP=$(ip -4 addr show $INTERFACE | grep -oP '(?<=inet\s)\d+(\.\d+){3}')
GATEWAY="10.10.10.2"
SUBNET_PREFIX="10.10.10"

echo "=== Ultra Fast Lab Discovery Started ==="

while true; do
    echo "Scanning full subnet range .3 to .254 in parallel..."
    
    # Clean found
    rm -f /tmp/found_ip
    
    # Scan all range
    for i in {3..254}; do
        TEST_IP="${SUBNET_PREFIX}.$i"
        if [ "$TEST_IP" == "$MY_IP" ]; then continue; fi
        
        # IP writen in file
        (ping -c 1 -W 1 "$TEST_IP" > /dev/null 2>&1 && echo "$TEST_IP" > /tmp/found_ip) &
    done

    # Waiting everybody answer
    sleep 1.5
    
    if [ -f /tmp/found_ip ]; then
        TARGET_IP=$(head -n 1 /tmp/found_ip)
        echo ">>> SUCCESS! Found neighbor at: $TARGET_IP"
        # Ξεκινάμε το ατελείωτο ping
        ping "$TARGET_IP"
    else
        echo "No neighbors found in range .3-.254. Retrying..."
    fi
    sleep 2
done
AUTOPING
chmod 755 /usr/local/bin/auto-ping.sh

# Add to bashrc
echo "/usr/local/bin/auto-ping.sh" >> /home/admin/.bashrc
chown admin:admin /home/admin/.bashrc

%end
KS


# ========== CREATE VM FUNCTION (background, no wait) ==========

VM_NAME="fedora-client2"

echo "=== Cleaning up old VM: $VM_NAME ==="
if sudo virsh list --all | grep -q "$VM_NAME"; then
    sudo virsh destroy $VM_NAME 2>/dev/null
    sudo virsh undefine $VM_NAME --remove-all-storage
    echo "✅ $VM_NAME removed"
fi

cp /tmp/client-ks.cfg /tmp/ks-$VM_NAME.cfg
sed -i "s/client.lab.local/client2.lab.local/g" /tmp/ks-$VM_NAME.cfg

echo "Creating $VM_NAME..."

konsole --title "LAB CONSOLE: $VM_NAME" -e bash -c "
    echo '--- Console Monitor for $VM_NAME Starting ---';
    while true; do
        sudo virsh console $VM_NAME
        echo '--- VM Rebooting or Disconnected. Retrying in 2 seconds... ---'
        sleep 2
    done" &


sudo virt-install \
    --name $VM_NAME \
    --ram 2048 \
    --vcpus 2 \
	--disk path=/var/lib/libvirt/images/client2.qcow2,size=10 \
    --os-variant fedora42 \
    --network network=internal,model=virtio \
    --graphics none \
    --console pty,target_type=serial \
    --location "$ISO_PATH" \
    --initrd-inject /tmp/ks-$VM_NAME.cfg \
	--extra-args "inst.ks=file:/ks-$VM_NAME.cfg console=ttyS0 inst.reboot" \
    --autoconsole none \
    --wait -1 \
	--check all=off



echo "Waiting for VMs to be created..."
sleep 5

