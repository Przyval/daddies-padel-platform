# Production Meeting Agenda — Daddies Padel Platform

**Frequency**: Monthly (30 minutes)
**Attendees**: Developer(s), Community Manager

## Checklist

### 1. SLO Review (10 min)
- [ ] Check booking SLO (target: 99% success)
  - Firebase Console > Analytics > Events > `sli_booking_attempt`
- [ ] Check payment SLO (target: 99% success)
  - Firebase Console > Analytics > Events > `sli_payment_attempt`
- [ ] Check app load SLO (target: 95% success, < 5s)
  - Firebase Console > Analytics > Events > `sli_app_load`
- [ ] Check data load SLO (target: 95% success, < 10s)
  - Firebase Console > Performance > Traces > `data_service_init`
- [ ] Note any SLO breaches and discuss action items

### 2. Crash Review (5 min)
- [ ] Check Crashlytics crash-free rate (target: > 99.5%)
  - Firebase Console > Crashlytics
- [ ] Review top 3 crash groups
- [ ] Assign owners for unresolved crashes

### 3. Incident Review (5 min)
- [ ] Review any incidents since last meeting
- [ ] Check status of postmortem action items
- [ ] Update incident playbook if needed

### 4. Backup Verification (5 min)
- [ ] Verify daily backups are running
  ```bash
  gsutil ls gs://padel-daddies-backups/firestore/ | tail -7
  ```
- [ ] Check backup sizes are reasonable
- [ ] Schedule quarterly restore test if due

### 5. Upcoming Changes (5 min)
- [ ] Review planned releases / features
- [ ] Identify any risky changes that need extra monitoring
- [ ] Confirm staging deploy and test plan

## Notes

[Meeting notes go here]

---

**Next meeting**: [Date]
