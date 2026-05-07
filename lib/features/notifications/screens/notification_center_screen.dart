import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:daddies_app/core/router/app_router.dart';
import 'package:daddies_app/core/services/notification_service.dart';
import 'package:daddies_app/core/widgets/empty_state.dart';
import 'package:daddies_app/models/notification_model.dart';
import 'package:daddies_app/services/data_service.dart';

class NotificationCenterScreen extends StatefulWidget {
  const NotificationCenterScreen({super.key});

  @override
  State<NotificationCenterScreen> createState() =>
      _NotificationCenterScreenState();
}

class _NotificationCenterScreenState extends State<NotificationCenterScreen> {
  @override
  void initState() {
    super.initState();
    NotificationService.instance.addListener(_onUpdate);
  }

  @override
  void dispose() {
    NotificationService.instance.removeListener(_onUpdate);
    super.dispose();
  }

  void _onUpdate() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final svc = NotificationService.instance;
    final items = svc.notifications;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifikasi'),
        actions: [
          if (items.isNotEmpty)
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'read_all') {
                  svc.markAllAsRead();
                } else if (value == 'clear') {
                  svc.clearAll();
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'read_all',
                  child: Text('Tandai semua dibaca'),
                ),
                const PopupMenuItem(
                  value: 'clear',
                  child: Text('Hapus semua'),
                ),
              ],
            ),
        ],
      ),
      body: RefreshIndicator(
        color: Theme.of(context).colorScheme.primary,
        onRefresh: () => DataService().refresh(),
        child: items.isEmpty
          ? ListView(
              children: const [
                SizedBox(height: 80),
                EmptyStateWidget(
                  icon: Icons.notifications_off_outlined,
                  title: 'Belum ada notifikasi',
                  subtitle: 'Pemberitahuan akan muncul di sini',
                  useLottie: true,
                ),
              ],
            )
          : ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: items.length,
              separatorBuilder: (_, _) => Divider(
                height: 1,
                indent: 72,
                color: colorScheme.outlineVariant.withValues(alpha: 0.3),
              ),
              itemBuilder: (context, index) {
                final n = items[index];
                return _NotificationTile(
                  notification: n,
                  colorScheme: colorScheme,
                  onTap: () {
                    svc.markAsRead(n.id);
                    if (n.sessionId != null && n.sessionId!.isNotEmpty) {
                      context.push(
                        AppRoutes.sessionDetailPath(n.sessionId!),
                      );
                    }
                  },
                );
              },
            ),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final NotificationModel notification;
  final ColorScheme colorScheme;
  final VoidCallback onTap;

  const _NotificationTile({
    required this.notification,
    required this.colorScheme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final icon = _iconForType(notification.type);
    final iconColor = _colorForType(notification.type, colorScheme);
    final age = _formatAge(notification.createdAt);

    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, size: 22, color: iconColor),
      ),
      title: Text(
        notification.title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: notification.isRead ? FontWeight.w500 : FontWeight.w700,
          color: colorScheme.onSurface,
        ),
      ),
      subtitle: Text(
        notification.body,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 12,
          color: colorScheme.onSurface.withValues(alpha: 0.6),
        ),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            age,
            style: TextStyle(
              fontSize: 11,
              color: colorScheme.onSurface.withValues(alpha: 0.4),
            ),
          ),
          if (!notification.isRead) ...[
            const SizedBox(height: 6),
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: colorScheme.primary,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ],
      ),
    );
  }

  IconData _iconForType(NotificationType type) {
    return switch (type) {
      NotificationType.sessionCreated => Icons.add_circle_outline,
      NotificationType.paymentVerified => Icons.check_circle_outline,
      NotificationType.paymentRejected => Icons.cancel_outlined,
      NotificationType.sessionLocked => Icons.lock_outline,
      NotificationType.sessionCompleted => Icons.emoji_events_outlined,
      NotificationType.sessionCancelled => Icons.event_busy_outlined,
      NotificationType.waitlistPromoted => Icons.arrow_upward,
      NotificationType.sessionInvite => Icons.person_add_outlined,
      NotificationType.reminder => Icons.alarm_outlined,
      NotificationType.general => Icons.notifications_outlined,
    };
  }

  Color _colorForType(NotificationType type, ColorScheme cs) {
    return switch (type) {
      NotificationType.paymentVerified ||
      NotificationType.sessionCompleted ||
      NotificationType.waitlistPromoted =>
        const Color(0xFF4A7C59),
      NotificationType.paymentRejected ||
      NotificationType.sessionCancelled =>
        const Color(0xFFA3543A),
      NotificationType.reminder => const Color(0xFFD4A843),
      _ => cs.primary,
    };
  }

  String _formatAge(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'Baru saja';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}j';
    if (diff.inDays < 7) return '${diff.inDays}h';
    return '${date.day}/${date.month}';
  }
}
