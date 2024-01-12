#!/bin/bash

# Check if running as root
if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root." >&2
    exit 1
fi

# Restore /etc/resolv.conf from backup
echo "Restoring /etc/resolv.conf from backup..."
mv /etc/resolv.conf.backup /etc/resolv.conf

# Enable systemd-resolved
echo "Enabling systemd-resolved..."
systemctl enable systemd-resolved

# Start systemd-resolved
echo "Starting systemd-resolved..."
systemctl start systemd-resolved

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
