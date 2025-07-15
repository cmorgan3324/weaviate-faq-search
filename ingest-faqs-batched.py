import csv
import os
import json
import time
import requests


WEAVIATE_URL = "http://localhost:8080"
OPENAI_API_KEY = os.getenv("OPENAI_APIKEY")

# embedding model; you can switch to "text-embedding-ada-002" or another
EMBEDDING_MODEL = "text-embedding-ada-002"

# max number of questions per OpenAI batch. 
# can increase up to ~2048 if you have a large CSV, but keep it small enough to avoid large JSON bodies.
BATCH_SIZE = 50

# path to trimmed CSV on the EC2
CSV_PATH = "/tmp/faqs.csv"


if not OPENAI_API_KEY:
    raise RuntimeError("Please export OPENAI_APIKEY with your OpenAI key before running.")

# read all rows from the CSV into memory
rows = []
with open(CSV_PATH, "r", encoding="utf-8") as f:
    reader = csv.DictReader(f)
    for row in reader:
        # ensure keys exactly match your CSV header: "question" and "answer"
        rows.append({
            "question": row["question"],
            "answer": row["answer"],
        })

if not rows:
    print(f"No rows found in {CSV_PATH}; exiting.")
    exit(0)

# batch the "question" texts into chunks of size BATCH_SIZE for OpenAI
questions = [r["question"] for r in rows]

def get_embeddings(text_list):
    """
    Calls OpenAI's embeddings endpoint with a list of strings.
    Returns a list of embedding vectors (one list of floats per input string).
    """
    url = "https://api.openai.com/v1/embeddings"
    headers = {
        "Content-Type": "application/json",
        "Authorization": f"Bearer {OPENAI_API_KEY}"
    }
    payload = {
        "model": EMBEDDING_MODEL,
        "input": text_list
    }
    resp = requests.post(url, headers=headers, json=payload)
    if resp.status_code != 200:
        raise RuntimeError(f"OpenAI embedding request failed: {resp.status_code} {resp.text}")
    data = resp.json()
    # data is a list of { "index": i, "embedding": [ ... ], ... }
    # extract embeddings in the same order as input
    return [item["embedding"] for item in data["data"]]

# divide questions into batches
all_vectors = []
for i in range(0, len(questions), BATCH_SIZE):
    batch = questions[i : i + BATCH_SIZE]
    print(f"Requesting embeddings for questions {i}–{i + len(batch) - 1}...")
    try:
        vectors = get_embeddings(batch)
    except Exception as e:
        print(f"Error while getting embeddings for batch starting at index {i}: {e}")
        # optional: retry logic around get_embeddings could go here
        raise
    all_vectors.extend(vectors)
    # to stay under rate limits: wait 1 second between batches
    time.sleep(1)

if len(all_vectors) != len(rows):
    raise RuntimeError(f"Mismatch: {len(all_vectors)} embeddings vs {len(rows)} rows")

print(f"Total embeddings received: {len(all_vectors)}")

# send each row+vector to Weaviate in one shot (no more OpenAI calls needed)
for idx, row in enumerate(rows):
    vector = all_vectors[idx]
    properties = {
        "question": row["question"],
        "answer": row["answer"]
    }
    payload = {
        "class": "FAQ",
        "properties": properties,
        "vector": vector
    }
    resp = requests.post(
        f"{WEAVIATE_URL}/v1/objects",
        headers={"Content-Type": "application/json"},
        json=payload
    )
    if resp.status_code not in (200, 201):
        print(f"Failed to import row idx {idx}: {row['question']}. "
              f"Status: {resp.status_code}, Response: {resp.text}")
    else:
        print(f"Successfully imported idx {idx}: '{row['question']}'")
    # Optional: very short sleep to avoid hammering Weaviate
    time.sleep(0.1)

print("Done ingesting all rows with precomputed vectors.")
