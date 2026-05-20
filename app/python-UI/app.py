import requests
import streamlit as st

BACKEND_URL = "http://localhost:8085/query"

st.set_page_config(page_title="Petclinic AIOps Assistant", page_icon="🛠", layout="wide")
st.title("Petclinic AIOps Assistant")

question = st.text_area(
    "Question",
    value="What is wrong with the petclinic platform?",
    height=120,
)

col1, col2 = st.columns(2)

with col1:
    service = st.text_input("Service (optional)", value="")
    namespace = st.text_input("Namespace", value="petclinic")

with col2:
    time_range = st.number_input("Time Range (minutes)", min_value=1, max_value=1440, value=60, step=5)

if st.button("Analyze", type="primary"):
    payload = {
        "question": question,
        "namespace": namespace,
        "timeRangeMinutes": int(time_range),
    }

    if service.strip():
        payload["service"] = service.strip()

    try:
        response = requests.post(BACKEND_URL, json=payload, timeout=30)
        response.raise_for_status()
        data = response.json()

        st.subheader("Probable Root Cause")
        st.write(data.get("probableRootCause", "No response"))

        st.subheader("Confidence")
        st.write(data.get("confidence", "unknown"))

        st.subheader("Impacted Services")
        impacted = data.get("impactedServices", [])
        if impacted:
            for item in impacted:
                st.write(f"- {item}")
        else:
            st.write("No impacted services listed.")

        st.subheader("Recommended Fix")
        fixes = data.get("recommendedFix", [])
        if fixes:
            for item in fixes:
                st.write(f"- {item}")
        else:
            st.write("No recommendations returned.")

        st.subheader("Unknowns")
        unknowns = data.get("unknowns", [])
        if unknowns:
            for item in unknowns:
                st.write(f"- {item}")
        else:
            st.write("No unknowns returned.")

        st.subheader("Evidence Collected")
        evidence = data.get("evidenceCollected", [])
        if evidence:
            for item in evidence:
                st.code(item)
        else:
            st.write("No evidence returned.")

    except requests.exceptions.RequestException as exc:
        st.error(f"Backend request failed: {exc}")
