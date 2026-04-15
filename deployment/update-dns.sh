#!/bin/bash
set -euo pipefail

# IMDSv2 token + current public IP
TOKEN=$(curl -sX PUT "http://169.254.169.254/latest/api/token" \
  -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
IP=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" \
  http://169.254.169.254/latest/meta-data/public-ipv4)

# Hosted zone ID and UPSERT apex A record
ZONE_ID=$(aws route53 list-hosted-zones-by-name --dns-name vibebycory.dev --query "HostedZones[0].Id" --output text)
aws route53 change-resource-record-sets --hosted-zone-id "$ZONE_ID" --change-batch "{
  \"Comment\": \"Auto-update A record\",
  \"Changes\": [{
    \"Action\": \"UPSERT\",
    \"ResourceRecordSet\": {
      \"Name\": \"vibebycory.dev\",
      \"Type\": \"A\",
      \"TTL\": 60,
      \"ResourceRecords\": [{\"Value\": \"$IP\"}]
    }
  }]
}"