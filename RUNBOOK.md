# 5-Line Runbook: Zero-Touch Boot → https://vibebycory.dev/faq-search-demo

1. **IAM Setup**: Ensure EC2 has IAM instance profile with Route53 change permissions
2. **Base Install**: Install docker/nginx/certbot/awscli; place nginx conf; reload
3. **Container Service**: Build & run container via systemd: weaviate-faq.service (port 8501)
4. **TLS**: Certbot issues TLS for vibebycory.dev; renew on schedule
5. **DNS**: update-dns.service UPSERTs apex A record; visit https://vibebycory.dev/faq-search-demo

## Quick Commands

```bash
# Deploy
chmod +x deploy-zero-touch.sh && ./deploy-zero-touch.sh

# Verify
systemctl status weaviate-faq nginx update-dns --no-pager
curl -Ik https://vibebycory.dev/faq-search-demo

# Rollback
chmod +x rollback.sh && ./rollback.sh
```

## Files Created
- `.streamlit/config.toml` - Streamlit subpath config
- `deployment/faq-search-demo.conf` - Nginx reverse proxy config
- `deployment/weaviate-faq.service` - Systemd service for container
- `deployment/update-dns.sh` - Route53 DNS updater script
- `deployment/update-dns.service` - Systemd service for DNS updates
- `deployment/r53-updater-policy.json` - IAM policy for Route53 access

## Paths
- Project root: /Users/corymorgan/Documents/aws-projects/weviate-faq-search
- Terraform dir: /Users/corymorgan/Documents/aws-projects/weviate-faq-search/terraform
- SSH key: ~/.ssh/weaviate-key-pair.pem

## Terraform
cd /Users/corymorgan/Documents/aws-projects/weviate-faq-search/terraform
terraform plan
terraform apply

## Ingestion
ssh -i ~/.ssh/weaviate-key-pair.pem ec2-user@<WEAVIATE_EC2_IP>
cd /home/ec2-user/<repo_or_workdir>
export OPENAI_APIKEY='...'
python3 ingest-faqs-batched.py
unset OPENAI_APIKEY