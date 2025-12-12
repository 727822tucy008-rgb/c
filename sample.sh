#!/bin/bash
# Wazuh Installation Continuation (Manager already running)
set -e

echo "=== INSTALLATION CONTINUATION ==="
echo "Starting from Wazuh Indexer installation..."

echo "=== Installing Wazuh Indexer ==="
apt-get install -y wazuh-indexer

echo "=== Generating certificates for Wazuh Indexer ==="
# Generate certificates BEFORE running security init
/usr/share/wazuh-indexer/bin/indexer-security-certificates/generate-certificates.sh

echo "=== Initializing Wazuh Indexer security ==="
# Initialize security with the generated certificates
JAVA_HOME=/usr/share/wazuh-indexer/jdk sudo -u wazuh-indexer /usr/share/wazuh-indexer/plugins/opensearch-security/tools/securityadmin.sh \
  -cd /usr/share/wazuh-indexer/plugins/opensearch-security/securityconfig/ \
  -cacert /etc/wazuh-indexer/certs/root-ca.pem \
  -cert /etc/wazuh-indexer/certs/admin.pem \
  -key /etc/wazuh-indexer/certs/admin-key.pem \
  -h 127.0.0.1 -p 9200 -icl -nhnv

echo "=== Starting Wazuh Indexer ==="
systemctl enable --now wazuh-indexer

echo "=== Waiting for Indexer to be ready (30 seconds) ==="
sleep 30

echo "=== Verifying Indexer is running ==="
if curl -k -s https://localhost:9200 >/dev/null 2>&1; then
    echo "✅ Wazuh Indexer is running and accessible"
else
    echo "⚠️  Indexer might still be starting, continuing anyway..."
    echo "Trying to start again..."
    systemctl restart wazuh-indexer
    sleep 10
fi

echo "=== Installing Wazuh Dashboard ==="
curl -s https://packages.wazuh.com/4.x/wazuh-dashboard.sh | bash

echo "=== Configuring Dashboard ==="
# Configure dashboard to connect to Indexer
DASH_CONFIG="/etc/wazuh-dashboard/opensearch_dashboards.yml"
cat > "$DASH_CONFIG" << EOF
# OpenSearch connection
opensearch.hosts: https://localhost:9200
opensearch.ssl.verificationMode: none
opensearch.username: admin
opensearch.password: admin
opensearch.requestHeadersWhitelist: ["authorization", "securitytenant"]

# Server configuration
server.host: "0.0.0.0"
server.port: 5601

# Security
opensearch_security.multitenancy.enabled: true
opensearch_security.multitenancy.tenants.preferred: ["Private", "Global"]
opensearch_security.readonly_mode.roles: ["kibana_read_only"]
opensearch_security.cookie.secure: false

# Telemetry
newsfeed.enabled: false
telemetry.optIn: false
telemetry.enabled: false
EOF

echo "=== Starting Wazuh Dashboard ==="
systemctl enable --now wazuh-dashboard

echo "=== Waiting for Dashboard to start (40 seconds) ==="
sleep 40

echo "=== FINAL VERIFICATION ==="
echo "1. Wazuh Manager status:"
systemctl is-active wazuh-manager && echo "✅ Active" || echo "❌ Not active"

echo -e "\n2. Wazuh Indexer status:"
systemctl is-active wazuh-indexer && echo "✅ Active" || echo "❌ Not active"

echo -e "\n3. Wazuh Dashboard status:"
systemctl is-active wazuh-dashboard && echo "✅ Active" || echo "❌ Not active"

echo -e "\n4. Checking open ports:"
for port in 1514 9200 5601; do
    if ss -tlnp | grep -q ":$port "; then
        echo "✅ Port $port is open"
    else
        echo "❌ Port $port is NOT open"
    fi
done

echo -e "\n5. Testing Dashboard connectivity:"
if curl -k -s https://localhost:5601 >/dev/null 2>&1; then
    echo "✅ Dashboard is responding"
else
    echo "⚠️  Dashboard not responding yet (may need more time)"
fi

echo ""
echo "================================================"
echo "✅ INSTALLATION COMPLETE!"
echo "================================================"
echo ""
echo "ACCESS YOUR DASHBOARD:"
echo "URL: https://$(hostname -I | awk '{print $1}'):5601"
echo "Username: admin"
echo "Password: admin"
echo ""
echo "If you cannot connect:"
echo "1. Wait 1-2 minutes for full initialization"
echo "2. Check logs: sudo journalctl -u wazuh-dashboard -f"
echo "3. Check firewall: sudo ufw allow 5601/tcp"
echo "4. Restart dashboard: sudo systemctl restart wazuh-dashboard"
echo "================================================"
