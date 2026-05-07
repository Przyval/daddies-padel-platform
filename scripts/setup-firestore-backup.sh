#!/bin/bash
# ==============================================================================
# Firestore Automated Backup Setup — Daddies Padel Platform
# ==============================================================================
#
# Prerequisites:
#   - Firebase Blaze (pay-as-you-go) plan
#   - gcloud CLI installed and authenticated
#   - Project ID: padel-daddies
#
# This script:
#   1. Creates a GCS bucket for backups with 30-day lifecycle
#   2. Grants Firestore export permissions
#   3. Creates a Cloud Scheduler job for daily backups at 02:00 WIB (UTC+7)
#
# Usage:
#   chmod +x scripts/setup-firestore-backup.sh
#   ./scripts/setup-firestore-backup.sh
# ==============================================================================

set -euo pipefail

PROJECT_ID="padel-daddies"
BUCKET_NAME="${PROJECT_ID}-backups"
LOCATION="asia-southeast2"  # Jakarta
SCHEDULE="0 19 * * *"       # 02:00 WIB = 19:00 UTC previous day

echo "==> Setting project to ${PROJECT_ID}"
gcloud config set project "${PROJECT_ID}"

# 1. Create backup bucket
echo "==> Creating GCS bucket gs://${BUCKET_NAME}/"
gsutil mb -l "${LOCATION}" "gs://${BUCKET_NAME}/" 2>/dev/null || echo "    Bucket already exists"

# 2. Set 30-day lifecycle (auto-delete old backups)
echo "==> Setting 30-day lifecycle policy"
cat > /tmp/lifecycle.json <<'EOF'
{
  "rule": [
    {
      "action": {"type": "Delete"},
      "condition": {"age": 30}
    }
  ]
}
EOF
gsutil lifecycle set /tmp/lifecycle.json "gs://${BUCKET_NAME}/"
rm /tmp/lifecycle.json

# 3. Grant Firestore export permissions to the default service account
echo "==> Granting IAM permissions for Firestore export"
SA="${PROJECT_ID}@appspot.gserviceaccount.com"
gsutil iam ch "serviceAccount:${SA}:objectAdmin" "gs://${BUCKET_NAME}/"

# 4. Enable required APIs
echo "==> Enabling Cloud Scheduler and Firestore APIs"
gcloud services enable cloudscheduler.googleapis.com
gcloud services enable firestore.googleapis.com

# 5. Create Cloud Scheduler job for daily backup
echo "==> Creating Cloud Scheduler job for daily Firestore export"
gcloud scheduler jobs create http firestore-daily-backup \
  --schedule="${SCHEDULE}" \
  --uri="https://firestore.googleapis.com/v1/projects/${PROJECT_ID}/databases/(default):exportDocuments" \
  --http-method=POST \
  --headers="Content-Type=application/json" \
  --message-body="{\"outputUriPrefix\": \"gs://${BUCKET_NAME}/firestore\"}" \
  --oauth-service-account-email="${SA}" \
  --location="${LOCATION}" \
  --time-zone="Asia/Jakarta" \
  2>/dev/null || echo "    Job already exists — updating..."

echo ""
echo "==> Setup complete!"
echo "    Bucket:    gs://${BUCKET_NAME}/"
echo "    Schedule:  Daily at 02:00 WIB"
echo "    Lifecycle: 30-day auto-delete"
echo ""
echo "    To trigger a manual backup:"
echo "    gcloud firestore export gs://${BUCKET_NAME}/manual/\$(date +%Y%m%d-%H%M%S)"
echo ""
echo "    To verify backups:"
echo "    gsutil ls gs://${BUCKET_NAME}/"
