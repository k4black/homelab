#!/bin/bash

# Check if the script is run as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root"
   exit 1
fi

# Create systemd-resolved configuration directory if it doesn't exist
mkdir -p /etc/systemd/resolved.conf.d/

# Configure systemd-resolved
# Disable DNSStubListener
echo -e "[Resolve]\nDNSStubListener=no" | tee /etc/systemd/resolved.conf.d/no-stub-listener.conf

# Restart systemd-resolved to apply changes
systemctl restart systemd-resolved

# Check if systemd-resolved is still using port 53
echo "Checking for services listening on port 53 after systemd-resolved restart:"
lsof -i :53

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

# Test DNS resolution
echo "Testing DNS resolution with a ping to google.com:"
ping -c 3 google.com

echo "Script execution completed."
