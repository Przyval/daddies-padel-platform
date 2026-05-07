/**
 * Core Web Vitals measurement for Daddies Padel Platform.
 *
 * Captures LCP, INP, CLS, FCP, and TTFB from real users and sends
 * them to Firebase Analytics as custom events.
 *
 * Uses the web-vitals library (https://github.com/GoogleChrome/web-vitals).
 * Loaded via CDN — the library is ~2 KB gzipped.
 */
(function () {
  'use strict';

  // Import web-vitals from CDN (ES module)
  var WEB_VITALS_URL =
    'https://unpkg.com/web-vitals@4/dist/web-vitals.attribution.iife.js';

  function sendToAnalytics(metric) {
    // Only send if Firebase Analytics (gtag) is available
    if (typeof gtag !== 'function') return;

    var params = {
      event_category: 'Web Vitals',
      event_label: metric.id,
      // Google Analytics expects integers for values
      value: Math.round(
        metric.name === 'CLS' ? metric.value * 1000 : metric.value
      ),
      // Custom dimensions
      metric_id: metric.id,
      metric_value: metric.value,
      metric_delta: metric.delta,
      metric_rating: metric.rating, // "good" | "needs-improvement" | "poor"
      // Non-interaction: don't affect bounce rate
      non_interaction: true,
    };

    gtag('event', metric.name, params);
  }

  function init() {
    if (!window.webVitals) return;

    window.webVitals.onLCP(sendToAnalytics);
    window.webVitals.onINP(sendToAnalytics);
    window.webVitals.onCLS(sendToAnalytics);
    window.webVitals.onFCP(sendToAnalytics);
    window.webVitals.onTTFB(sendToAnalytics);
  }

  // Load web-vitals library
  var script = document.createElement('script');
  script.src = WEB_VITALS_URL;
  script.onload = init;
  // Load after main content — low priority
  script.defer = true;
  document.head.appendChild(script);
})();
