import 'dart:async';

import 'package:flutter/material.dart';
import 'package:daddies_app/core/theme/app_colors.dart';

/// Generic wrapper that loads a deferred library before showing [builder]'s widget.
///
/// While the library is loading, a minimal themed spinner is shown.
/// On failure, a retry button is shown.
class DeferredLoader extends StatefulWidget {
  const DeferredLoader({
    super.key,
    required this.loadLibrary,
    required this.builder,
  });

  /// The `loadLibrary()` call for the deferred import.
  final Future<void> Function() loadLibrary;

  /// Called once the library has been loaded to build the actual screen.
  final WidgetBuilder builder;

  @override
  State<DeferredLoader> createState() => _DeferredLoaderState();
}

class _DeferredLoaderState extends State<DeferredLoader> {
  late Future<void> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.loadLibrary();
  }

  void _retry() {
    setState(() {
      _future = widget.loadLibrary();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done &&
            !snapshot.hasError) {
          return widget.builder(context);
        }
        if (snapshot.hasError) {
          return Scaffold(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.cloud_off, size: 48, color: AppColors.mossAccent),
                  const SizedBox(height: 16),
                  Text(
                    'Gagal memuat halaman',
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton.icon(
                    onPressed: _retry,
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Coba lagi'),
                  ),
                ],
              ),
            ),
          );
        }
        // Loading state
        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          body: const Center(
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        );
      },
    );
  }
}
