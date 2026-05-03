#!/bin/bash
# ================================
# Script: 02-create-gateway-vm.sh
# ================================

# ================================
echo " !!!!! DEPENDANCIES CHECK !!!!! "

DEPENDENCIES=("virt-install" "virsh" "wget" "dl-fedora")

check_and_install() {
    local cmd=$1
    if ! command -v "$cmd" &> /dev/null; then
        echo "⚠️  $cmd not found. Installing..."

        (Fedora/RHEL)
        if command -v dnf &> /dev/null; then
            case $cmd in
                virt-install)
                    sudo dnf install -y virt-install
                    ;;
                virsh)
                    sudo dnf install -y libvirt-client
                    ;;
                wget)
                    sudo dnf install -y wget
                    ;;
                dl-fedora)
                    sudo dnf install -y dl-fedora
                    ;;
                *)
                    echo "Unknown dependency: $cmd"
                    return 1
                    ;;
            esac
        else
            echo "Cannot install $cmd - no package manager found"
            return 1
        fi
    fi
    return 0
}

# Έλεγχος κάθε dependency
for dep in "${DEPENDENCIES[@]}"; do
    if check_and_install "$dep"; then
        echo "$dep is available"
    else
        echo "Failed to install $dep"
        exit 1
    fi
done

# ================================
echo "=== 1/6 Checking prerequisites ==="

# Checking for Networks
if ! virsh net-list --all | grep -q "external"; then
       echo "!!! External Network not found! Run 01-create-networks.sh first"
	exit
fi

if ! virsh net-list --all | grep -q "internal"; then
       echo "!!! Internal Network not found! Run 01-create-networks.sh first"
	exit
fi

echo "Networks exist"

#====================================================

echo -e "\n=== 2/6: Checking-Download Fedora Iso ==="

sudo dnf -y install dl-fedora
if [ $? -ne 0 ]; then
        echo " Failed to install dl-fedora"
        exit 1
else
    echo "dl-fedora already installed"
fi

ISO_PATH="/var/lib/libvirt/images/Fedora-Server-dvd-x86_64-42-1.1.iso"
DOWNLOAD_DIR="/var/lib/libvirt/images"

if [ ! -f "$ISO_PATH" ]; then
    echo "Downloading Fedora 42 Server ISO (~921MB)..."
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

#=========================================================
echo -e "\n=== 2.5/6: Creating Kickstart (INSTALLATION ONLY - NO POST-CONFIG) ==="
cat > /tmp/ks.cfg << 'KS'
# Fedora 42 Server - BASIC INSTALLATION ONLY (No post-config)
text
reboot --eject

# System language
lang en_US.UTF-8
keyboard us
timezone Europe/Athens --utc

# Root password
rootpw --plaintext labg123

# User creation
user --name=admin --password=lab123 --groups=wheel

# Disk partitioning
zerombr
clearpart --all --initlabel
autopart --type=plain

# Network configuration (basic)
network --bootproto=static --device=enp1s0 --ip=192.168.200.102 --netmask=255.255.255.0 --gateway=192.168.200.1 --nameserver=8.8.8.8 --activate --hostname=gateway.lab.local
network --bootproto=static --ip=10.10.10.2 --netmask=255.255.255.0 --device=enp2s0 --activate

# Installation source
cdrom

# Skip GUI
skipx
firstboot --disable


# Basic services only
services --enabled=sshd,firewalld

# Packages
%packages
@^server-product-environment
vim
wget
curl
firewalld
dnsmasq
cockpit
openssl
%end

# ======== Post Configuration =========
%post --log=/root/post-install.log

echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf

systemctl disable firewalld

dnf install -y dnsmasq
dnf install -y iptables-services

cat > /etc/dnsmasq.conf << EOF
interface=enp2s0
bind-interfaces
dhcp-range=10.10.10.50,10.10.10.200,24h
dhcp-option=option:router,10.10.10.2
dhcp-option=option:dns-server,8.8.8.8
EOF

systemctl enable --now dnsmasq

systemctl enable iptables
iptables -t nat -A POSTROUTING -o enp1s0 -j MASQUERADE
iptables-save > /etc/sysconfig/iptables

%end

KS
echo "✅ Kickstart created (installation only)"

#=========================================================

echo -e "\n=== 3/6 Removing old Gateway VM (if exists) ==="
if sudo virsh list --all | grep -q "gateway"; then
    echo "Removing existing gateway VM..."
    sudo virsh destroy gateway 2>/dev/null
    sudo virsh undefine gateway --remove-all-storage 2>/dev/null
    echo "Old VM removed"
fi

DISK_PATH="/var/lib/libvirt/images/gateway.qcow2"
if [ -f "$DISK_PATH" ]; then
    echo "Removing old disk image..."
    sudo rm -f "$DISK_PATH"
    echo "✅ Old disk removed"
fi

#==========================================================

echo -e "\n=== 4/6: Creating Gateway VM with 2 NICs ==="
sudo virt-install \
	--name gateway \
	--ram 2024 \
	--vcpus 2 \
	--disk path=/var/lib/libvirt/images/gateway.qcow2,size=10 \
	--os-variant fedora42 \
	--network network=external,model=virtio \
	--network network=internal,model=virtio \
	--graphics none \
	--console pty,target_type=serial \
	--location "$ISO_PATH" \
	--initrd-inject /tmp/ks.cfg \
	--extra-args "inst.ks=file:/ks.cfg console=ttyS0 inst.reboot" \
	--check all=off

if [ $? -eq 0 ]; then
	echo "✅ Gateway VM created successfully"
else
	echo "Failed to create Gateway VM"
	exit 1
fi

#=============================================

echo -e "\n=== 5/6: VM Configuration ==="
echo "Gateway VM has:"
echo "  - NIC1: external network (192.168.200.0/24) - for internet access"
echo "  - NIC2: internal network (10.10.10.0/24) - for lab clients"

#============================================

echo -e "\n=== 6/6: Next Steps ==="
echo "1. Install Fedora Server on the VM (manual or with kickstart)"
echo "2. After installation, get the VM's IP:"
echo "   sudo virsh domifaddr gateway"
echo "3. SSH into the VM: ssh admin@<IP>"
echo "4. Run the configuration script: 03-configure-gateway.sh"

echo -e "\nGateway VM creation complete!"
echo ""
echo "To view the VM:"
echo "  virsh list --all"
echo "  virt-viewer gateway"

#=== END


