variable "project_id" {
  description = "The GCP project ID where the automation infrastructure is hosted"
  type        = string
}

variable "folder_id" {
  description = "The numerical ID of the target folder to scan and stop resources (e.g. team-labs)"
  type        = string
}

variable "region" {
  description = "The GCP region for the Cloud Function and Scheduler"
  type        = string
  default     = "us-central1"
}

variable "schedule_cron" {
  description = "Cron schedule expression for the weekend shutdown"
  type        = string
  default     = "0 22 * * 5" # Every Friday at 22:00
}

variable "time_zone" {
  description = "Time zone for the Cloud Scheduler job"
  type        = string
  default     = "America/Sao_Paulo"
}

variable "dry_run" {
  description = "Whether to run in simulation mode without stopping resources"
  type        = bool
  default     = false
}
