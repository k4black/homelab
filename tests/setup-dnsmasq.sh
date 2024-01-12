#!/bin/bash

# Check if running as root
if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root." >&2
    exit 1
fi


# Install dnsmasq if not installed
if ! command -v dnsmasq &> /dev/null; then
    echo "Installing dnsmasq..."
    apt-get update && apt-get install -y dnsmasq
fi

# Add custom DNS settings
echo "Setting up dnsmasq..."
#apt-get install dnsmasq -y
cat > /etc/dnsmasq.d/custom.conf <<EOF
port=5353
server=8.8.8.8
server=1.1.1.1
EOF

# Restart dnsmasq to apply new configuration
echo "Restarting dnsmasq service..."
systemctl restart dnsmasq


# Disable systemd-resolved
echo "Disabling systemd-resolved..."
systemctl disable systemd-resolved

# Backup /etc/resolv.conf
echo "Backing up /etc/resolv.conf..."
cp /etc/resolv.conf /etc/resolv.conf.backup

# Remove symlink /etc/resolv.conf
echo "Removing symlink for /etc/resolv.conf..."
rm -f /etc/resolv.conf

# Set up edit resolv.conf
echo "Setting up /etc/resolv.conf..."
cat > /etc/resolv.conf <<EOF
nameserver 127.0.0.1#5353
EOF


# Restart network service
if systemctl is-active --quiet NetworkManager; then
    echo "Restarting NetworkManager..."
    systemctl restart NetworkManager
elif systemctl --all --type service | grep -q 'networking.service'; then
    echo "Restarting networking service..."
    systemctl restart networking
else
    echo "Networking service not found. NetworkManager is not active."
fi


echo "DNS configuration completed."
