#!/bin/bash

# Check if the script is run as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root"
   exit 1
fi

# Configure systemd-resolved
# Disable DNSStubListener
echo -e "[Resolve]\nDNSStubListener=no" | tee /etc/systemd/resolved.conf.d/no-stub-listener.conf

# Restart systemd-resolved to apply changes
systemctl restart systemd-resolved

# Setup alternative DNS resolution by modifying /etc/resolv.conf
# Backup the current resolv.conf
cp /etc/resolv.conf /etc/resolv.conf.backup

# Set Google DNS for example, you can choose another provider
echo "nameserver 8.8.8.8" > /etc/resolv.conf
echo "nameserver 8.8.4.4" >> /etc/resolv.conf

# Verify the configuration
echo "DNS configuration updated. /etc/resolv.conf now contains:"
cat /etc/resolv.conf

# Optional: Verify that port 53 is free
echo "Checking for services listening on port 53:"
lsof -i :53

echo "Script execution completed."
