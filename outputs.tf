output "function_uri" {
  description = "The HTTPS URI of the deployed Cloud Function"
  value       = google_cloudfunctions2_function.function.service_config[0].uri
}

output "service_account_email" {
  description = "The email address of the FinOps Service Account"
  value       = google_service_account.sa.email
}

output "scheduler_job_name" {
  description = "The name of the Cloud Scheduler job"
  value       = google_cloud_scheduler_job.scheduler.name
}
