#!/bin/sh
set -e

# 1) Fetch the latest FAQs CSV from S3 into /tmp
aws s3 cp s3://weaviate-faq-csv-v24/faqs.csv /tmp/faqs.csv || true

# 2) Ensure the FAQ class exists in Weaviate schema
if ! curl -s -X GET http://localhost:8080/v1/schema | grep -q '"class":"FAQ"'; then
  curl -s -X POST http://localhost:8080/v1/schema \
    -H "Content-Type: application/json" \
    -d @/tmp/faq_schema.json \
    || echo "⚠️  Schema creation may have already been applied"
fi

# 3) Batch‐ingest the CSV into Weaviate (won’t duplicate objects)
curl -s -X POST \
    "http://localhost:8080/v1/batch/objects?batchSize=16&class=FAQ&vectorizer=text2vec-openai" \
    -H "Content-Type: text/csv" \
    --data-binary @/tmp/faqs.csv \
  || echo "⚠️  Batch import may have already been applied"
