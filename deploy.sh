#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Cloud Function Deployment Script for Weekend FinOps
# ==============================================================================

PROJECT_ID="${PROJECT_ID:-<YOUR_PROJECT_ID>}"
REGION="${REGION:-us-central1}"
FUNCTION_NAME="cf-weekend-finops-shutdown"
SA_NAME="sa-weekend-finops"
SA_EMAIL="${SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"
FOLDER_ID="${FOLDER_ID:-<YOUR_TARGET_FOLDER_ID>}"

echo "=== Deploying Cloud Function: ${FUNCTION_NAME} ==="
gcloud functions deploy "${FUNCTION_NAME}" \
    --gen2 \
    --runtime=python311 \
    --region="${REGION}" \
    --source="." \
    --entry-point="weekend_shutdown_http" \
    --trigger-http \
    --no-allow-unauthenticated \
    --service-account="${SA_EMAIL}" \
    --set-env-vars="FOLDER_ID=${FOLDER_ID},DRY_RUN=false" \
    --timeout=540s \
    --memory=512Mi \
    --project="${PROJECT_ID}"

echo "=== Deployment completed successfully! ==="
