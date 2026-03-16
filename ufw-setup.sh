#!/bin/bash
# UFW Firewall Rules for AdGuard Home DHCP + DNS
# Run with sudo: sudo bash ufw-setup.sh
#
# IMPORTANT: DHCP uses broadcast packets (source 0.0.0.0 → dest 255.255.255.255)
# Devices requesting DHCP don't have an IP yet, so we MUST use "from any"
# Using "from 192.168.2.0/24" will NOT work for DHCP!

set -e

INTERFACE="eno1"  # Change to your network interface
LOCAL_NET="192.168.2.0/24"  # Change to your local network

echo "=== Adding AdGuard Home firewall rules ==="

# DHCP - MUST be "from any" (broadcast packets)
sudo ufw allow in on "$INTERFACE" from any to any port 67 proto udp comment "AdGuard DHCP server"
sudo ufw allow in on "$INTERFACE" from any to any port 68 proto udp comment "AdGuard DHCP client responses"

# DNS - can be restricted to local network
sudo ufw allow in from "$LOCAL_NET" to any port 53 proto udp comment "AdGuard DNS (UDP)"
sudo ufw allow in from "$LOCAL_NET" to any port 53 proto tcp comment "AdGuard DNS (TCP)"

# Web UI - restrict to local network
sudo ufw allow in from "$LOCAL_NET" to any port 3000 proto tcp comment "AdGuard web UI"

echo ""
echo "=== Verifying rules ==="
sudo ufw status verbose | grep -E "(67|68|53|3000)"

echo ""
echo "✅ Done! All AdGuard Home firewall rules added."
