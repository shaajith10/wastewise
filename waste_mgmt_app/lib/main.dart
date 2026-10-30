import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'core/api_client.dart';
import 'core/router.dart';
import 'core/theme.dart';
import 'providers/auth_provider.dart';
import 'providers/notification_provider.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // firebase_options.dart holds placeholder values; the app runs on the backend's
  // own login, so don't let a Firebase init failure crash the app on startup.
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  } catch (e) {
    debugPrint('[Firebase] init skipped: $e');
  }
  await ApiClient.loadServerOverride();
  final auth = AuthProvider();
  await auth.restoreSession();
  runApp(WasteMgmtApp(auth: auth));
}

class WasteMgmtApp extends StatefulWidget {
  final AuthProvider auth;
  const WasteMgmtApp({super.key, required this.auth});

  @override
  State<WasteMgmtApp> createState() => _WasteMgmtAppState();
}

class _WasteMgmtAppState extends State<WasteMgmtApp> {
  // Router is created once; it re-runs redirects via refreshListenable when auth changes.
  // Rebuilding it on every auth notification reset navigation back to /splash.
  late final _auth = widget.auth;
  late final _router = AppRouter.createRouter(_auth);

  @override
  void dispose() {
    _router.dispose();
    _auth.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _auth),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
      ],
      child: MaterialApp.router(
        title: 'WasteWise',
        theme: AppTheme.lightTheme,
        debugShowCheckedModeBanner: false,
        routerConfig: _router,
      ),
    );
  }
}
