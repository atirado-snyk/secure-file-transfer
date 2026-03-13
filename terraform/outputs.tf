output "bucket_name" {
  description = "Name of the private GCS bucket for this workspace (derived automatically by transfer.py from --workspace)"
  value       = google_storage_bucket.transfer.name
}

output "signing_sa_email" {
  description = "Signing service account email for this workspace (derived automatically by transfer.py from --workspace)"
  value       = google_service_account.signer.email
}
