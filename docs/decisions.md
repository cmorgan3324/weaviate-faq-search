# Decisions

## D1: Two-EC2 Architecture (Weaviate + Streamlit separated)

**Decision**: Run Weaviate and Streamlit on separate EC2 instances.

**Alternatives**:
- Single EC2 running both services
- ECS/Fargate for container orchestration
- Single docker-compose on one instance

**Tradeoffs**:
- Separation allows independent scaling and security group isolation
- Adds complexity: Streamlit must discover Weaviate IP at boot
- Higher cost than single instance (~2x EC2 runtime)
- Simpler than ECS for a portfolio demo

**Justification**: Security group isolation allows Weaviate port 8080 to be restricted to Streamlit's SG only, preventing public access to the vector database. Acceptable cost tradeoff for a demo that demonstrates proper network segmentation.

**Source**: `terraform/ec2-weaviate.tf`, `terraform/streamlit_ec2.tf`

---

## D2: text-embedding-3-small over text-embedding-ada-002

**Decision**: Use OpenAI's `text-embedding-3-small` model for production embeddings.

**Alternatives**:
- `text-embedding-ada-002` (older, widely documented)
- `text-embedding-3-large` (higher dimension, higher cost)
- Self-hosted sentence-transformers (MiniLM-L6-v2, used in local mode)

**Tradeoffs**:
- `3-small` is newer, cheaper per token, and produces better embeddings than ada-002
- `3-large` would be overkill for 30 FAQ items
- Self-hosted (MiniLM) avoids API costs but lower quality for English semantic search

**Justification**: Best cost/quality ratio for a small FAQ dataset. The local docker-compose path uses MiniLM for zero-cost development without an API key.

**Source**: `ingest-faqs-batched.py` (line: `EMBEDDING_MODEL = "text-embedding-3-small"`)

---

## D3: SSM Parameter Store for API Key Management

**Decision**: Store OpenAI API key in AWS SSM Parameter Store as SecureString, fetched at container start via systemd ExecStartPre.

**Alternatives**:
- Hardcoded in Terraform tfvars (original approach — insecure)
- AWS Secrets Manager (more features, higher cost)
- Environment variable in user_data (persisted in instance metadata)

**Tradeoffs**:
- SSM Parameter Store is free for standard parameters
- Requires IAM policy granting `ssm:GetParameter` to EC2 role
- Key is written to `/etc/weaviate/weaviate.env` (chmod 600) at boot — not fully ephemeral but root-only
- Secrets Manager would add rotation but costs $0.40/secret/month

**Justification**: Free, simple, and sufficient for a single secret. The hardening script (`harden-weaviate.sh`) implements this pattern with validation and rollback.

**Source**: `harden-weaviate.sh` (Phase 1-2), `terraform/iam.tf`

---

## D4: Hybrid Search (BM25 + Vector) as User Option

**Decision**: Expose both pure vector search (`nearText`) and hybrid search (`BM25 + vector`) via a UI toggle.

**Alternatives**:
- Vector-only (simpler, fewer false positives on semantic queries)
- Hybrid-only (always combines keyword + semantic)
- Separate endpoints

**Tradeoffs**:
- Hybrid reduces false positives for keyword-heavy queries
- Pure vector handles conversational/paraphrased queries better
- UI toggle adds minimal complexity but demonstrates both retrieval strategies

**Justification**: Demonstrates understanding of retrieval tradeoffs — a key portfolio signal for AI/ML roles. Both modes use the same Weaviate GraphQL endpoint with different query structures.

**Source**: `app.py` (hybrid checkbox, GraphQL query construction)

---

## D5: Host Bind Mount for Weaviate Data Persistence

**Decision**: Persist Weaviate data to host filesystem (`/opt/weaviate/data`) via Docker bind mount instead of Docker volumes.

**Alternatives**:
- Docker named volume (default, data inside Docker-managed directory)
- EBS volume attached separately
- EFS for shared storage

**Tradeoffs**:
- Bind mount survives container recreation and image upgrades
- Easier to backup/inspect from host
- Docker volumes are simpler but harder to access directly
- EBS would add cost and complexity for 30 FAQ objects

**Justification**: Data must survive `docker rm` + `docker run` cycles during hardening and upgrades. Bind mount is the simplest path for a single-node deployment.

**Source**: `harden-weaviate.sh` (Phase 4-5), systemd unit file

---

## D6: Nginx + Certbot for TLS Termination

**Decision**: Use Nginx as reverse proxy with Let's Encrypt TLS certificates managed by Certbot.

**Alternatives**:
- AWS ALB with ACM certificate (managed, higher cost)
- Caddy (automatic TLS, simpler config)
- Direct Streamlit exposure without TLS

**Tradeoffs**:
- Nginx + Certbot is free and well-documented
- ALB would add ~$16/month minimum
- Caddy would be simpler but less common in AWS deployments
- No TLS would be unacceptable for a portfolio demo

**Justification**: Zero additional AWS cost. Certbot auto-renews. Nginx handles WebSocket upgrade for Streamlit's real-time features.

**Source**: `deployment/faq-search-demo.conf`, `deploy-zero-touch.sh`

---

## D7: Dynamic DNS via Route53 UPSERT at Boot

**Decision**: Update Route53 A record with current public IP at every instance boot using a systemd oneshot service.

**Alternatives**:
- Elastic IP (static, $3.60/month when attached to running instance, free while in use — but costs if instance stopped)
- CloudFront distribution pointing to origin
- Manual DNS update

**Tradeoffs**:
- Dynamic DNS is free and handles IP changes on stop/start
- Elastic IP would be simpler but adds cost if instance is stopped frequently
- Adds ~2 second boot delay for DNS propagation (TTL 60s)

**Justification**: Instance is stopped when not demoing to save cost. Dynamic DNS avoids paying for an idle Elastic IP and handles IP reassignment automatically.

**Source**: `deployment/update-dns.sh`, `deployment/update-dns.service`, `terraform/iam.tf` (Route53 policy)
