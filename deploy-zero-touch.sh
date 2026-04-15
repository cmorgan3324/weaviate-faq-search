#!/bin/bash
set -euo pipefail

echo "=== Zero-Touch Deployment for Weaviate FAQ Search ==="
echo "Target: https://vibebycory.dev/faq-search-demo"
echo

# 0) PRE-REQ (run once OUTSIDE the instance with admin creds)
echo "0) PRE-REQ - Create IAM role (run this OUTSIDE the instance):"
echo "cat > r53-updater-policy.json <<'JSON'"
cat deployment/r53-updater-policy.json
echo "JSON"
echo
echo "aws iam create-role --role-name weaviate-ec2-role \\"
echo "  --assume-role-policy-document '{\"Version\":\"2012-10-17\",\"Statement\":[{\"Effect\":\"Allow\",\"Principal\":{\"Service\":\"ec2.amazonaws.com\"},\"Action\":\"sts:AssumeRole\"}]}' || true"
echo "aws iam put-role-policy --role-name weaviate-ec2-role --policy-name r53-updater --policy-document file://r53-updater-policy.json"
echo "aws iam create-instance-profile --instance-profile-name weaviate-ec2-profile || true"
echo "aws iam add-role-to-instance-profile --instance-profile-name weaviate-ec2-profile --role-name weaviate-ec2-role || true"
echo
echo "# Attach to running instance:"
echo "INST_ID=\"<your-instance-id>\""
echo "aws ec2 associate-iam-instance-profile --instance-id \"\$INST_ID\" --iam-instance-profile Name=weaviate-ec2-profile"
echo
echo "Press Enter to continue with on-instance setup..."
read

# 1) PACKAGES
echo "1) Installing packages..."
sudo dnf install -y nginx certbot python3-certbot-nginx docker awscli || \
sudo yum install -y nginx certbot python2-certbot-nginx docker awscli
sudo systemctl enable --now docker nginx
echo "✓ Packages installed"

# 2) STREAMLIT CONFIG
echo "2) Streamlit config already created at .streamlit/config.toml"
echo "✓ Streamlit configured for subpath"

# 3) SYSTEMD SERVICE
echo "3) Setting up systemd services..."
sudo cp deployment/weaviate-faq.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable weaviate-faq

# Start with docker-compose for full stack
echo "Starting Weaviate + Streamlit stack..."
cp deployment/docker-compose-ec2.yml docker-compose.yml
docker-compose up -d
sleep 20  # Give Weaviate and transformers time to start

# Setup Weaviate with sample data
echo "Setting up Weaviate with sample data..."
python3 -m pip install weaviate-client requests --user
python3 setup_weaviate.py

echo "✓ Full stack configured and started"

# 4) NGINX
echo "4) Configuring nginx..."
sudo cp deployment/faq-search-demo.conf /etc/nginx/conf.d/
sudo nginx -t && sudo systemctl reload nginx
echo "✓ Nginx configured"

# 5) TLS
echo "5) Setting up TLS with Let's Encrypt..."
sudo certbot --nginx -d vibebycory.dev --non-interactive --agree-tos -m admin@vibebycory.dev
sudo certbot renew --dry-run
echo "✓ TLS configured"

# 6) DYNAMIC DNS
echo "6) Setting up dynamic DNS..."
sudo cp deployment/update-dns.sh /usr/local/bin/
sudo chmod +x /usr/local/bin/update-dns.sh
sudo cp deployment/update-dns.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable update-dns
sudo systemctl start update-dns
echo "✓ Dynamic DNS configured"

# 7) VERIFY
echo "7) Verification..."
echo "Service status:"
systemctl status weaviate-faq --no-pager
systemctl status nginx --no-pager
systemctl status update-dns --no-pager

echo
echo "Testing endpoints:"
curl -Ik http://localhost:8501 || echo "Local test failed"
curl -Ik https://vibebycory.dev/faq-search-demo || echo "Public test failed"

echo
echo "=== DEPLOYMENT COMPLETE ==="
echo "Your app should be available at: https://vibebycory.dev/faq-search-demo"