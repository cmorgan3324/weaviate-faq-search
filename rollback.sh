#!/bin/bash
set -euo pipefail

echo "=== ROLLBACK SCRIPT ==="
echo "This will remove the zero-touch deployment setup"
echo

# Stop services
echo "Stopping services..."
sudo systemctl stop weaviate-faq || true
sudo systemctl disable weaviate-faq || true

# Remove nginx config
echo "Removing nginx config..."
sudo mv /etc/nginx/conf.d/faq-search-demo.conf{,.bak} 2>/dev/null || true
sudo nginx -t && sudo systemctl reload nginx

# Remove DNS updater
echo "Removing DNS updater..."
sudo systemctl stop update-dns || true
sudo systemctl disable update-dns || true
sudo rm -f /usr/local/bin/update-dns.sh /etc/systemd/system/update-dns.service
sudo systemctl daemon-reload

# Remove systemd service
echo "Removing systemd service..."
sudo rm -f /etc/systemd/system/weaviate-faq.service
sudo systemctl daemon-reload

# Stop container
echo "Stopping container..."
sudo docker stop weaviate-faq 2>/dev/null || true
sudo docker rm weaviate-faq 2>/dev/null || true

echo "✓ Rollback complete"
echo "Note: TLS certificates and nginx/docker packages remain installed"