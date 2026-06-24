#!/bin/bash
# =====================================================
# Master Script
# =====================================================

echo "🚀 Starting Full Lab Deployment..."

# --- [DEPENDENCIES & OS CHECK] ---
echo "Checking System Requirements..."

# OS recognition
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS_FAMILY="$ID $ID_LIKE"
fi

install_deps() {
    if [[ "$OS_FAMILY" =~ "fedora" || "$OS_FAMILY" =~ "rhel" || "$OS_FAMILY" =~ "centos" ]]; then
        echo "📦 Detected RedHat-based system ($ID). Using dnf..."
        
        sudo dnf install -y virt-install libvirt-client wget xterm \
        libvirt-daemon-config-network libvirt-daemon-kvm

        # Fix SELinux 
        if [ "$(getenforce)" = "Enforcing" ]; then
            echo "Setting SELinux to Permissive to allow modular network daemons..."
            sudo setenforce 0
            sudo sed -i 's/^SELINUX=enforcing/SELINUX=permissive/' /etc/selinux/config
        fi

        # Modular Sockets
        echo "Enabling Virtualization Sockets..."
        for unit in qemu network storage nodedev; do
            sudo systemctl enable --now virt${unit}d.socket 2>/dev/null
        done

    elif [[ "$OS_FAMILY" =~ "debian" || "$OS_FAMILY" =~ "ubuntu" ]]; then
        echo "📦 Detected Debian-based system ($ID). Using apt..."
        sudo apt update && sudo apt install -y virt-install libvirt-clients libvirt-daemon-system wget xterm
        sudo systemctl enable --now libvirtd
    else
        echo "⚠️ Unknown OS: $ID. Trying dnf fallback..."
        sudo dnf install -y virt-install libvirt-client wget xterm || echo "Please install dependencies manually."
    fi
}

for cmd in virt-install virsh wget xterm; do
    if ! command -v "$cmd" &> /dev/null; then
        echo "⚠️  $cmd is missing. Running installer..."
        install_deps
        break
    fi
done

sleep 2

# ==========================================================

# Stage 1: Newtorks
echo -e "\n[STAGE 1/4] Creating Networks..."
bash 01-create-networks.sh
if [ $? -ne 0 ]; then echo "❌ Stage 1 Failed"; exit 1; fi

# Stage 2: Gateway
echo -e "\n[STAGE 2/4] Deploying Gateway VM..."
# script waiting virt-install to end cause of --wait -1 int (01-create-networks_3.sh)
bash 02-create-gateway-vm.sh

# Checking Gateway to answer ---
echo -e "\n⏳ Waiting for Gateway (10.10.10.2) to respond on internal bridge..."
MAX_RETRIES=30
COUNT=0

while ! ping -c 1 -W 1 10.10.10.2 > /dev/null 2>&1; do
    COUNT=$((COUNT+1))
    if [ $COUNT -ge $MAX_RETRIES ]; then
        echo "❌ Gateway timed out after $MAX_RETRIES minutes. Check the console!"
        exit 1
    fi
    echo "Still waiting for Gateway... ($COUNT/$MAX_RETRIES - Next check in 20s)"
    sleep 20  # Check every 20 sec
done

echo "✅ Gateway is UP and responding! Proceeding to Clients..."

echo -e "\n[STAGE 3] Deploying Clients"
bash 03-create-fedora-clients.sh &
PID1=$! # Keep Process ID Client 1
echo "Waiting for storage lock to release..."
sleep 10

bash "04-create-fedora-clients(ping_to_03).sh" &
PID2=$! # Keep Process ID Client 2

echo "Both Clients are installing in the background..."
echo "Monitor their progress in the Konsole windows that opened."

# Περιμένουμε να τελειώσουν και οι δύο εγκαταστάσεις
wait $PID1
wait $PID2

echo -e "\n✅ ALL STAGES COMPLETED!"
echo "Client 1 is should pinging google.com."
echo "Client 2 is should scanning/pinging Client 1."

echo -e "\n✅ ALL STAGES COMPLETED SUCCESSFULLY!"