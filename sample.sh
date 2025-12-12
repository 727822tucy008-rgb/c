#!/bin/bash

echo "=== Stopping indexer & dashboard services ==="
systemctl stop wazuh-indexer 2>/dev/null
systemctl stop wazuh-dashboard 2>/dev/null

echo "=== Removing indexer & dashboard packages ONLY ==="
apt purge -y wazuh-indexer wazuh-dashboard
apt autoremove -y
apt clean

echo "=== Removing leftover indexer & dashboard directories ==="
rm -rf /usr/share/wazuh-indexer
rm -rf /usr/share/wazuh-dashboard
rm -rf /etc/wazuh-indexer
rm -rf /etc/wazuh-dashboard
rm -rf /var/lib/wazuh-indexer
rm -rf /var/log/wazuh-indexer
rm -rf /var/log/wazuh-dashboard
rm -rf /etc/filebeat

echo "=== Downloading Wazuh installation assistant ==="
curl -sO https://packages.wazuh.com/4.9/wazuh-install.sh
curl -sO https://packages.wazuh.com/4.9/config.yml

echo "=== Writing single-node config.yml (manager already exists) ==="
cat <<EOF > config.yml
nodes:
  indexer:
    - name: node-1
      ip: "10.10.10.112"

  server:
    - name: wazuh-1
      ip: "10.10.10.112"   # manager already installed

  dashboard:
    - name: dashboard
      ip: "10.10.10.112"
EOF

echo "=== Setting permissions ==="
chmod 755 wazuh-install.sh

echo "=== Installing certificates ==="
./wazuh-install.sh --generate-certs

echo "=== Installing ONLY indexer & dashboard ==="
./wazuh-install.sh --only-indexer --only-dashboard

echo "=== Done! ==="
echo "Access Dashboard at: https://10.10.10.112"
