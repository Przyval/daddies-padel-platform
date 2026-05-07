# Firestore Backup Runbook — Daddies Padel Platform

## Automated Backups

Daily Firestore exports run at **02:00 WIB** via Cloud Scheduler.
- Destination: `gs://padel-daddies-backups/firestore/`
- Retention: 30 days (auto-deleted by GCS lifecycle policy)

## Manual Backup

```bash
gcloud firestore export gs://padel-daddies-backups/manual/$(date +%Y%m%d-%H%M%S) \
  --project=padel-daddies
```

## Verify Backups

```bash
# List all backups
gsutil ls gs://padel-daddies-backups/

# Check most recent export
gsutil ls -l gs://padel-daddies-backups/firestore/ | tail -5
```

## Restore from Backup

**WARNING**: Importing will overwrite existing documents with the same IDs.

```bash
# 1. Identify the backup to restore
gsutil ls gs://padel-daddies-backups/firestore/

# 2. Import (specify the full path to the backup folder)
gcloud firestore import gs://padel-daddies-backups/firestore/2025-01-15T19:00:00_12345/ \
  --project=padel-daddies

# 3. To restore specific collections only:
gcloud firestore import gs://padel-daddies-backups/firestore/2025-01-15T19:00:00_12345/ \
  --collection-ids=users,sessions,slots,payments \
  --project=padel-daddies
```

## Monthly Verification Checklist

- [ ] Check that daily backups are running: `gsutil ls gs://padel-daddies-backups/firestore/ | tail -7`
- [ ] Verify latest backup size is reasonable (not empty)
- [ ] Test restore to a separate project or emulator (quarterly)
- [ ] Review GCS billing for the backup bucket

## Setup

First-time setup: run `./scripts/setup-firestore-backup.sh`

Requires Firebase Blaze plan and `gcloud` CLI authenticated.
