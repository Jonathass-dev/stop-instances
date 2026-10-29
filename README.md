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
* `main.tf`: Terraform definition for all GCP resources (Cloud Function v2, Cloud Scheduler, Service Account, Storage bucket, IAM folder bindings).
* `variables.tf`: Input variables for the Terraform configuration.
* `outputs.tf`: Outputs exposing the Cloud Function URI, Service Account, and Scheduler job name.
* `terraform.tfvars.example`: Example variable values for deployment.

---

## Terraform Deployment (Production / Recommended)

### 1. Prerequisites
* [Terraform](https://developer.hashicorp.com/terraform/downloads) >= 1.5.0 installed.
* Authenticated Google Cloud SDK (`gcloud auth application-default login`).

### 2. Configure Variables
Copy the example variables file:
```bash
cp terraform.tfvars.example terraform.tfvars
```
Edit `terraform.tfvars` with your target `project_id` and `folder_id`:
```hcl
project_id = "your-gcp-project-id"
folder_id  = "123456789012"
region     = "us-central1"
dry_run    = false
```

### 3. Deploy Infrastructure
```bash
terraform init
terraform plan
terraform apply
```

---

## Manual Recovery (Starting Resources on Monday)

* **GCE VMs:** Start instances via GCP Console (**Compute Engine > VM Instances > Start**) or via CLI:
  ```bash
  gcloud compute instances start <VM_NAME> --zone=<ZONE> --project=<PROJECT_ID>
  ```
* **GKE Clusters:** Resize the node pool back to the desired number of nodes:
  ```bash
  gcloud container clusters resize <CLUSTER_NAME> --node-pool=<POOL_NAME> --num-nodes=<COUNT> --zone=<ZONE> --project=<PROJECT_ID>
  ```
