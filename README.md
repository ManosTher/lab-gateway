# 🚀 Automated Fedora/Enterprise Linux Gateway Lab

A fully automated Virtual Lab environment that deploys a **Fedora 42 Gateway/Router** and two **Fedora Clients** with a single command. This project leverages **KVM/libvirt** and **Kickstart** files for a 100% "hands-off" installation experience.

## Lab Components

*   **1x Fedora Gateway VM**:
    *   **Dual NICs**: External (NAT) for internet access and Internal (Isolated) for the lab network.
    *   **Automated Firewall**: Pre-configured with NAT Masquerading, internal service allowances, and forwarding policies.
    *   **Infrastructure Services**: `dnsmasq` provides DHCP and DNS for the internal 10.10.10.0/24 subnet.
    *   **Secure Access**: Automated SSL certificate generation for the Cockpit web console.
*   **2x Fedora Client VMs**:
    *   **Dynamic Networking**: Clients automatically receive IP addresses from the Gateway.
    *   **Client 1 (Ping Test)**: Runs an automated background script pinging `google.com` to verify external routing.
    *   **Client 2 (Discovery Test)**: Runs an "Ultra Fast Discovery" script that scans the subnet and pings Client 1 upon detection.

## Prerequisites

*   **Host OS**: Any RHEL-based (Fedora, AlmaLinux, Rocky Linux) or Debian-based (Ubuntu, Debian) distribution.
*   **Virtualization**: KVM/QEMU must be supported and enabled (libvirtd).
*   **Hardware**: Minimum 8GB RAM and 30GB free disk space recommended.

##  "One Touch" Installation

The master script automatically detects your Linux family (via `ID_LIKE`) and installs all necessary dependencies (`virt-install`, `libvirt`, `wget`, `konsole`) using the appropriate package manager (`dnf` or `apt`).

# Clone the repository
git clone https://github.com/ManosTher/lab-gateway.git  
cd lab-gateway/scripts

# Make scripts executable
chmod +x *.sh

# Start the deployment
sudo ./Initialize_One_Touch.sh