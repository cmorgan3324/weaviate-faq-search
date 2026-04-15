#!/usr/bin/env python3
"""
Setup script to initialize Weaviate with FAQ data
"""
import os
import time
import requests

# Wait for Weaviate to be ready
def wait_for_weaviate(url="http://localhost:8080", max_retries=30):
    for i in range(max_retries):
        try:
            response = requests.get(f"{url}/v1/.well-known/ready")
            if response.status_code == 200:
                print("✓ Weaviate is ready!")
                return True
        except requests.exceptions.RequestException:
            pass
        
        print(f"Waiting for Weaviate... ({i+1}/{max_retries})")
        time.sleep(2)
    
    return False

def setup_weaviate():
    # Use REST API to set up Weaviate (simpler than gRPC)
    base_url = "http://localhost:8080"
    
    # Check if schema already exists
    try:
        schema_response = requests.get(f"{base_url}/v1/schema")
        if schema_response.status_code == 200:
            schema = schema_response.json()
            if any(cls['class'] == 'FAQ' for cls in schema.get('classes', [])):
                print("✓ FAQ schema already exists")
                return
    except:
        pass
    
    # Create FAQ schema using REST API
    faq_schema = {
        "class": "FAQ",
        "description": "Frequently Asked Questions",
        "vectorizer": "text2vec-transformers",
        "properties": [
            {
                "name": "question",
                "dataType": ["text"],
                "description": "The FAQ question",
                "moduleConfig": {
                    "text2vec-transformers": {
                        "skip": False,
                        "vectorizePropertyName": False
                    }
                }
            },
            {
                "name": "answer", 
                "dataType": ["text"],
                "description": "The FAQ answer",
                "moduleConfig": {
                    "text2vec-transformers": {
                        "skip": True,
                        "vectorizePropertyName": False
                    }
                }
            }
        ]
    }
    
    schema_response = requests.post(
        f"{base_url}/v1/schema",
        json=faq_schema,
        headers={"Content-Type": "application/json"}
    )
    
    if schema_response.status_code == 200:
        print("✓ Created FAQ schema")
    else:
        print(f"❌ Failed to create schema: {schema_response.text}")
        return
    
    # Sample FAQ data
    sample_faqs = [
        {
            "question": "What is AWS EC2?",
            "answer": "Amazon Elastic Compute Cloud (EC2) is a web service that provides secure, resizable compute capacity in the cloud. It allows you to launch virtual servers, configure security and networking, and manage storage."
        },
        {
            "question": "How do I create an S3 bucket?",
            "answer": "You can create an S3 bucket through the AWS Console, CLI, or SDKs. In the console, go to S3 service, click 'Create bucket', choose a unique name, select a region, and configure settings like versioning and encryption."
        },
        {
            "question": "What is AWS Lambda?",
            "answer": "AWS Lambda is a serverless compute service that runs your code in response to events and automatically manages the compute resources. You pay only for the compute time you consume - there's no charge when your code isn't running."
        },
        {
            "question": "How do I set up VPC?",
            "answer": "To set up a VPC, go to the VPC console, click 'Create VPC', specify the IP address range (CIDR block), create subnets, configure route tables, and set up internet gateways or NAT gateways as needed."
        },
        {
            "question": "What is AWS RDS?",
            "answer": "Amazon Relational Database Service (RDS) is a managed database service that makes it easy to set up, operate, and scale relational databases in the cloud. It supports MySQL, PostgreSQL, Oracle, SQL Server, and Amazon Aurora."
        }
    ]
    
    # Add sample data using REST API
    for faq in sample_faqs:
        data_response = requests.post(
            f"{base_url}/v1/objects",
            json={
                "class": "FAQ",
                "properties": faq
            },
            headers={"Content-Type": "application/json"}
        )
        
        if data_response.status_code != 200:
            print(f"❌ Failed to add FAQ: {data_response.text}")
    
    print(f"✓ Added {len(sample_faqs)} sample FAQs")
    print("✓ Weaviate setup complete!")

if __name__ == "__main__":
    if wait_for_weaviate():
        setup_weaviate()
    else:
        print("❌ Weaviate failed to start")
        exit(1)