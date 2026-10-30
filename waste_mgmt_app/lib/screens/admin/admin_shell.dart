import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/notification_provider.dart';
import '../../core/theme.dart';

class AdminShell extends StatefulWidget {
  final Widget child;
  final String location;
  const AdminShell({super.key, required this.child, required this.location});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  final _destinations = const [
    (path: '/admin', icon: Icons.dashboard_outlined, activeIcon: Icons.dashboard, label: 'Dashboard'),
    (path: '/admin/requests', icon: Icons.list_alt_outlined, activeIcon: Icons.list_alt, label: 'Requests'),
    (path: '/admin/users', icon: Icons.people_outline, activeIcon: Icons.people, label: 'Users'),
    (path: '/admin/collectors', icon: Icons.local_shipping_outlined, activeIcon: Icons.local_shipping, label: 'Collectors'),
    (path: '/admin/reports', icon: Icons.bar_chart_outlined, activeIcon: Icons.bar_chart, label: 'Reports'),
  ];

  int _calculateSelectedIndex() {
    final loc = widget.location;
    if (loc.startsWith('/admin/requests')) return 1;
    if (loc.startsWith('/admin/users')) return 2;
    if (loc.startsWith('/admin/collectors')) return 3;
    if (loc.startsWith('/admin/reports')) return 4;
    return 0;
  }

  @override
  void initState() {
    super.initState();
    Future.microtask(() => context.read<NotificationProvider>().fetchNotifications());
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = _calculateSelectedIndex();

    return Scaffold(
      body: widget.child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: (i) {
          context.go(_destinations[i].path);
        },
        destinations: _destinations.map((d) {
          return NavigationDestination(
            icon: Icon(d.icon),
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
