import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:daddies_app/models/notification_model.dart';
import 'package:daddies_app/core/services/app_logger.dart';
import 'package:daddies_app/core/router/app_router.dart';

class NotificationService extends ChangeNotifier {
  static final NotificationService instance = NotificationService._();
  NotificationService._();

  static const _tag = 'NotificationService';
  static const _storageKey = 'notifications_v1';

  final List<NotificationModel> _notifications = [];
  List<NotificationModel> get notifications => List.unmodifiable(_notifications);
  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  String? _fcmToken;
  String? get fcmToken => _fcmToken;

  Future<void> initialize() async {
    await _loadFromStorage();
    // FCM requires native platform or web service worker — skip on web
    if (kIsWeb) return;
    try {
      await _setupFCM().timeout(const Duration(seconds: 8));
    } catch (e) {
      AppLogger.w(_tag, 'FCM setup timed out or failed', error: e);
    }
  }

  Future<void> _setupFCM() async {
    try {
      final messaging = FirebaseMessaging.instance;

      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        _fcmToken = await messaging.getToken();
        AppLogger.i(_tag, 'FCM token: ${_fcmToken?.substring(0, 20)}...');

        // Listen for token refresh
        messaging.onTokenRefresh.listen((token) {
          _fcmToken = token;
          AppLogger.i(_tag, 'FCM token refreshed');
        });

        // Foreground messages
        FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

        // Background/terminated tap
        FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageTap);

        // Check if app was opened from a notification
        final initialMessage = await messaging.getInitialMessage();
        if (initialMessage != null) {
          _handleMessageTap(initialMessage);
        }
      } else {
        AppLogger.w(_tag, 'Notification permission denied');
      }
    } catch (e) {
      AppLogger.e(_tag, 'FCM setup failed', error: e);
    }
  }

  void _handleForegroundMessage(RemoteMessage message) {
    AppLogger.i(_tag, 'Foreground message: ${message.notification?.title}');
    final notification = _remoteToModel(message);
    addNotification(notification);
  }

  void _handleMessageTap(RemoteMessage message) {
    AppLogger.i(_tag, 'Message tapped: ${message.notification?.title}');
    final data = message.data;
    final sessionId = data['sessionId'] as String?;
    if (sessionId != null && sessionId.isNotEmpty && globalRouter != null) {
      globalRouter!.push(AppRoutes.sessionDetailPath(sessionId));
    } else if (globalRouter != null) {
      globalRouter!.push(AppRoutes.notificationCenter);
    }
  }

  NotificationModel _remoteToModel(RemoteMessage message) {
    final data = message.data;
    return NotificationModel(
      id: message.messageId ?? const Uuid().v4(),
      title: message.notification?.title ?? data['title'] as String? ?? '',
      body: message.notification?.body ?? data['body'] as String? ?? '',
      type: NotificationModel.fromJson(
              {'type': data['type'] ?? 'general'}).type,
      sessionId: data['sessionId'] as String?,
      createdAt: DateTime.now(),
    );
  }

  // Local notification creation (used by the app itself)
  void addNotification(NotificationModel notification) {
    _notifications.insert(0, notification);
    // Keep max 50 notifications
    if (_notifications.length > 50) {
      _notifications.removeRange(50, _notifications.length);
    }
    _saveToStorage();
    notifyListeners();
  }

  void pushLocal({
    required String title,
    required String body,
    required NotificationType type,
    String? sessionId,
  }) {
    addNotification(NotificationModel(
      id: const Uuid().v4(),
      title: title,
      body: body,
      type: type,
      sessionId: sessionId,
      createdAt: DateTime.now(),
    ));
  }

  void markAsRead(String id) {
    final idx = _notifications.indexWhere((n) => n.id == id);
    if (idx != -1) {
      _notifications[idx] = _notifications[idx].copyWith(isRead: true);
      _saveToStorage();
      notifyListeners();
    }
  }

  void markAllAsRead() {
    for (int i = 0; i < _notifications.length; i++) {
      if (!_notifications[i].isRead) {
        _notifications[i] = _notifications[i].copyWith(isRead: true);
      }
    }
    _saveToStorage();
    notifyListeners();
  }

  void clearAll() {
    _notifications.clear();
    _saveToStorage();
    notifyListeners();
  }

  // Persistence
  Future<void> _loadFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw != null) {
        final list = jsonDecode(raw) as List;
        _notifications.clear();
        for (final item in list) {
          _notifications.add(
            NotificationModel.fromJson(item as Map<String, dynamic>),
          );
        }
        notifyListeners();
      }
    } catch (e) {
      AppLogger.w(_tag, 'Failed to load notifications', error: e);
    }
  }

  Future<void> _saveToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = _notifications.map((n) => n.toJson()).toList();
      await prefs.setString(_storageKey, jsonEncode(data));
    } catch (e) {
      AppLogger.w(_tag, 'Failed to save notifications', error: e);
    }
  }
}
