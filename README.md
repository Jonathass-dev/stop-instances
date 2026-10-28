# Weekend FinOps: Automated GCE & GKE Shutdown

A lightweight, serverless FinOps automation on Google Cloud Platform (GCP) to stop running Compute Engine (GCE) instances and scale down Google Kubernetes Engine (GKE) node pools to 0 nodes across an entire GCP folder during weekends, minimizing cloud computing costs.

---

## Architecture Overview

```
                          EVERY FRIDAY AT 22:00
                                    │
                                    ▼
                        ┌───────────────────────┐
                        │    Cloud Scheduler    │ (Cron: 0 22 * * 5)
                        └───────────────────────┘
                                    │
                                    ▼ [Authenticated OIDC HTTP Trigger]
                        ┌───────────────────────┐
                        │  Cloud Function Gen2  │ (Python 3.11 Runtime)
                        └───────────────────────┘
                                    │
            ┌───────────────────────┴───────────────────────┐
            ▼                                               ▼
┌─────────────────────────────────┐   ┌─────────────────────────────────────┐
│      Cloud Asset Inventory      │   │         GCP Execution APIs          │
│ • Single-pass scan across       │   │ • Compute Engine: instances.stop()  │
│   entire target folder scope    │   │ • Container API: setNodePoolSize(0) │
└─────────────────────────────────┘   └─────────────────────────────────────┘
```

---

## Project Structure

* `main.py`: Core Python routine using Google Cloud Client Libraries (`asset_v1`, `compute_v1`, `container_v1`) with Functions Framework.
* `requirements.txt`: Python package dependencies.
* `setup_iam.sh`: Infrastructure setup script for creating the Service Account and granting folder-level IAM bindings.
* `deploy.sh`: Deployment script for deploying the Gen 2 Cloud Function to GCP.

---

## Environment Variables

| Variable | Description | Default |
| :--- | :--- | :--- |
| `FOLDER_ID` | Numerical ID of the target GCP folder (e.g., `123456789012`) | *Required* |
| `DRY_RUN` | When `true`, simulates actions and logs them without modifying resources | `false` |

---

## Deployment & Setup

### 1. Prerequisites & IAM Setup
Configure environment variables and run the IAM setup script:
```bash
export HOST_PROJECT_ID="<YOUR_PROJECT_ID>"
export TARGET_FOLDER_ID="<YOUR_TARGET_FOLDER_ID>"

./setup_iam.sh
```

### 2. Deploy Cloud Function
```bash
export PROJECT_ID="<YOUR_PROJECT_ID>"
export FOLDER_ID="<YOUR_TARGET_FOLDER_ID>"

./deploy.sh
```

### 3. Create Cloud Scheduler Job
```bash
CF_URL=$(gcloud functions describe cf-weekend-finops-shutdown --region=us-central1 --format="value(serviceConfig.uri)" --project="<YOUR_PROJECT_ID>")
SA_EMAIL="sa-weekend-finops@<YOUR_PROJECT_ID>.iam.gserviceaccount.com"

# Grant invoker permission
gcloud functions add-invoker-policy-binding cf-weekend-finops-shutdown \
    --region="us-central1" \
    --member="serviceAccount:${SA_EMAIL}" \
    --project="<YOUR_PROJECT_ID>"

# Create weekly schedule (Every Friday at 22:00)
gcloud scheduler jobs create http job-weekend-stop-instances \
    --location="us-central1" \
    --schedule="0 22 * * 5" \
    --time-zone="America/Sao_Paulo" \
    --uri="${CF_URL}" \
    --http-method="POST" \
    --oidc-service-account-email="${SA_EMAIL}" \
    --project="<YOUR_PROJECT_ID>"
```

---

## Monday Morning Recovery (Starting Resources)

* **GCE VMs:** Developers start their instances via GCP Console (**Compute Engine > VM Instances > Start**) or via CLI:
  ```bash
  gcloud compute instances start <VM_NAME> --zone=<ZONE> --project=<PROJECT_ID>
  ```
* **GKE Clusters:** Resize the node pool back to the desired number of nodes:
  ```bash
  gcloud container clusters resize <CLUSTER_NAME> --node-pool=<POOL_NAME> --num-nodes=<COUNT> --zone=<ZONE> --project=<PROJECT_ID>
  ```
