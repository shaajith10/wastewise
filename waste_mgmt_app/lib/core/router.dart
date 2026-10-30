import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';

// Auth
import '../screens/auth/splash_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/auth/forgot_password_screen.dart';

// Citizen
import '../screens/citizen/citizen_shell.dart';
import '../screens/citizen/citizen_dashboard.dart';
import '../screens/citizen/submit_request_screen.dart';
import '../screens/citizen/my_requests_screen.dart';
import '../screens/citizen/request_detail_screen.dart';
import '../screens/citizen/qr_display_screen.dart';
import '../screens/citizen/recycling_history_screen.dart';
import '../screens/citizen/rewards_screen.dart';
import '../screens/citizen/citizen_profile_screen.dart';
import '../screens/shared/notifications_screen.dart';

// Collector
import '../screens/collector/collector_shell.dart';
import '../screens/collector/collector_dashboard.dart';
import '../screens/collector/task_detail_screen.dart';
import '../screens/collector/qr_scanner_screen.dart';
import '../screens/collector/collector_history_screen.dart';

// Admin
import '../screens/admin/admin_shell.dart';
import '../screens/admin/admin_dashboard.dart';
import '../screens/admin/manage_requests_screen.dart';
import '../screens/admin/manage_users_screen.dart';
import '../screens/admin/manage_collectors_screen.dart';
import '../screens/admin/manage_categories_screen.dart';
import '../screens/admin/reward_rules_screen.dart';
import '../screens/admin/admin_reports_screen.dart';

class AppRouter {
  static GoRouter createRouter(AuthProvider auth) {
    return GoRouter(
      initialLocation: '/splash',
      refreshListenable: auth,
      redirect: (context, state) {
        final loggedIn = auth.isLoggedIn;
        final role = auth.role;
        final loc = state.matchedLocation;

        final isAuthRoute = loc.startsWith('/login') ||
            loc.startsWith('/register') ||
            loc.startsWith('/forgot') ||
            loc == '/splash';
        final isSplash = loc == '/splash';

        if (isSplash) return null; // Let splash decide
        if (!loggedIn && !isAuthRoute) return '/login';
        if (loggedIn && isAuthRoute) {
          return _homeForRole(role);
        }
        return null;
      },
      routes: [
        GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
        GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
        GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),
        GoRoute(path: '/forgot-password', builder: (_, __) => const ForgotPasswordScreen()),

        // ── Citizen Shell ─────────────────────────────────────────────────────
        ShellRoute(
          builder: (_, state, child) => CitizenShell(location: state.matchedLocation, child: child),
          routes: [
            GoRoute(path: '/citizen', builder: (_, __) => const CitizenDashboard()),
            GoRoute(path: '/citizen/submit', builder: (_, __) => const SubmitRequestScreen()),
            GoRoute(path: '/citizen/requests', builder: (_, __) => const MyRequestsScreen()),
            GoRoute(
              path: '/citizen/requests/:id',
              builder: (_, state) => RequestDetailScreen(requestId: state.pathParameters['id']!),
            ),
            GoRoute(
              path: '/citizen/requests/:id/qr',
              builder: (_, state) => QrDisplayScreen(requestId: state.pathParameters['id']!),
            ),
            GoRoute(path: '/citizen/recycling', builder: (_, __) => const RecyclingHistoryScreen()),
            GoRoute(path: '/citizen/rewards', builder: (_, __) => const RewardsScreen()),
            GoRoute(path: '/citizen/profile', builder: (_, __) => const CitizenProfileScreen()),
            GoRoute(path: '/citizen/notifications', builder: (_, __) => const NotificationsScreen()),
          ],
        ),

        // ── Collector Shell ───────────────────────────────────────────────────
        ShellRoute(
          builder: (_, state, child) => CollectorShell(location: state.matchedLocation, child: child),
          routes: [
            GoRoute(path: '/collector', builder: (_, __) => const CollectorDashboard()),
            GoRoute(
              path: '/collector/tasks/:id',
              builder: (_, state) => TaskDetailScreen(requestId: state.pathParameters['id']!),
            ),
            GoRoute(path: '/collector/scan', builder: (_, __) => const QrScannerScreen()),
            GoRoute(path: '/collector/history', builder: (_, __) => const CollectorHistoryScreen()),
            GoRoute(path: '/collector/notifications', builder: (_, __) => const NotificationsScreen()),
          ],
        ),

        // ── Admin Shell ───────────────────────────────────────────────────────
        ShellRoute(
          builder: (_, state, child) => AdminShell(location: state.matchedLocation, child: child),
          routes: [
            GoRoute(path: '/admin', builder: (_, __) => const AdminDashboard()),
            GoRoute(path: '/admin/requests', builder: (_, __) => const ManageRequestsScreen()),
            GoRoute(path: '/admin/users', builder: (_, __) => const ManageUsersScreen()),
            GoRoute(path: '/admin/collectors', builder: (_, __) => const ManageCollectorsScreen()),
            GoRoute(path: '/admin/categories', builder: (_, __) => const ManageCategoriesScreen()),
            GoRoute(path: '/admin/reward-rules', builder: (_, __) => const RewardRulesScreen()),
            GoRoute(path: '/admin/reports', builder: (_, __) => const AdminReportsScreen()),
            GoRoute(path: '/admin/notifications', builder: (_, __) => const NotificationsScreen()),
          ],
        ),
      ],
    );
  }

  static String _homeForRole(String? role) {
    switch (role) {
      case 'collector': return '/collector';
      case 'admin': return '/admin';
      default: return '/citizen';
    }
  }
}
