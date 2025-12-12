#!/bin/bash

echo "=== Downloading Wazuh certificate tool and config.yml ==="
curl -sO https://packages.wazuh.com/4.14/wazuh-certs-tool.sh
curl -sO https://packages.wazuh.com/4.14/config.yml

chmod +x wazuh-certs-tool.sh

echo "=== Writing your custom config.yml ==="
cat <<EOF > config.yml
nodes:
  # Wazuh indexer node
  indexer:
    - name: node-1
      ip: "10.10.10.10"

  # Wazuh manager node
  server:
    - name: wazuh-1
      ip: "10.10.10.20"

  # Wazuh dashboard node
  dashboard:
    - name: dashboard
      ip: "10.10.10.30"
EOF

echo "=== Generating certificates with wazuh-certs-tool.sh ==="
bash ./wazuh-certs-tool.sh -A

echo "=== Compressing generated certificates ==="
tar -cvf ./wazuh-certificates.tar -C ./wazuh-certificates/ .

echo "=== Cleaning temporary folder ==="
rm -rf ./wazuh-certificates

echo
echo "======================================================="
echo " WAZUH CERTIFICATE GENERATION COMPLETED SUCCESSFULLY "
echo "======================================================="
echo
echo "Generated file: wazuh-certificates.tar"
echo "Copy this file to:"
echo "  → 10.10.10.10 (indexer)"
echo "  → 10.10.10.20 (wazuh-manager)"
echo "  → 10.10.10.30 (dashboard)"
echo
echo "Use this command:"
echo "scp wazuh-certificates.tar root@<IP>:/root/"
echo
