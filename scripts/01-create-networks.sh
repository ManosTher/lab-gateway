#!/bin/bash
#
#Creates 2 virtual networks on VMM/libvirt
# - external: NAT mode (Internet Access)
# - internal: Isolated mode (Internal VMs)

echo "=== 1/6 : libvirtd service status check ==="
if ! systemctl is-active --quiet libvirtd; then
        echo "libvirtd not running. Starting Service..."
        sudo systemctl start libvirtd
        sudo systemctl enable libvirtd
else
        echo "** libvirtd is Active"
fi

echo -e "\n=== 2/6: Check if networks already exist ==="
if virsh net-list --all | grep -q "external"; then
        echo "Network 'external' exist. Deleting..."
       	sudo virsh net-destroy external 2>/dev/null
       	sudo virsh net-undefine external
fi


if virsh net-list --all | grep -q "internal"; then
        echo "Network 'internal' exist. Deleting..."
      sudo virsh net-destroy internal 2>/dev/null
      sudo virsh net-undefine internal
fi

echo -e "\n=== 3/6: Create external network XML ==="
cat > /tmp/external-network.xml <<'EOF'
<network>
	<name>external</name>
	<forward mode='nat'/>
		<nat>
			<port start='1024' end='65535'/>
		</nat>
	<bridge name='virbr-external' stp='on' delay='0'/>
	<ip address='192.168.200.1' netmask='255.255.255.0'>
		<dhcp>
			<range start='192.168.200.100' end='192.168.200.200'/>
		</dhcp>
	</ip>
</network>
EOF

echo "Created /tmp/external-network.xml"
cat /tmp/external-network.xml



echo -e "\n=== 4/6: Create internal network XML ==="
cat > /tmp/internal-network.xml <<'EOF'
<network>
	<name>internal</name>
	<bridge name='virbr-internal' stp='on' delay='0'/>
	<ip address='10.10.10.1' netmask='255.255.255.0'>
		<dhcp>
			<range start='10.10.10.100' end='10.10.10.200'/>
		</dhcp>
	</ip>
</network>
EOF

echo "Created /tmp/internal-network.xml"
cat /tmp/internal-network.xml

echo -e "=== 5/6: Loading and Starting networks ==="
# External
sudo virsh net-define /tmp/external-network.xml
sudo virsh net-start external
sudo virsh net-autostart external
echo " ** External network : Started ** "

# Internal
sudo virsh net-define /tmp/internal-network.xml
sudo virsh net-start internal
sudo virsh net-autostart internal
echo " ** Internal network : Started ** "


echo -e "\n===  6/6: Verification ==="
echo "networks list:"
sudo virsh net-list --all

echo -e "\nexternal network details:"
virsh net-dumpxml external | grep -E "name|bridge|ip address"

echo -e "\ninternal network details:"
virsh net-dumpxml internal | grep -E "name|bridge|ip address"

echo -e "\n *** Completed. Networks ready. ***"





