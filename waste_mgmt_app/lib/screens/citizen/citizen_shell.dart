import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/notification_provider.dart';
import '../../core/theme.dart';

class CitizenShell extends StatefulWidget {
  final Widget child;
  final String location;
  const CitizenShell({super.key, required this.child, required this.location});
  @override
  State<CitizenShell> createState() => _CitizenShellState();
}

class _CitizenShellState extends State<CitizenShell> {
  final _destinations = const [
    (path: '/citizen', icon: Icons.dashboard_outlined, activeIcon: Icons.dashboard, label: 'Home'),
    (path: '/citizen/requests', icon: Icons.list_alt_outlined, activeIcon: Icons.list_alt, label: 'Requests'),
    (path: '/citizen/rewards', icon: Icons.stars_outlined, activeIcon: Icons.stars, label: 'Rewards'),
    (path: '/citizen/notifications', icon: Icons.notifications_outlined, activeIcon: Icons.notifications, label: 'Alerts'),
    (path: '/citizen/profile', icon: Icons.person_outline, activeIcon: Icons.person, label: 'Profile'),
  ];

  int _calculateSelectedIndex() {
    final loc = widget.location;
    if (loc.startsWith('/citizen/requests')) return 1;
    if (loc.startsWith('/citizen/rewards')) return 2;
    if (loc.startsWith('/citizen/notifications')) return 3;
    if (loc.startsWith('/citizen/profile')) return 4;
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
