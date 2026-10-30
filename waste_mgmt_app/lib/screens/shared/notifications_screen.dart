import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/notification_provider.dart';
import '../../core/theme.dart';
import '../../widgets/common_widgets.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => context.read<NotificationProvider>().fetchNotifications());
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NotificationProvider>();
    final notifications = provider.notifications;
    final loading = provider.loading;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (notifications.isNotEmpty)
            TextButton(
              onPressed: () => provider.markAllRead(),
              child: const Text('Mark all read', style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
      body: loading
        ? const LoadingWidget()
        : notifications.isEmpty
          ? const EmptyStateWidget(
              icon: Icons.notifications_none,
              title: 'No notifications',
              subtitle: 'Status updates and system announcements will appear here.',
            )
          : RefreshIndicator(
              onRefresh: () => provider.fetchNotifications(),
              child: ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: notifications.length,
                itemBuilder: (_, i) {
                  final n = notifications[i];
                  final isRead = n['read'] == true;
                  return Card(
                    color: isRead ? Colors.white : const Color(0xFFE8F5E9),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: isRead ? Colors.grey.shade200 : AppTheme.primary.withOpacity(0.2),
                        child: Icon(
                          _getIcon(n['type']),
                          color: isRead ? Colors.grey : AppTheme.primary,
                        ),
                      ),
                      title: Text(
                        n['title'] ?? 'Notification',
                        style: TextStyle(fontWeight: isRead ? FontWeight.normal : FontWeight.bold),
                      ),
                      subtitle: Text(n['body'] ?? ''),
                      onTap: () {
                        if (!isRead && n['id'] != null) {
                          provider.markRead(n['id']);
                        }
                      },
                    ),
                  );
                },
              ),
            ),
    );
  }

  IconData _getIcon(String? type) {
    switch (type) {
      case 'verified': return Icons.verified;
      case 'status_updated': return Icons.update;
      case 'task_assigned': return Icons.assignment_ind;
      default: return Icons.notifications;
    }
  }
}
