#!/bin/bash
# Verification script - Run BEFORE disabling router DHCP
# Checks all 5 critical prerequisites for AdGuard DHCP takeover
#
# Usage: sudo bash verify.sh

set -e

INTERFACE="eno1"  # Change to your network interface
SERVER_IP="192.168.2.135"  # Change to your server's static IP
PASS=0
FAIL=0

check() {
    if [ "$1" -eq 0 ]; then
        echo "  ✅ $2"
        PASS=$((PASS + 1))
    else
        echo "  ❌ $2"
        FAIL=$((FAIL + 1))
    fi
}

echo "🔍 AdGuard Home DHCP Takeover - Pre-Flight Check"
echo "================================================="
echo ""

# 1. Static IP
echo "1. Static IP Configuration"
ip addr show "$INTERFACE" | grep -q "$SERVER_IP"
check $? "Server has static IP $SERVER_IP on $INTERFACE"

# 2. Kernel parameters
echo ""
echo "2. Kernel Parameters (Blacklist Prevention)"
SEND_REDIRECTS=$(sysctl -n "net.ipv4.conf.$INTERFACE.send_redirects" 2>/dev/null)
[ "$SEND_REDIRECTS" = "0" ]
check $? "send_redirects=0 on $INTERFACE (current: $SEND_REDIRECTS)"

ACCEPT_REDIRECTS=$(sysctl -n "net.ipv4.conf.$INTERFACE.accept_redirects" 2>/dev/null)
[ "$ACCEPT_REDIRECTS" = "0" ]
check $? "accept_redirects=0 on $INTERFACE (current: $ACCEPT_REDIRECTS)"

# 3. Firewall rules
echo ""
echo "3. UFW Firewall Rules"
sudo ufw status | grep -q "67/udp"
check $? "Port 67/udp (DHCP server) allowed"

sudo ufw status | grep -q "68/udp"
check $? "Port 68/udp (DHCP client) allowed"

sudo ufw status | grep -q "53/udp"
check $? "Port 53/udp (DNS) allowed"

# 4. Docker container
echo ""
echo "4. AdGuard Container"
docker ps --format '{{.Names}}' | grep -q "adguard"
check $? "AdGuard container running"

docker inspect adguard --format '{{.HostConfig.NetworkMode}}' | grep -q "host"
check $? "Container using host network mode"

docker inspect adguard --format '{{.HostConfig.CapAdd}}' | grep -q "NET_ADMIN"
check $? "Container has NET_ADMIN capability"

# 5. DHCP listening
echo ""
echo "5. DHCP Server Status"
ss -tulnp | grep -q ":67 "
check $? "AdGuard listening on port 67 (DHCP)"

ss -tulnp | grep -q ":53 "
check $? "AdGuard listening on port 53 (DNS)"

# 6. No errors in logs
echo ""
echo "6. AdGuard Logs (recent errors)"
ERRORS=$(docker logs adguard 2>&1 | tail -50 | grep -ciE "(error|invalid|fail)" || true)
[ "$ERRORS" -eq 0 ]
check $? "No errors in recent logs (found: $ERRORS)"

# Summary
echo ""
echo "================================================="
echo "Results: $PASS passed, $FAIL failed"
echo ""

if [ "$FAIL" -eq 0 ]; then
    echo "🎉 ALL CHECKS PASSED! Safe to disable router DHCP."
else
    echo "⚠️  FIX FAILURES ABOVE before disabling router DHCP!"
    exit 1
fi
