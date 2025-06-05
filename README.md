FAQ Semantic Search Platform(powered by Weaviate & OpenAI)
============================

I made this FAQ Semantic Search as a proof-of-concept demonstrating how to build a scalable, AI-powered FAQ search system on AWS using Terraform, Weaviate, OpenAI, and Streamlit. This project showcases end-to-end infrastructure-as-code, real-time vector embeddings, containerization of services (Docker) and a polished front-end. 

🔍 Project Overview
-------------------

-   **Problem**: Enable natural language search over a static CSV of FAQs.

-   **Solution**:

    1.  Terraform-provisioned AWS resources (EC2, S3, Security Groups, IAM roles).

    2.  Batched OpenAI embedding ingestion into Weaviate (vector database).

    3.  Hybrid (BM25 + vector) and pure-vector search via a Streamlit UI.

🎯 Key Features
---------------

-   **Infrastructure as Code**:

    -   Single `terraform/` directory manages VPC, EC2, S3 bucket, IAM, and security groups.

    -   One-line `terraform apply` spins up a secure, public-facing Weaviate instance.

-   **Efficient Data Ingestion**:

    -   Batch embedding of questions into OpenAI's API to avoid rate/quota limits.

    -   Automatic upload of `faqs.csv` from S3 into Weaviate with precomputed vectors.

-   **Flexible Query Interface**:

    -   Streamlit app supporting both pure vector search (`nearText`) and hybrid search (`BM25 + vector`).

    -   Clear scoring metrics (distance vs. score) and graceful error handling.

-   **Low Cost / Free Tier**:

    -   EC2 `t3.micro` for Weaviate (free tier).

    -   Terraform-managed S3 for CSV storage.

    -   Free-tier OpenAI embeddings when trimmed CSV fits quota.

🚀 Tech Stack
-------------

-   **AWS**: EC2, S3, IAM, Security Groups

-   **Terraform**: Declarative infrastructure provisioning

-   **Weaviate**: Open-source vector database with OpenAI module

-   **OpenAI Embeddings**: `text-embedding-ada-002` (batched)

-   **Streamlit**: Lightweight Python UI framework

📋 Prerequisites
----------------

1.  **AWS CLI** configured with a profile that has EC2/S3/IAM permissions.

2.  **Terraform (v1.0+)** installed locally.

3.  **Python 3.8+** with `requests` and `streamlit` packages.

4.  **OpenAI API Key** with available embedding quota.

🛠️ Setup Instructions
----------------------

1.  **Clone the repo**

    bash

    CopyEdit

    `git clone https://github.com/yourusername/weaviate-faq-search.git
    cd weaviate-faq-search/terraform`

2.  **Provision AWS Infrastructure**

    bash

    CopyEdit

    `terraform init
    terraform apply -var="aws_profile=<your-profile>"
    # Outputs: weaviate_public_ip (e.g., 35.168.19.92)`

3.  **Upload FAQs CSV to S3**

    bash

    CopyEdit

    `aws s3 cp ../faqs.csv s3://weaviate-faq-csv-v24/faqs.csv --profile <your-profile>`

4.  **SSH or Session Manager into EC2**

    bash

    CopyEdit

    `ssh -i ~/.ssh/weaviate-key-pair.pem ec2-user@<weaviate_public_ip>`

5.  **Run Batched Ingestion Script**

    bash

    CopyEdit

    `export OPENAI_APIKEY="sk-xxxxxx"
    aws s3 cp s3://weaviate-faq-csv-v24/faqs.csv /tmp/faqs.csv
    python3 ~/ingest_faqs_batched.py
    # Wait until "Done ingesting all rows with precomputed vectors."`

6.  **Run the Streamlit App (Locally or on EC2)**

    -   **Locally**:

        bash

        CopyEdit

        `cd weaviate-faq-search
        pip3 install --user streamlit requests
        # Edit WEAVIATE_URL in app.py to "http://<weaviate_public_ip>:8080"
        streamlit run app.py`

    -   **On EC2** (if preferred):

        bash

        CopyEdit

        `sudo yum install -y python3
        python3 -m pip install --user streamlit requests
        nohup ~/.local/bin/streamlit run ~/app.py --server.port 8501 --server.address 0.0.0.0 &`

    -   Access in browser at `http://<weaviate_public_ip>:8501`.

🧰 Usage & Demo Tips
--------------------

-   **Pure-Vector Search** (`nearText`):

    -   Enter a conversational query (e.g., "How can I recover my account?").

    -   Returns semantically closest FAQs but may not always match exact keywords.

-   **Hybrid Search** (`BM25 + vector`):

    -   Ideal for precise, keyword-driven queries (e.g., "How do I reset my password?").

    -   Combining BM25 reduces false positives and surfaces exact matches.

🔧 Troubleshooting
------------------

-   **"Connection refused" or timeout** to `http://<IP>:8080`:

    -   Verify Terraform output for the correct IP.

    -   Ensure the Weaviate container is `Up` (`docker ps`).

    -   Confirm Security Group allows inbound 8080 from your IP.

-   **Embedding quota errors (429 / insufficient_quota)**:

    -   Check OpenAI dashboard for remaining quota.

    -   Trim `faqs.csv` to reduce number of embeddings.

    -   Switch to `text-embedding-ada-002` model in `ingest_faqs_batched.py` for lower cost.

-   **Streamlit UI issues**:

    -   Confirm `WEAVIATE_URL` is set to `http://<weaviate_public_ip>:8080`.

    -   Open port 8501 in the same Security Group (TCP from your IP).