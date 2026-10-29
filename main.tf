terraform {
  required_version = ">= 1.5.0"
  required_providers {
    google  = { source = "hashicorp/google", version = "~> 5.0" }
    archive = { source = "hashicorp/archive", version = "~> 2.4" }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

# 1. Habilitar APIs necessárias
resource "google_project_service" "apis" {
  for_each = toset([
    "cloudasset.googleapis.com",
    "compute.googleapis.com",
    "container.googleapis.com",
    "cloudfunctions.googleapis.com",
    "cloudbuild.googleapis.com",
    "cloudscheduler.googleapis.com",
    "run.googleapis.com"
  ])
  project            = var.project_id
  service            = each.key
  disable_on_destroy = false
}

# 2. Service Account e Permissões na Pasta
resource "google_service_account" "sa" {
  account_id   = "sa-weekend-finops"
  display_name = "Service Account Weekend FinOps Automation"
  project      = var.project_id
}

resource "google_folder_iam_member" "permissions" {
  for_each = toset([
    "roles/cloudasset.viewer",
    "roles/compute.instanceAdmin.v1",
    "roles/container.admin",
    "roles/resourcemanager.folderViewer"
  ])
  folder = "folders/${var.folder_id}"
  role   = each.key
  member = "serviceAccount:${google_service_account.sa.email}"
}

# 3. Pacote do Código (Zip e Storage)
data "archive_file" "source_zip" {
  type        = "zip"
  output_path = "${path.module}/function-source.zip"
  source {
    content  = file("${path.module}/main.py")
    filename = "main.py"
  }
  source {
    content  = file("${path.module}/requirements.txt")
    filename = "requirements.txt"
  }
}

resource "google_storage_bucket" "bucket" {
  name     = "${var.project_id}-finops-source"
  location = var.region
  project  = var.project_id
}

resource "google_storage_bucket_object" "zip" {
  name   = "source-${data.archive_file.source_zip.output_md5}.zip"
  bucket = google_storage_bucket.bucket.name
  source = data.archive_file.source_zip.output_path
}

# 4. Cloud Function (Gen 2)
resource "google_cloudfunctions2_function" "function" {
  name        = "cf-weekend-finops-shutdown"
  location    = var.region
  project     = var.project_id
  description = "Weekend FinOps shutdown for GCE and GKE"

  build_config {
    runtime     = "python311"
    entry_point = "weekend_shutdown_http"
    source {
      storage_source {
        bucket = google_storage_bucket.bucket.name
        object = google_storage_bucket_object.zip.name
      }
    }
  }

  service_config {
    available_memory      = "512Mi"
    timeout_seconds       = 540
    service_account_email = google_service_account.sa.email
    environment_variables = {
      FOLDER_ID = var.folder_id
      DRY_RUN   = tostring(var.dry_run)
    }
  }
}

# 5. Permissão de Invocação e Cloud Scheduler
resource "google_cloud_run_service_iam_member" "invoker" {
  project  = var.project_id
  location = var.region
  service  = google_cloudfunctions2_function.function.name
  role     = "roles/run.invoker"
  member   = "serviceAccount:${google_service_account.sa.email}"
}

resource "google_cloud_scheduler_job" "scheduler" {
  name        = "job-weekend-stop-instances"
  description = "Trigger Cloud Function every Friday at 22:00"
  schedule    = var.schedule_cron
  time_zone   = var.time_zone
  region      = var.region
  project     = var.project_id

  http_target {
    http_method = "POST"
    uri         = google_cloudfunctions2_function.function.service_config[0].uri
    oidc_token {
      service_account_email = google_service_account.sa.email
      audience              = google_cloudfunctions2_function.function.service_config[0].uri
    }
  }
}
