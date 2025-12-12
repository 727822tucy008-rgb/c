#!/bin/bash
# Wazuh Clean Uninstall & Reinstall Script
# Works on Ubuntu 20.04 / 22.04

echo "=== Stopping Wazuh services ==="
sudo systemctl stop wazuh-manager 2>/dev/null
sudo systemctl stop wazuh-api 2>/dev/null

echo "=== Removing Wazuh packages ==="
sudo apt-get remove --purge wazuh-manager wazuh-api wazuh-agent -y

echo "=== Removing remaining Wazuh directories ==="
sudo rm -rf /var/ossec
sudo rm -rf /etc/ossec.conf
sudo rm -rf /etc/wazuh
sudo rm -rf /usr/share/wazuh-api
sudo rm -rf /var/log/wazuh

echo "=== Updating system ==="
sudo apt-get update && sudo apt-get upgrade -y
sudo apt-get install curl apt-transport-https gnupg2 -y

echo "=== Adding Wazuh repository ==="
curl -s https://packages.wazuh.com/key/GPG-KEY-WAZUH | sudo gpg --dearmor -o /usr/share/keyrings/wazuh-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/wazuh-archive-keyring.gpg] https://packages.wazuh.com/4.x/apt/ stable main" | sudo tee /etc/apt/sources.list.d/wazuh.list
sudo apt-get update

echo "=== Installing Wazuh Manager ==="
sudo apt-get install wazuh-manager -y

echo "=== Enabling & starting Wazuh Manager ==="
sudo systemctl enable wazuh-manager
sudo systemctl start wazuh-manager
sudo systemctl status wazuh-manager --no-pager

echo "=== Installing Wazuh API ==="
sudo apt-get install wazuh-api -y

echo "=== Enabling & starting Wazuh API ==="
sudo systemctl enable wazuh-api
sudo systemctl start wazuh-api
sudo systemctl status wazuh-api --no-pager

echo "=== Installing Wazuh Dashboard (optional) ==="
curl -s https://packages.wazuh.com/4.x/wazuh-dashboard.sh | sudo bash

echo "=== Wazuh Clean Reinstall Complete ==="
echo "Manager running on port 1514 (default), API on 55000"
