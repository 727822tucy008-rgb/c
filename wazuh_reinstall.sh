#!/bin/bash
# Simple Wazuh Clean Remove & Fresh Install Script (Manager + Indexer + Dashboard)
# Ubuntu 20.04 / 22.04

set -e

echo "=== Checking for sudo ==="
if [ "$EUID" -ne 0 ]; then 
    echo "Please run with sudo"
    exit 1
fi

echo "=== Stopping Wazuh services ==="
systemctl stop wazuh-manager 2>/dev/null || true
systemctl stop wazuh-indexer 2>/dev/null || true
systemctl stop wazuh-dashboard 2>/dev/null || true

echo "=== Removing old Wazuh packages ==="
apt-get remove --purge -y wazuh-manager wazuh-indexer wazuh-dashboard wazuh-agent || true

echo "=== Removing old directories ==="
rm -rf /var/ossec /etc/ossec* /etc/wazuh* /usr/share/wazuh* /var/log/wazuh* /var/lib/wazuh*

echo "=== Cleaning package system ==="
apt-get autoremove -y
apt-get clean
rm -f /etc/apt/sources.list.d/wazuh.list
rm -f /usr/share/keyrings/wazuh-archive-keyring.gpg

echo "=== Installing prerequisites ==="
apt-get update
apt-get upgrade -y
apt-get install -y curl apt-transport-https gnupg2 lsb-release

echo "=== Adding Wazuh repository ==="
curl -s https://packages.wazuh.com/key/GPG-KEY-WAZUH | gpg --no-default-keyring --keyring /usr/share/keyrings/wazuh.gpg --import
echo "deb [signed-by=/usr/share/keyrings/wazuh.gpg] https://packages.wazuh.com/4.x/apt/ stable main" | tee /etc/apt/sources.list.d/wazuh.list
apt-get update

echo "=== Installing Wazuh Manager ==="
apt-get install -y wazuh-manager
systemctl enable --now wazuh-manager

echo "=== Installing Wazuh Indexer ==="
apt-get install -y wazuh-indexer
/usr/share/wazuh-indexer/bin/indexer-security-init.sh
systemctl enable --now wazuh-indexer

echo "=== Installing Wazuh Dashboard ==="
curl -s https://packages.wazuh.com/4.x/wazuh-dashboard.sh | bash
systemctl enable --now wazuh-dashboard

echo "=== Waiting 20 seconds for services to start ==="
sleep 20

echo "=== Wazuh Services Status ==="
systemctl status wazuh-manager --no-pager | head -5
systemctl status wazuh-indexer --no-pager | head -5
systemctl status wazuh-dashboard --no-pager | head -5

echo "=== Open Ports ==="
ss -tlnp | grep -E ":(1514|9200|5601)" || echo "Ports might still be initializing..."

echo ""
echo "✅ Wazuh installation complete!"
echo "Dashboard URL: https://$(hostname -I | awk '{print $1}'):5601"
echo "Default credentials: admin / admin"
