# Web Performance Guide — Daddies Padel Platform

Based on "Web Performance Engineering in the Age of AI" (Addy Osmani, O'Reilly 2026).

## Architecture Overview

This is a **Flutter Web** app using the **CanvasKit renderer** (renders to `<canvas>`, not DOM). This means standard DOM-based web performance techniques (CSS optimization, HTML semantics, React-style component optimization) do not directly apply. Instead, performance focus is on:

1. **Initial load** — CanvasKit WASM + Dart JS bundle download
2. **Network latency** — Firestore reads, Firebase Storage images
3. **Runtime rendering** — Flutter's own compositor and Skia engine
4. **Caching** — HTTP cache, service worker, in-memory DataService cache

## Core Web Vitals Targets (SLO)

| Metric | Target (p75) | What It Measures |
|--------|:------------:|------------------|
| LCP    | < 2.5s       | Time to largest content painted (canvas render) |
| INP    | < 200ms      | Responsiveness to user interactions |
| CLS    | < 0.1        | Visual stability during load |
| FCP    | < 1.8s       | Time to first content painted |
| TTFB   | < 800ms      | Server response time |

### Monitoring CWVs

CWVs are captured automatically via `web/js/web-vitals-init.js` and sent to Firebase Analytics.

**To check in Firebase Console:**
1. Go to **Analytics > Events**
2. Look for events: `LCP`, `INP`, `CLS`, `FCP`, `TTFB`
3. Each event has parameters: `metric_value`, `metric_rating` (good/needs-improvement/poor)

**To check in Chrome DevTools:**
1. Open DevTools > **Performance** tab
2. Record a page load
3. Check the "Web Vitals" lane for LCP, CLS, INP markers

## Performance Optimizations Implemented

### 1. Resource Hints (web/index.html)

```html
<link rel="preconnect" href="https://firestore.googleapis.com" crossorigin>
<link rel="preconnect" href="https://firebasestorage.googleapis.com" crossorigin>
```

Saves 200-500ms per connection by establishing TLS handshakes early.

### 2. Pre-Flutter Loading Screen (web/index.html)

A CSS-only loading screen shows immediately while Flutter's CanvasKit WASM (6.8MB) loads. Without this, users see a blank white screen for 3-5 seconds on slower connections.

The loading screen is removed automatically when Flutter fires `flutter-first-frame`.

### 3. Deferred Loading (lib/core/router/app_router.dart)

Six specialized screens use Dart's `deferred as` imports:
- LeaderboardScreen
- VenueDetailScreen
- PlayerStatsScreen
- KtaDigitalScreen
- PartnerListScreen
- MatchScoringScreen

This splits the main.dart.js bundle so these screens load on-demand only when navigated to.

### 4. HTTP Cache Strategy (firebase.json)

| Asset Type | Cache Duration | Rationale |
|-----------|:-------------:|-----------|
| JS, CSS, WASM, WOFF2 | 1 year (immutable) | Content-hashed, changes = new URL |
| Images (PNG, JPG, etc.) | 7 days | User-uploaded content may update |
| JSON (manifest, Lottie) | 1 day | Infrequent changes |
| flutter_bootstrap.js | 1 hour | References change on each build |
| index.html | no-cache | Entry point, always revalidate |

### 5. Security Headers (firebase.json)

All responses include:
- `X-Content-Type-Options: nosniff`
- `X-Frame-Options: SAMEORIGIN`
- `Referrer-Policy: strict-origin-when-cross-origin`

### 6. Bundle Size Budget (CI)

The CI pipeline enforces:
- `main.dart.js` < 6 MB
- `canvaskit.wasm` < 8 MB

Build fails if budget is exceeded. Check current sizes:
```bash
ls -lh build/web/main.dart.js
ls -lh build/web/canvaskit/canvaskit.wasm
```

### 7. Image Loading Optimization

All `CachedNetworkImage` instances use:
- Shimmer/placeholder while loading
- Error widgets on failure
- `memCacheWidth`/`memCacheHeight` to limit decoded image memory
- `fadeInDuration` for smooth appearance

### 8. Offline Resilience

- `ConnectivityService` monitors network state
- `DataService` maintains in-memory cache for instant reads
- Offline banner shown when connection lost
- Session data available offline via local cache
- `SharedPreferences` persists user preferences locally

## Performance Budget Guidelines

When adding new features:

1. **Dependencies**: Before adding a new package to `pubspec.yaml`, check its size impact. Run `flutter build web --release` before and after to compare `main.dart.js` size.

2. **Images**: Use Firebase Storage with appropriate sizing. Avoid uploading full-resolution photos; resize before upload if possible.

3. **Deferred loading**: For any new feature screen that isn't part of the core flow (splash → home → sessions), use `deferred as` imports.

4. **Network calls**: Batch Firestore reads when possible. Use the in-memory cache in DataService for reads; only hit Firestore for writes.

## Troubleshooting

### Slow initial load
1. Check network tab for large assets
2. Verify preconnect hints are working (check timing in DevTools)
3. Ensure Cache-Control headers are being served correctly
4. Test on throttled network (DevTools > Network > Slow 3G)

### High INP
1. Profile with DevTools Performance tab
2. Look for long tasks during user interactions
3. Check if data transformations are blocking the UI thread

### High CLS
1. Check if images load without explicit dimensions
2. Verify loading states don't cause layout jumps
3. Test on slow network where content loads progressively

## Monthly Performance Review Checklist

- [ ] Check Firebase Analytics for CWV event trends
- [ ] Review Firebase Performance traces for latency regressions
- [ ] Verify bundle sizes haven't grown unexpectedly
- [ ] Test on a low-end Android device (Chrome)
- [ ] Review any new third-party dependencies for size impact
