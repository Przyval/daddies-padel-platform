# Incident Playbook — Daddies Padel Platform

## Severity Levels

| Level | Description | Response Time | Examples |
|-------|------------|---------------|----------|
| **SEV1** | App completely unusable for all users | < 30 min | Firebase down, auth broken, blank screen |
| **SEV2** | Major feature broken for some users | < 2 hours | Join session failing, payments not verifying |
| **SEV3** | Minor issue, workaround available | < 24 hours | Slow loading, UI glitch, incorrect count |

## Contact List

| Role | Name | Contact |
|------|------|---------|
| Lead Developer | [TBD] | [phone/WhatsApp] |
| Firebase Admin | [TBD] | [phone/WhatsApp] |
| Community Manager | [TBD] | [phone/WhatsApp] |

## 5-Step Response Process

### 1. Detect
- Firebase Crashlytics alert (crash spike)
- Firebase Performance alert (latency spike)
- User report in WhatsApp group
- SLI analytics show success rate drop

### 2. Assess
- Determine severity level (SEV1/2/3)
- Identify affected users and features
- Check Firebase Console status: https://status.firebase.google.com/
- Check recent deployments: `git log --oneline -10`

### 3. Mitigate
- **If recent deploy caused it**: Rollback via Firebase Hosting
  ```bash
  firebase hosting:rollback --project padel-daddies
  ```
- **If Firestore issue**: Check Firestore Console for errors, quotas
- **If auth issue**: Check Firebase Auth Console for provider status

### 4. Communicate
- Post update in community WhatsApp group
- For SEV1/SEV2: Direct message affected users
- Template: "Hai Daddies, kami sedang menangani [masalah]. Estimasi perbaikan [waktu]. Mohon maaf atas ketidaknyamanannya."

### 5. Resolve
- Fix root cause and deploy
- Verify fix in staging first
- Monitor for 30 minutes after deploy
- Write postmortem (for SEV1/SEV2)

## Specific Scenarios

### App Not Loading (Blank Screen)
1. Check Firebase Console > Hosting for deployment status
2. Check browser console for JavaScript errors
3. Test: `curl -I https://padel-daddies.web.app/`
4. If hosting is fine, check Firebase Core initialization in Crashlytics
5. Rollback: `firebase hosting:rollback`

### Join Session Failing
1. Check `sli_booking_attempt` events in Analytics (success rate)
2. Check `firestore_join_session` trace in Performance (latency)
3. Check Firestore Console > Rules for denied requests
4. Check session document: is `confirmedCount` correct? is `status` correct?
5. Run `syncConfirmedCounts()` if count is out of sync

### Payment Verification Failing
1. Check `sli_payment_attempt` events in Analytics
2. Check `firestore_verify_payment` trace in Performance
3. Verify payment document exists and status is `pending`
4. Check if slot document exists for the payment's `slotId`
5. Manual fix: Update payment status directly in Firestore Console

### Data Loss / Missing Records
1. Check if records were soft-deleted (look for `deletedAt` field)
2. If soft-deleted accidentally: Remove `deletedAt` field in Firestore Console
3. If hard-deleted: Restore from backup (see backup-runbook.md)
4. Check recent code changes for unintended delete operations
