#!/bin/bash
# Wazuh Indexer & Dashboard Installation Script
# Run this after Wazuh Manager is already installed and running

set -e

echo "=== WAZUH INSTALLATION CONTINUATION ==="
echo "Starting at: $(date)"

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo "Please run with sudo"
    exit 1
fi

echo "=== Installing Wazuh Indexer ==="
apt-get install -y wazuh-indexer

echo "=== Starting Indexer without custom certificates ==="
echo "Letting Wazuh use its default self-signed certificates..."
systemctl enable --now wazuh-indexer

echo "=== Waiting for Indexer to initialize (30 seconds) ==="
sleep 30

echo "=== Verifying Indexer is running ==="
if systemctl is-active --quiet wazuh-indexer; then
    echo "✅ Wazuh Indexer service is active"
else
    echo "❌ Wazuh Indexer failed to start"
    echo "Checking status..."
    systemctl status wazuh-indexer --no-pager
    exit 1
fi

echo "=== Testing Indexer connection ==="
echo "Waiting for port 9200 to open..."
for i in {1..10}; do
    if curl -k -s https://localhost:9200 >/dev/null 2>&1; then
        echo "✅ Indexer is responding on port 9200"
        break
    fi
    echo -n "."
    sleep 5
done

echo "=== Installing Wazuh Dashboard ==="
curl -s https://packages.wazuh.com/4.x/wazuh-dashboard.sh | bash

echo "=== Configuring Dashboard to use insecure connection ==="
DASH_CONFIG="/etc/wazuh-dashboard/opensearch_dashboards.yml"

# Backup original config if it exists
if [ -f "$DASH_CONFIG" ]; then
    mv "$DASH_CONFIG" "$DASH_CONFIG.backup_$(date +%Y%m%d_%H%M%S)"
fi

# Create new configuration
cat > "$DASH_CONFIG" << 'EOF'
# OpenSearch connection
opensearch.hosts: https://localhost:9200
opensearch.ssl.verificationMode: none
opensearch.username: admin
opensearch.password: admin
opensearch.requestHeadersWhitelist: ["authorization", "securitytenant"]

# Server configuration
server.host: "0.0.0.0"
server.port: 5601
server.maxPayloadBytes: 1048576

# Security configuration
opensearch_security.multitenancy.enabled: true
opensearch_security.multitenancy.tenants.preferred: ["Private", "Global"]
opensearch_security.readonly_mode.roles: ["kibana_read_only"]
opensearch_security.cookie.secure: false

# Telemetry and features
newsfeed.enabled: false
telemetry.optIn: false
telemetry.enabled: false
savedObjects.maxImportPayloadBytes: 10485760

# Wazuh specific
wazuh.security.enabled: false
EOF

echo "=== Setting correct permissions ==="
chown wazuh-dashboard:wazuh-dashboard "$DASH_CONFIG"
chmod 640 "$DASH_CONFIG"

echo "=== Starting Wazuh Dashboard ==="
systemctl enable --now wazuh-dashboard

echo "=== Waiting for Dashboard to start (40 seconds) ==="
sleep 40

echo "=== FINAL VERIFICATION ==="
echo "1. Service Status:"
echo "   - Wazuh Manager: $(systemctl is-active wazuh-manager 2>/dev/null || echo 'Not found')"
echo "   - Wazuh Indexer: $(systemctl is-active wazuh-indexer)"
echo "   - Wazuh Dashboard: $(systemctl is-active wazuh-dashboard)"

echo -e "\n2. Open Ports:"
PORTS=(1514 9200 5601)
for port in "${PORTS[@]}"; do
    if ss -tlnp | grep -q ":$port "; then
        echo "   ✅ Port $port is listening"
    else
        echo "   ❌ Port $port is NOT listening"
    fi
done

echo -e "\n3. Testing Dashboard connection:"
if curl -k -s https://localhost:5601 >/dev/null 2>&1; then
    echo "   ✅ Dashboard is responding"
else
    echo "   ⚠️  Dashboard not responding yet (may need more time)"
    echo "   Checking dashboard logs..."
    journalctl -u wazuh-dashboard --no-pager | tail -10
fi

echo ""
echo "================================================"
echo "✅ INSTALLATION COMPLETE!"
echo "================================================"
echo ""
echo "YOUR DASHBOARD IS READY AT:"
echo "   URL: https://$(hostname -I | awk '{print $1}'):5601"
echo "   Username: admin"
echo "   Password: admin"
echo ""
echo "TROUBLESHOOTING COMMANDS:"
echo "   Check all services: sudo systemctl status wazuh-manager wazuh-indexer wazuh-dashboard"
echo "   Check dashboard logs: sudo journalctl -u wazuh-dashboard -f"
echo "   Restart dashboard: sudo systemctl restart wazuh-dashboard"
echo ""
echo "Note: If you can't connect immediately, wait 1-2 minutes and refresh."
echo "================================================"

echo -e "\n=== Checking logs for errors ==="
echo "Recent dashboard errors (if any):"
journalctl -u wazuh-dashboard --since "1 minute ago" | grep -i error | tail -5 || echo "No recent errors found"
