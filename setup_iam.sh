#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Infrastructure and IAM Setup Script for Weekend FinOps Automation
# ==============================================================================

HOST_PROJECT_ID="${HOST_PROJECT_ID:-<YOUR_PROJECT_ID>}"
TARGET_FOLDER_ID="${TARGET_FOLDER_ID:-<YOUR_TARGET_FOLDER_ID>}"
SA_NAME="sa-weekend-finops"
SA_EMAIL="${SA_NAME}@${HOST_PROJECT_ID}.iam.gserviceaccount.com"

echo "=== [1/4] Setting active project: ${HOST_PROJECT_ID} ==="
gcloud config set project "${HOST_PROJECT_ID}"

echo "=== [2/4] Enabling required APIs on host project ==="
gcloud services enable \
    cloudasset.googleapis.com \
    compute.googleapis.com \
    container.googleapis.com \
    cloudfunctions.googleapis.com \
    cloudbuild.googleapis.com \
    cloudscheduler.googleapis.com \
    run.googleapis.com

echo "=== [3/4] Creating dedicated Service Account: ${SA_NAME} ==="
if gcloud iam service-accounts describe "${SA_EMAIL}" --project="${HOST_PROJECT_ID}" >/dev/null 2>&1; then
    echo "Service Account ${SA_EMAIL} already exists. Skipping creation."
else
    gcloud iam service-accounts create "${SA_NAME}" \
        --display-name="Service Account Weekend FinOps Automation" \
        --project="${HOST_PROJECT_ID}"
    echo "Service Account created successfully."
fi

echo "=== [4/4] Granting folder-level IAM permissions (Folder ID: ${TARGET_FOLDER_ID}) ==="
ROLES=(
    "roles/cloudasset.viewer"
    "roles/compute.instanceAdmin.v1"
    "roles/container.admin"
    "roles/resourcemanager.folderViewer"
)

for ROLE in "${ROLES[@]}"; do
    echo "-> Granting ${ROLE}..."
    gcloud resource-manager folders add-iam-policy-binding "${TARGET_FOLDER_ID}" \
        --member="serviceAccount:${SA_EMAIL}" \
        --role="${ROLE}"
done

echo ""
echo "=============================================================================="
echo " Setup completed successfully!"
echo " Service Account: ${SA_EMAIL}"
echo " Target Scope: folders/${TARGET_FOLDER_ID}"
echo "=============================================================================="
