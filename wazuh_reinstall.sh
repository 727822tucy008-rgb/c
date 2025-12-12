#!/bin/bash
# Complete Wazuh Removal & Fresh Install Script
# Works on Ubuntu 20.04 / 22.04

set -e  # Exit on error

echo "=== COMPLETE WAZUH REMOVAL & FRESH INSTALL ==="
echo "Starting at: $(date)"

# Check if running with sudo
if [ "$EUID" -ne 0 ]; then 
    echo "Please run with sudo"
    exit 1
fi

echo "=== Stopping all Wazuh services ==="
sudo systemctl stop wazuh-manager 2>/dev/null || true
sudo systemctl stop wazuh-api 2>/dev/null || true
sudo systemctl stop wazuh-dashboard 2>/dev/null || true
sudo systemctl stop wazuh-indexer 2>/dev/null || true

echo "=== Removing all Wazuh packages ==="
sudo apt-get remove --purge wazuh-manager wazuh-api wazuh-indexer wazuh-dashboard wazuh-agent -y

echo "=== Removing all Wazuh directories and files ==="
sudo rm -rf /var/ossec
sudo rm -rf /etc/ossec*
sudo rm -rf /etc/wazuh*
sudo rm -rf /usr/share/wazuh*
sudo rm -rf /var/log/wazuh*
sudo rm -rf /var/lib/wazuh*
sudo rm -rf /usr/share/kibana*
sudo rm -rf /var/lib/kibana*
sudo rm -rf /etc/kibana*

echo "=== Cleaning up package system ==="
sudo apt-get autoremove -y
sudo apt-get clean
sudo rm -f /etc/apt/sources.list.d/wazuh.list
sudo rm -f /usr/share/keyrings/wazuh-archive-keyring.gpg

echo "=== Updating system and installing prerequisites ==="
sudo apt-get update
sudo apt-get upgrade -y
sudo apt-get install curl apt-transport-https gnupg2 lsb-release -y

echo "=== Adding Wazuh repository ==="
curl -s https://packages.wazuh.com/key/GPG-KEY-WAZUH | sudo gpg --no-default-keyring --keyring /usr/share/keyrings/wazuh.gpg --import
echo "deb [signed-by=/usr/share/keyrings/wazuh.gpg] https://packages.wazuh.com/4.x/apt/ stable main" | sudo tee /etc/apt/sources.list.d/wazuh.list
sudo apt-get update

echo "=== Installing Wazuh Manager ==="
sudo apt-get install wazuh-manager -y

echo "=== Starting Wazuh Manager ==="
sudo systemctl daemon-reload
sudo systemctl enable wazuh-manager
sudo systemctl start wazuh-manager

echo "=== Installing Wazuh Indexer (replaces old API) ==="
sudo apt-get install wazuh-indexer -y

echo "=== Initializing Wazuh Indexer security ==="
sudo /usr/share/wazuh-indexer/bin/indexer-security-init.sh

echo "=== Starting Wazuh Indexer ==="
sudo systemctl daemon-reload
sudo systemctl enable wazuh-indexer
sudo systemctl start wazuh-indexer

echo "=== Installing Wazuh Dashboard ==="
curl -s https://packages.wazuh.com/4.x/wazuh-dashboard.sh | sudo bash

echo "=== Configuring Dashboard credentials ==="
sudo sed -i 's|#enabled: true|enabled: true|g' /etc/wazuh-dashboard/opensearch_dashboards.yml
sudo sed -i '23s|#password: admin|password: admin|g' /etc/wazuh-dashboard/opensearch_dashboards.yml
sudo sed -i '22s|#username: kibanaserver|username: kibanaserver|g' /etc/wazuh-dashboard/opensearch_dashboards.yml

echo "=== Starting Wazuh Dashboard ==="
sudo systemctl daemon-reload
sudo systemctl enable wazuh-dashboard
sudo systemctl start wazuh-dashboard

echo "=== Waiting for services to start (30 seconds) ==="
sleep 30

echo "=== Verifying installation ==="
echo "Wazuh Manager status:"
sudo systemctl status wazuh-manager --no-pager | head -5

echo -e "\nWazuh Indexer status:"
sudo systemctl status wazuh-indexer --no-pager | head -5

echo -e "\nWazuh Dashboard status:"
sudo systemctl status wazuh-dashboard --no-pager | head -5

echo "=== Checking open ports ==="
sudo ss -tlnp | grep -E ":(1514|9200|5601)" || echo "Ports might still be initializing..."

echo ""
echo "================================================"
echo "✅ INSTALLATION COMPLETE!"
echo "================================================"
echo "Dashboard URL: https://$(hostname -I | awk '{print $1}'):5601"
echo "Default credentials:"
echo "  Username: admin"
echo "  Password: admin"
echo ""
echo "To check if services are ready:"
echo "  sudo systemctl status wazuh-manager wazuh-indexer wazuh-dashboard"
echo ""
echo "If dashboard doesn't load immediately, wait 1-2 minutes and refresh."
echo "================================================"
