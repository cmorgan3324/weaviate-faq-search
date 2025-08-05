# #!/usr/bin/env bash
# #
# # Looks up your Streamlit & Weaviate public URLs by tag
# # and prints them (or even opens them in your browser).

# REGION="us-east-1"

# # Helper: fetch instance public IP by Name tag
# get_ip() {
#   local TAG="$1" PORT="$2"
#   IP=$(aws ec2 describe-instances \
#     --region "$REGION" \
#     --filters "Name=tag:Name,Values=$TAG" "Name=instance-state-name,Values=running" \
#     --query "Reservations[0].Instances[0].PublicIpAddress" \
#     --output text)
#   if [ "$IP" == "None" ] || [ -z "$IP" ]; then
#     echo "❌ No running instance found for tag '$TAG'"
#   else
#     echo "$TAG → http://$IP:$PORT"
#   fi
# }

# # Fetch and display
# get_ip "streamlit-server" 8501
# get_ip "weaviate-server" 8080

# # Auto-open in default browser
# open "http://$(aws ec2 describe-instances --region $REGION \
#   --filters 'Name=tag:Name,Values=streamlit-server' 'Name=instance-state-name,Values=running' \
#   --query 'Reservations[0].Instances[0].PublicIpAddress' --output text):8501"

#!/usr/bin/env bash
set -euo pipefail

REGION="us-east-1"

# 1. Fetch the IPs
STREAMLIT_IP=$(aws ec2 describe-instances \
  --region "$REGION" \
  --filters "Name=tag:Name,Values=streamlit-server" "Name=instance-state-name,Values=running" \
  --query "Reservations[0].Instances[0].PublicIpAddress" --output text)

WEAVIATE_IP=$(aws ec2 describe-instances \
  --region "$REGION" \
  --filters "Name=tag:Name,Values=weaviate-server" "Name=instance-state-name,Values=running" \
  --query "Reservations[0].Instances[0].PublicIpAddress" --output text)

# 2. Verify we got something
if [[ -z "$STREAMLIT_IP" || "$STREAMLIT_IP" == "None" ]]; then
  echo "❌ Could not find a running streamlit-server instance."
  exit 1
fi
if [[ -z "$WEAVIATE_IP" || "$WEAVIATE_IP" == "None" ]]; then
  echo "❌ Could not find a running weaviate-server instance."
  exit 1
fi

# 3. Print out both URLs
echo "streamlit-server → http://$STREAMLIT_IP:8501"
echo "weaviate-server  → http://$WEAVIATE_IP:8080"

# 4. Open Streamlit in your default browser
open "http://$STREAMLIT_IP:8501"
