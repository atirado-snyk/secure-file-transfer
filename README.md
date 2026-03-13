# secure-file-transfer

Disposable secure file sharing via GCS signed URLs — provision, upload, share, tear down.

Each transfer runs in its own isolated workspace with a dedicated private bucket. Infrastructure
is provisioned on demand via a GitHub Actions pipeline and torn down when the transfer is complete.

---

## How it works

A **workspace** is the unit of isolation — one per transfer, named after the customer or purpose.

```
gh workflow run terraform.yml -f action=apply -f workspace=acme-q1-report
  └─ provisions a private GCS bucket + signing service account for this workspace

python transfer.py upload --workspace acme-q1-report --file report.pdf
  └─ uploads the file and prints a time-limited signed URL

                      [ share URL with customer → one-click download ]

gh workflow run terraform.yml -f action=destroy -f workspace=acme-q1-report -f confirm_destroy=destroy
  └─ removes the bucket, the service account, and all files
```

Signed URLs are served from `storage.googleapis.com`, which enforces TLS 1.2 / 1.3 and
strong ECDHE cipher suites. No service-account key file is ever created or stored.

---

## Prerequisites

- GCP project with the following APIs enabled:
  ```bash
  gcloud services enable storage.googleapis.com iam.googleapis.com iamcredentials.googleapis.com
  ```
- A GCS bucket for Terraform state — create it once:
  ```bash
  gsutil mb -p <project_id> gs://<project_id>-tf-state
  gsutil versioning set on gs://<project_id>-tf-state
  ```
- A GCP service account with Storage Admin + IAM Admin permissions, and a JSON key for GitHub Actions.
- Python 3.9+ with `gcloud` CLI authenticated locally (`gcloud auth application-default login`).

---

## One-time setup

### 1. GitHub Actions secrets

Set these in **Settings → Secrets and variables → Actions**:

| Secret | Value |
|---|---|
| `GCP_PROJECT_ID` | your GCP project ID |
| `GCP_CREDENTIALS` | contents of the service account JSON key |
| `GCP_SIGNING_MEMBERS` | IAM members allowed to upload and sign, e.g. `["user:you@gmail.com"]` |
| `TF_STATE_BUCKET` | name of the GCS state bucket created above |

### 2. Python dependencies

```bash
cd scripts
python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
```

---

## Workflow

### Provision + upload in one command

```bash
gh workflow run terraform.yml -f action=apply -f workspace=acme-q1-report && \
python scripts/transfer.py upload --workspace acme-q1-report --file report.pdf
```

The script prints the signed URL to share with the customer. The URL expires after 1 hour by default.

### Tear down

```bash
gh workflow run terraform.yml -f action=destroy -f workspace=acme-q1-report -f confirm_destroy=destroy
```

Typing `destroy` in `confirm_destroy` is required — it prevents accidental teardown.

### Running multiple transfers in parallel

Each workspace is fully isolated. Run as many as needed simultaneously:

```bash
gh workflow run terraform.yml -f action=apply -f workspace=acme-q1-report
gh workflow run terraform.yml -f action=apply -f workspace=globex-contract
```

Each gets its own bucket (`secure-transfer-<workspace>`) and can be torn down independently.

---

## Other script commands

```bash
# List files currently in a workspace's bucket
python scripts/transfer.py list --workspace acme-q1-report

# Delete a specific file before it expires
python scripts/transfer.py delete --workspace acme-q1-report --object report.pdf

# Override the default 1h expiry (max 7d)
python scripts/transfer.py upload --workspace acme-q1-report --file report.pdf --expiry 4h
```

---

## Security notes

- Buckets have `public_access_prevention = enforced` — objects can never be made public accidentally.
- Signed URLs are scoped to `GET` only and expire at the time requested (default 1h, max 7d).
- No service-account key file is created. The script impersonates the signing SA via the IAM
  `signBlob` API using your local ADC credentials, which are revocable at any time.
- Files auto-delete after 7 days even if the workspace is not explicitly destroyed.
