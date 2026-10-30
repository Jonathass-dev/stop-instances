# Weekend FinOps: Automated GCE & GKE Shutdown

A lightweight, serverless FinOps automation on Google Cloud Platform (GCP) designed to stop running Compute Engine (GCE) VM instances and scale down Google Kubernetes Engine (GKE) node pools to 0 nodes across an entire GCP folder during weekends, minimizing idle compute costs.

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

## Repository Structure

```text
.
├── src/
│   ├── main.py                  # Core Python routine (Functions Framework & GCP SDKs)
│   └── requirements.txt         # Python dependencies
├── main.tf                      # Terraform infrastructure definitions (GCP resources)
├── variables.tf                 # Terraform input variables
├── outputs.tf                   # Terraform outputs
├── terraform.tfvars.example     # Template for variable values
├── .gitignore                   # Git ignore patterns
└── README.md                    # Project documentation
```

---

## Integration with Other Repositories

This module uses self-contained relative paths (`${path.module}/src/...`). It can be integrated into another repository in two ways:

### Option 1: As a Subdirectory / Monorepo Component
Place this directory (or its contents) into your target repository (e.g., `modules/weekend-finops/`):

```hcl
module "weekend_finops" {
  source = "./modules/weekend-finops"

  project_id = "your-host-project-id"
  folder_id  = "123456789012"
  region     = "us-central1"
  dry_run    = false
}
```

### Option 2: As a Remote Git Terraform Module
Reference this repository directly from another Terraform codebase:

```hcl
module "weekend_finops" {
  source = "git::https://github.com/Jonathass-dev/stop-instances.git?ref=main"

  project_id = "your-host-project-id"
  folder_id  = "123456789012"
  region     = "us-central1"
  dry_run    = false
}
```

---

## Standalone Deployment

### 1. Prerequisites
* [Terraform](https://developer.hashicorp.com/terraform/downloads) >= 1.5.0
* Authenticated Google Cloud SDK (`gcloud auth application-default login`)

### 2. Configure Variables
Copy the example variables file:
```bash
cp terraform.tfvars.example terraform.tfvars
```

Configure `terraform.tfvars`:
```hcl
project_id    = "your-gcp-project-id"
folder_id     = "123456789012"
region        = "us-central1"
schedule_cron = "0 22 * * 5"
time_zone     = "America/Sao_Paulo"
dry_run       = false
```

### 3. Deploy
```bash
terraform init
terraform plan
terraform apply
```

### 4. Teardown / Destroy
To delete all automation resources:
```bash
terraform destroy
```

---

## Terraform Variables Reference

### Inputs

| Variable | Description | Type | Default | Required |
| :--- | :--- | :--- | :--- | :---: |
| `project_id` | GCP Project ID where automation is hosted | `string` | - | **Yes** |
| `folder_id` | Numerical ID of target GCP folder to scan | `string` | - | **Yes** |
| `region` | GCP Region for Cloud Function & Scheduler | `string` | `"us-central1"` | No |
| `schedule_cron` | Cron schedule expression | `string` | `"0 22 * * 5"` | No |
| `time_zone` | Time zone for Cloud Scheduler | `string` | `"America/Sao_Paulo"` | No |
| `dry_run` | Run in simulation mode without stopping | `bool` | `false` | No |

### Outputs

| Output | Description |
| :--- | :--- |
| `function_uri` | HTTPS endpoint URI of the deployed Cloud Function |
| `service_account_email` | Service Account email created for the FinOps automation |
| `scheduler_job_name` | Name of the Cloud Scheduler job |

---

## Log Format (Cloud Logging)

All logs are emitted as clean, structured key-value messages for fast filtering in Google Cloud Logging:

* **GCE Stop:** `GCE: project=<id> zone=<zone> vm=<name> action=STOP`
* **GCE Skip:** `GCE: project=<id> zone=<zone> vm=<name> status=<status> action=SKIP`
* **GCE Error:** `GCE: project=<id> zone=<zone> vm=<name> status=ERROR error=<msg>`
* **GKE Scale:** `GKE: project=<id> location=<loc> cluster=<name> pool=<pool> current_nodes=<n> target_nodes=0 action=SCALE_DOWN`
* **GKE Skip:** `GKE: project=<id> location=<loc> cluster=<name> status=SKIP reason=<msg>`
* **Summary:** `FinOps: summary gce_stopped=<n> gke_pools_scaled=<n>`

---

## Monday Morning Resource Recovery

Developers restart their respective resources on Monday morning:

* **Compute Engine VM:**
  ```bash
  gcloud compute instances start <VM_NAME> --zone=<ZONE> --project=<PROJECT_ID>
  ```
* **GKE Node Pool:**
  ```bash
  gcloud container clusters resize <CLUSTER_NAME> --node-pool=<POOL_NAME> --num-nodes=<COUNT> --zone=<ZONE> --project=<PROJECT_ID>
  ```
