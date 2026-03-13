output "sign_blob_role_id" {
  description = "Custom role ID to bind on each workspace signing SA in terraform/main.tf"
  value       = google_project_iam_custom_role.sign_blob.id
}
