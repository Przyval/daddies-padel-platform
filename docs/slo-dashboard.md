# SLO Dashboard — Daddies Padel Platform

## Overview

We track 4 Service Level Objectives (SLOs) using Firebase Analytics custom events and Firebase Performance traces.

## SLO Definitions

| SLO | Target | Latency Target | Analytics Event | Performance Trace |
|-----|--------|---------------|-----------------|-------------------|
| Booking (join/leave) | 99% success | < 5s | `sli_booking_attempt` | `firestore_join_session`, `firestore_leave_session` |
| Payment (verify) | 99% success | < 3s | `sli_payment_attempt` | `firestore_verify_payment` |
| App Load (splash → home) | 95% success | < 5s | `sli_app_load` | — |
| Data Load (Firestore init) | 95% success | < 10s | `sli_data_load` | `data_service_init` |

## How to Check SLOs

### Firebase Console > Analytics > Events

1. Go to [Firebase Console](https://console.firebase.google.com/project/padel-daddies/analytics/events)
2. Find events prefixed with `sli_`
3. Click an event to see parameters:
   - `success`: 1 = success, 0 = failure
   - `latency_ms`: operation duration in milliseconds
   - `error_type` / `failure_reason`: present only on failures

### Calculating Success Rate

For each SLO event, calculate:
```
success_rate = count(success=1) / count(all) * 100
```

Compare against the target in the table above.

### Firebase Console > Performance > Traces

1. Go to [Firebase Console](https://console.firebase.google.com/project/padel-daddies/performance/traces)
2. Look for custom traces:
   - `data_service_init` — Initial data loading
   - `firestore_join_session` — Join session transaction
   - `firestore_leave_session` — Leave session transaction
   - `firestore_verify_payment` — Payment verification transaction
3. Check median and p95 latency against targets

### Firebase Console > Crashlytics

1. Go to [Firebase Console](https://console.firebase.google.com/project/padel-daddies/crashlytics)
2. Review crash-free user rate (target: > 99.5%)
3. Review crash trends and top crash groups

## When to Act

- **SLO breached**: Success rate drops below target → investigate immediately
- **Error budget < 20%**: Approaching target → freeze non-critical changes, focus on reliability
- **Latency p95 > 2x target**: Performance degradation → investigate Firestore queries

## SLO Configuration in Code

Constants are defined in `lib/core/config/slo_config.dart`. Update these if targets change.
