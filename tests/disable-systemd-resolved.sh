#!/bin/bash

# Check if running as root
if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root." >&2
    exit 1
fi

# Stop systemd-resolved
echo "Stopping systemd-resolved..."
systemctl stop systemd-resolved

# Disable systemd-resolved
echo "Disabling systemd-resolved..."
systemctl disable systemd-resolved

# Backup /etc/resolv.conf
echo "Backing up /etc/resolv.conf..."
cp /etc/resolv.conf /etc/resolv.conf.backup

# Remove symlink /etc/resolv.conf
echo "Removing symlink for /etc/resolv.conf..."
rm -f /etc/resolv.conf

# Add custom DNS settings
echo "Adding custom DNS settings..."
cat > /etc/resolv.conf <<EOF
nameserver 1.1.1.1
nameserver 8.8.8.8
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
