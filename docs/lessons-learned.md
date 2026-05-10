# Lessons Learned

## L1: API Key Exposure in Terraform Variables

**What happened**: The OpenAI API key was initially stored in `terraform.tfvars` as a plaintext variable, passed directly into the EC2 user_data script. While `.gitignore` covered `terraform.tfvars`, the key was embedded in the running instance's user_data (visible via instance metadata) and in Terraform state.

**Root cause**: Terraform's `sensitive = true` annotation only masks output display — it does not encrypt the value in state files or prevent it from appearing in user_data.

**Resolution**: Migrated to SSM Parameter Store with a dedicated fetch script (`/etc/weaviate/fetch-key.sh`) that retrieves the key at container start. Removed the `openai_api_key` variable from Terraform entirely. Rotated the exposed key.

**Takeaway**: Never pass secrets through Terraform variables into user_data. Use a secrets manager (SSM, Secrets Manager) and fetch at runtime with IAM-scoped access.

**Source**: `harden-weaviate.sh`, `terraform/variables.tf` (key variable removed)

---

## L2: Ingestion Requires Weaviate-Local Execution

**What happened**: Initial attempts to run `ingest-faqs-batched.py` from a local machine failed because the script targets `http://localhost:8080`. The Weaviate EC2 security group only allows port 8080 from the Streamlit SG and a single operator IP.

**Root cause**: The ingestion script was designed for on-instance execution. Running remotely would require either opening port 8080 publicly or SSH tunneling.

**Resolution**: Documented that ingestion must run on the Weaviate EC2 instance via SSH or SSM session. The script reads from `/tmp/faqs.csv` (pulled from S3) and writes to localhost.

**Takeaway**: Document execution context requirements explicitly. Scripts that assume localhost access should state that assumption clearly.

**Source**: `ingest-faqs-batched.py`, `PROJECT_STATE.md`

---

## L3: Two Vectorizer Paths Create Confusion

**What happened**: The project has two distinct vectorizer configurations:
- Production (EC2): `text2vec-openai` with `text-embedding-3-small`
- Local (docker-compose): `text2vec-transformers` with `sentence-transformers/all-MiniLM-L6-v2`

This caused confusion when the README documented only the OpenAI path but the docker-compose used transformers.

**Root cause**: The local development path was added later to allow testing without an API key. The README was not updated to reflect both modes.

**Resolution**: Document both paths clearly in architecture docs. The docker-compose path is for local development; the Terraform/EC2 path is for production demo.

**Takeaway**: When a project supports multiple deployment modes with different dependencies, document each mode explicitly with its requirements and limitations.

**Source**: `docker-compose.yml`, `terraform/ec2-weaviate.tf`, `setup_weaviate.py`

---

## L4: Ephemeral EC2 Data Without Persistence

**What happened**: Weaviate data stored inside the Docker container was lost on container recreation. After running `docker rm` during troubleshooting, all ingested FAQ objects were gone and required re-ingestion (including another OpenAI API call).

**Root cause**: Default Docker container storage is ephemeral. No volume or bind mount was configured in the original systemd unit.

**Resolution**: Added host bind mount (`/opt/weaviate/data:/var/lib/weaviate`) in the hardened systemd unit. Data now survives container lifecycle events.

**Takeaway**: Always configure persistent storage for stateful containers from day one, even for demos. Re-ingestion costs money (API calls) and time.

**Source**: `harden-weaviate.sh` (Phase 4)

---

## L5: Streamlit Requires Weaviate IP Discovery at Boot

**What happened**: The Streamlit container needs the Weaviate EC2's private IP to connect. Since instances get new IPs on stop/start, this can't be hardcoded.

**Root cause**: No service discovery mechanism (like ECS service connect or a load balancer) exists in this two-EC2 architecture.

**Resolution**: The Streamlit EC2's user_data script calls `aws ec2 describe-instances` with a Name tag filter to discover the Weaviate private IP at boot, then passes it as the `WEAVIATE_URL` environment variable to the container.

**Takeaway**: In multi-instance architectures without service discovery, tag-based instance lookup is a simple alternative. Ensure the IAM role has `ec2:DescribeInstances` permission.

**Source**: `terraform/streamlit_ec2.tf` (user_data), `terraform/iam.tf` (streamlit_describe policy)
