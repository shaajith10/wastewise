import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/notification_provider.dart';
import '../../core/theme.dart';

class CollectorShell extends StatefulWidget {
  final Widget child;
  final String location;
  const CollectorShell({super.key, required this.child, required this.location});

  @override
  State<CollectorShell> createState() => _CollectorShellState();
}

class _CollectorShellState extends State<CollectorShell> {
  final _destinations = const [
    (path: '/collector', icon: Icons.assignment_outlined, activeIcon: Icons.assignment, label: 'Tasks'),
    (path: '/collector/scan', icon: Icons.qr_code_scanner_outlined, activeIcon: Icons.qr_code_scanner, label: 'Scan QR'),
    (path: '/collector/history', icon: Icons.history_outlined, activeIcon: Icons.history, label: 'History'),
    (path: '/collector/notifications', icon: Icons.notifications_outlined, activeIcon: Icons.notifications, label: 'Alerts'),
  ];

  int _calculateSelectedIndex() {
    final loc = widget.location;
    if (loc.startsWith('/collector/scan')) return 1;
    if (loc.startsWith('/collector/history')) return 2;
    if (loc.startsWith('/collector/notifications')) return 3;
    return 0;
  }

  @override
  void initState() {
    super.initState();
    Future.microtask(() => context.read<NotificationProvider>().fetchNotifications());
  }

  @override
  Widget build(BuildContext context) {
    final unread = context.watch<NotificationProvider>().unreadCount;
    final currentIndex = _calculateSelectedIndex();

    return Scaffold(
      body: widget.child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: (i) {
          context.go(_destinations[i].path);
        },
        destinations: _destinations.asMap().entries.map((e) {
          final d = e.value;
          final isAlert = d.label == 'Alerts';
          return NavigationDestination(
            icon: isAlert && unread > 0
              ? Badge(label: Text('$unread'), child: Icon(d.icon))
              : Icon(d.icon),
            selectedIcon: Icon(d.activeIcon, color: AppTheme.primary),
            label: d.label,
          );
        }).toList(),
        backgroundColor: Colors.white,
        indicatorColor: const Color(0xFFE8F5E9),
      ),
    );
  }
}
