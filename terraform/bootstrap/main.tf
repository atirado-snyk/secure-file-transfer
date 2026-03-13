terraform {
  required_version = ">= 1.5"

  # Separate state prefix from the per-workspace config.
  # Bucket is passed at init time: terraform init -backend-config="bucket=<bucket>"
  backend "gcs" {
    prefix = "secure-file-transfer-bootstrap"
  }

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

provider "google" {
  project = var.project_id
}

# ---------------------------------------------------------------------------
# Least-privilege custom role for V4 signed URL generation.
#
# Grants only iam.serviceAccounts.signBlob — the single permission needed
# to call the IAM signBlob API on the per-workspace signing SA.
#
# Lives here (project-scoped, long-lived) rather than in the per-workspace
# config to avoid role ID conflicts across concurrent workspace applies.
# The binding itself is scoped to each SA resource in terraform/main.tf.
# ---------------------------------------------------------------------------
resource "google_project_iam_custom_role" "sign_blob" {
  role_id     = "secureTransferSignBlob"
  title       = "Secure Transfer — Sign Blob Only"
  description = "Allows signBlob on the per-workspace signing SA. Least privilege for V4 signed URL generation."
  permissions = ["iam.serviceAccounts.signBlob"]
}
