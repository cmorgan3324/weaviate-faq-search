# KIRO_SPEC_PROMPT.md

## SYSTEM ARCHITECTURE

Terraform → EC2 instances  
EC2 → boot-setup.sh installs Docker  
Docker → runs Weaviate container (vector DB)  
Python ingestion script → generates embeddings + inserts into Weaviate  
Streamlit → queries Weaviate via GraphQL (nearText)  
Public access → Streamlit via EC2 port 8501  

---

## OBJECTIVE

Resume deployment of the Weaviate FAQ semantic search demo.

The system must:

- Be accessible via a single public URL
- Allow users to enter questions
- Return semantically matched FAQ answers using vector search

---

## CURRENT STATE (DO NOT REPEAT PREVIOUS STEPS)

- Step 1: COMPLETE (Repository analysis)
- Step 2: COMPLETE (Terraform apply, EC2 instances recreated)
- Step 3: COMPLETE (Weaviate container running and reachable)
- Step 4: COMPLETE (FAQ schema created successfully)
- Step 5: PARTIALLY COMPLETE — ingestion failed due to invalid OpenAI API key (HTTP 401)

---

## INSTRUCTION

Resume execution from:

Step 5 — Data Ingestion

Do NOT:

- Re-run Terraform
- Re-analyze repository
- Recreate schema
- Modify infrastructure

---

## CRITICAL CONSTRAINTS

- Do NOT refactor architecture
- Do NOT rename files or move directories
- Do NOT introduce new infrastructure services
- Do NOT replace Terraform resources
- Do NOT modify working code unless absolutely required
- Only make minimal, targeted changes
- If a step cannot be completed, STOP and report
- Do not proceed automatically after failures

---

## STEP 5 — DATA INGESTION (RESUME HERE)

### Default Execution Location

Run ingestion on the Weaviate EC2 instance.

Reason:

- Weaviate is running on localhost:8080
- Avoids networking issues
- Matches production architecture

---

### Secure API Key Injection (REQUIRED)

The OpenAI API key must be injected at runtime only.

Rules:

- Do NOT store the key in files
- Do NOT commit to repo
- Do NOT modify terraform.tfvars
- Do NOT persist on EC2
- Do NOT print the key

---

### Execution Steps

#### 1. SSH into Weaviate EC2

ssh -i ~/.ssh/weaviate-key-pair.pem ec2-user@<WEAVIATE_EC2_IP>

---

#### 2. Set temporary environment variable

export OPENAI_APIKEY='<PASTE_VALID_KEY>'

Verify (without revealing value):

test -n "$OPENAI_APIKEY" && echo "OPENAI_APIKEY set"

---

#### 3. Navigate to project directory

cd /home/ec2-user

(Adjust if repo is in a different location)

---

#### 4. Verify prerequisites

ls ingest-faqs-batched.py  
ls faqs.csv  
curl -s http://localhost:8080/v1/meta  

---

#### 5. Run ingestion

python3 ingest-faqs-batched.py

Capture full output.

---

#### 6. Verify ingestion success

curl -s "http://localhost:8080/v1/objects?class=FAQ&limit=5" | python3 -m json.tool

Expected:

- objects array exists
- length > 0
- valid question + answer pairs

---

#### 7. Remove API key immediately

unset OPENAI_APIKEY  
history -d $((HISTCMD-1))

Verify:

test -z "$OPENAI_APIKEY" && echo "API key removed"

---

## FAILURE HANDLING

If ingestion fails:

Classify error:

- 401 → invalid API key
- connection refused → Weaviate not running
- 422 → schema mismatch
- timeout → embedding/network issue
- module error → missing dependencies

Required behavior:

- Capture full error output
- Do NOT modify script immediately
- STOP and report

---

## SUCCESS CRITERIA

Ingestion is successful when:

- Objects exist in Weaviate
- Query returns valid FAQ results
- No errors during batch insert

---

## NEXT STEPS (DO NOT EXECUTE YET)

After ingestion succeeds:

- Step 6: Validate Streamlit app
- Step 7: Launch public demo
- Step 8: End-to-end testing
- Step 9: Portfolio integration

---

## FINAL REQUIREMENT

The system must:

- Be fully deployable from code + S3
- Require only a single public URL
- Have no secrets persisted in repo or infrastructure
- Be safe for portfolio demonstration

---

## EXECUTION MODE

Run in Kiro Spec Mode.

Follow steps sequentially.  
Stop at any failure.  
Do not improvise changes.
