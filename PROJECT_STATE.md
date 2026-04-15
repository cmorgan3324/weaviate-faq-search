# PROJECT_STATE

## Project
Weaviate FAQ semantic search demo for portfolio presentation

## Repository Layout

Project root:
- /Users/corymorgan/Documents/aws-projects/weviate-faq-search

Terraform working directory:
- /Users/corymorgan/Documents/aws-projects/weviate-faq-search/terraform

Critical paths:
- PROJECT_STATE.md: ./PROJECT_STATE.md
- RUNBOOK.md: ./RUNBOOK.md
- app.py: ./app.py
- ingest-faqs-batched.py: ./ingest-faqs-batched.py
- faq_schema.json: ./faq_schema.json
- faqs.csv: ./faqs.csv
- terraform.tfvars: ./terraform/terraform.tfvars
- terraform.tfstate: ./terraform/terraform.tfstate
- outputs.tf: ./terraform/outputs.tf

## Architecture
- Terraform provisions two EC2 instances:
  - Weaviate EC2
  - Streamlit EC2
- boot-setup.sh installs Docker
- Weaviate runs in Docker on the Weaviate EC2
- Streamlit frontend runs separately and queries Weaviate
- Public access is through Streamlit on port 8501

## Current Progress
- Step 1: COMPLETE
- Step 2: COMPLETE
- Step 3: COMPLETE
- Step 4: COMPLETE
- Step 5: IN PROGRESS

## Confirmed Facts
- Terraform plan required replacing both EC2 instances
- Replacement was approved because the environment is rebuildable
- Weaviate schema did not exist initially and was created successfully
- GET /v1/schema returned empty before creation
- POST of faq_schema.json succeeded with HTTP 200
- GET /v1/schema/FAQ verified the FAQ class exists
- FAQ class uses text2vec-openai
- question is vectorized
- answer is stored but not vectorized
- S3 bucket weaviate-faq-csv-v24 is accessible
- S3 contains:
  - faqs.csv
  - faq_batch.json
  - faq_schema.json
  - weviate-faq-search.tar.gz
- Ingestion must run on the Weaviate EC2 instance
- ingest-faqs-batched.py expects localhost:8080
- Ingestion failed because the OpenAI API key returned HTTP 401 invalid_api_key
- No repo or Terraform files were modified to handle the invalid key
- Correct next approach is runtime-only API key injection on the Weaviate EC2 instance

## Current Blocker
- A valid OpenAI API key is needed to complete ingestion
- The key must not be pasted into chat
- The key must not be committed to files
- The key must be exported temporarily in the SSH session only

## Constraints
- Do NOT refactor architecture
- Do NOT rename files or move directories
- Do NOT introduce new infrastructure services
- Do NOT replace Terraform resources unless absolutely required
- Do NOT modify working code unless it directly prevents the system from running
- Only make minimal targeted edits required to complete deployment
- Before modifying any file, state the file, exact lines, and reason
- If a constraint conflicts with a step, STOP and report the conflict

## Next Step
Run Step 5 again:
- SSH into the Weaviate EC2 instance
- Export a valid OPENAI_APIKEY in the current shell only
- Run python3 ingest-faqs-batched.py
- Verify FAQ objects exist in Weaviate
- Unset the API key immediately after completion

## Remaining Steps
- Complete Step 5: Data Ingestion
- Step 6: Streamlit Application Validation
- Step 7: Public Demo Launch
- Step 8: End-to-End Verification
- Step 9: Portfolio Integration Output

## Known Risks
- Streamlit container depends on ECR image:
  864899872694.dkr.ecr.us-east-1.amazonaws.com/faq-streamlit:latest
- ECR image existence/startup must still be verified during runtime validation
- Weaviate data on EC2 is ephemeral and must be recreated by ingestion

## Execution Rules
- Run Terraform only from ./terraform
- Run app and ingestion commands from the project root unless EC2 execution is explicitly required
- Run ingestion on the Weaviate EC2 instance for production/demo deployment
- Do not store secrets in repo files

## SSH Configuration
- SSH key location: ~/.ssh/weaviate-key-pair.pem
- SSH user: ec2-user
- Key permissions: 400