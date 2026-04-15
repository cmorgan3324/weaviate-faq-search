import os
import requests
import streamlit as st

WEAVIATE_URL = os.getenv("WEAVIATE_URL", "http://localhost:8080")

# page config & headers
st.set_page_config(
    page_title="Weaviate FAQ Search",
    page_icon="🔍",
    layout="wide",
)

# title & subtitle
st.title("FAQ Semantic Search")
st.subheader("Interactive FAQ lookup powered by Weaviate & OpenAI embeddings")

# query input area
query = st.text_input("Ask a question about AWS...")

# hybrid toggle
hybrid = st.checkbox("Use Hybrid Search (BM25 + Vector)", value=False)

# execute search on button click
if st.button("Search"):
    if not query.strip():
        st.warning("✋ Please enter a question before searching.")
    else:
        # build GraphQL payload
        if hybrid:
            graphql_query = {
                "query": f'''
                {{
                  Get {{
                    FAQ(
                      hybrid: {{
                        query: "{query}"
                        alpha: 0.5
                      }}
                      limit: 5
                    ) {{
                      question
                      answer
                      _additional {{
                        score
                      }}
                    }}
                  }}
                }}
                '''
            }
        else:
            graphql_query = {
                "query": f'''
                {{
                  Get {{
                    FAQ(
                      nearText: {{
                        concepts: ["{query}"]
                      }}
                      limit: 5
                    ) {{
                      question
                      answer
                      _additional {{
                        distance
                      }}
                    }}
                  }}
                }}
                '''
            }

        # add spinner around the network call 
        with st.spinner("Searching for answers…"):
            try:
                resp = requests.post(
                    f"{WEAVIATE_URL}/v1/graphql",
                    json=graphql_query,
                    headers={"Content-Type": "application/json"}
                )
            except requests.exceptions.RequestException as e:
                st.error(f"Network error: {e}")
                st.stop()

            if resp.status_code != 200:
                st.error(f"GraphQL request failed: {resp.status_code}\n{resp.text}")
                st.stop()

            json_out = resp.json()

        # graphql‐level errors & data extraction
        if "errors" in json_out:
            st.error(f"GraphQL errors:\n{json_out['errors']}")
        else:
            faq_results = (
                json_out.get("data", {})
                .get("Get", {})
                .get("FAQ", [])
            )

                        # Define your thresholds
            MAX_DISTANCE = 0.7   # for non‐hybrid
            MIN_SCORE    = 0.65  # for hybrid

            # Separate hybrid vs. non‐hybrid filtering
            if hybrid:
                # Keep only results with score ≥ MIN_SCORE
                filtered = [
                    faq for faq in faq_results
                    if faq.get("_additional", {}).get("score") is not None
                    and float(faq["_additional"]["score"]) >= MIN_SCORE
                ]
                if not filtered:
                    st.write("No results found. Try different keywords or toggle hybrid search.")
                else:
                    for obj in filtered:
                        col1, col2 = st.columns([2, 5])
                        with col1:
                            st.write("**Question:**")
                            st.write(obj["question"])
                        with col2:
                            st.write("**Answer:**")
                            st.write(obj["answer"])
                            raw_score = obj["_additional"]["score"]
                            st.write(f"**Score (↑ is better):** {float(raw_score):.4f}")
                        st.divider()

            else:
                # Keep only results with distance ≤ MAX_DISTANCE
                filtered = [
                    faq for faq in faq_results
                    if faq.get("_additional", {}).get("distance") is not None
                    and float(faq["_additional"]["distance"]) <= MAX_DISTANCE
                ]
                if not filtered:
                    st.write("No results found. Try different keywords or toggle hybrid search.")
                else:
                    for obj in filtered:
                        col1, col2 = st.columns([2, 5])
                        with col1:
                            st.write("**Question:**")
                            st.write(obj["question"])
                        with col2:
                            st.write("**Answer:**")
                            st.write(obj["answer"])
                            distance = obj["_additional"]["distance"]
                            st.write(f"**Distance (↓ is better):** {float(distance):.4f}")
                        st.divider()


# Footer
st.markdown("""
---
<p style="text-align:center; font-size:12px; color:gray;">
Powered by Weaviate & OpenAI • Built with Streamlit
</p>
""", unsafe_allow_html=True)
