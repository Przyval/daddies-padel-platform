import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Exposes a [ValueNotifier<bool>] that tracks whether the device is online.
class ConnectivityService {
  ConnectivityService._();
  static final ConnectivityService instance = ConnectivityService._();

  final ValueNotifier<bool> isOnline = ValueNotifier(true);

  StreamSubscription<List<ConnectivityResult>>? _sub;

  void initialize() {
    _sub?.cancel();
    // Check initial state
    Connectivity().checkConnectivity().then(_update);
    // Listen for changes
    _sub = Connectivity().onConnectivityChanged.listen(_update);
  }

  void _update(List<ConnectivityResult> results) {
    final connected =
        results.any((r) => r != ConnectivityResult.none);
    if (isOnline.value != connected) {
      isOnline.value = connected;
    }
  }

  void dispose() {
    _sub?.cancel();
    _sub = null;
  }
}
