import 'dart:async';

import 'package:flutter/material.dart';

import 'package:daddies_app/core/resilience/circuit_breaker.dart';
import 'package:daddies_app/core/resilience/bulkhead.dart';

/// Graceful degradation widget — shows a friendly error with retry.
///
/// Release It! Ch.10: "Partially broken is the normal state at scale."
/// Instead of crashing or showing a generic error, degrade gracefully
/// with context-appropriate messages and recovery actions.
class GracefulError extends StatelessWidget {
  final Object error;
  final VoidCallback? onRetry;
  final Widget? fallback;

  const GracefulError({
    super.key,
    required this.error,
    this.onRetry,
    this.fallback,
  });

  @override
  Widget build(BuildContext context) {
    final (icon, title, subtitle) = _classify(error);

    if (fallback != null) return fallback!;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                  ),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Coba Lagi'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  (IconData, String, String) _classify(Object error) {
    if (error is CircuitBreakerOpenException) {
      return (
        Icons.cloud_off,
        'Server Sedang Bermasalah',
        'Koneksi ke server terganggu. Coba lagi dalam beberapa saat.',
      );
    }
    if (error is BulkheadRejectedException) {
      return (
        Icons.hourglass_top,
        'Terlalu Banyak Permintaan',
        'Server sedang sibuk. Tunggu sebentar lalu coba lagi.',
      );
    }
    if (error is TimeoutException) {
      return (
        Icons.timer_off,
        'Waktu Habis',
        'Server terlalu lama merespons. Periksa koneksi internet kamu.',
      );
    }
    return (
      Icons.error_outline,
      'Terjadi Kesalahan',
      'Sesuatu tidak berjalan dengan baik. Coba lagi nanti.',
    );
  }
}
