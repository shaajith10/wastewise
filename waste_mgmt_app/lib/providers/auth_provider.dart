import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/api_client.dart';

const _sessionTokenKey = 'session_token';

/// Built-in accounts created by the backend on startup (see backend authService.js).
const demoAccounts = {
  'citizen': (email: 'citizen@waste.dev', password: 'citizen123'),
  'collector': (email: 'collector@waste.dev', password: 'collector123'),
  'admin': (email: 'admin@waste.dev', password: 'admin123'),
};

class AuthProvider extends ChangeNotifier {
  Map<String, dynamic>? _profile;
  String? _token;
  bool _loading = false;
  String? _error;

  // ── Getters ────────────────────────────────────────────────────────────────
  bool get isLoggedIn => _token != null && _profile != null;
  bool get loading => _loading;
  String? get error => _error;
  String? get uid => _profile?['uid'] as String?;
  String? get email => _profile?['email'] as String?;
  String? get role => _profile?['role'] as String?;
  String? get displayName => _profile?['displayName'] as String?;
  int get rewardBalance => (_profile?['rewardBalance'] as num?)?.toInt() ?? 0;
  Map<String, dynamic>? get profile => _profile;

  void updateRewardBalance(int newBalance) {
    if (_profile != null) {
      _profile!['rewardBalance'] = newBalance;
      notifyListeners();
    }
  }

  Future<void> _fetchProfile() async {
    try {
      final data = await ApiClient.get('/auth/me');
      _profile = data['user'] as Map<String, dynamic>?;
      _error = null;
    } catch (_) {
      // Keep the current profile on transient errors; restoreSession checks for null.
    }
    _loading = false;
    notifyListeners();
  }

  /// Stores the token + profile returned by /auth/login or /auth/register.
  Future<void> _startSession(Map<String, dynamic> res) async {
    _token = res['token'].toString();
    ApiClient.customToken = _token;
    _profile = Map<String, dynamic>.from(res['user'] as Map);
    await _saveSessionToken(_token);
  }

  /// Runs an auth request, exposing the server's message via [error] and rethrowing on failure.
  Future<void> _authRequest(Future<Map<String, dynamic>> Function() request) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      await _startSession(await request());
    } on ApiException catch (e) {
      _error = e.message;
      rethrow;
    } catch (e) {
      _error = 'Cannot reach the server. Check your connection.';
      rethrow;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  // ── Register ───────────────────────────────────────────────────────────────
  /// Creates a new citizen account (fresh dashboard, 0 points) and logs it in.
  Future<void> register({
    required String email,
    required String password,
    required String displayName,
    required String phone,
  }) {
    return _authRequest(() => ApiClient.post('/auth/register', {
          'displayName': displayName,
          'email': email.trim().toLowerCase(),
          'phone': phone,
          'password': password,
        }, auth: false));
  }

  // ── Login ──────────────────────────────────────────────────────────────────
  Future<void> login({required String email, required String password}) {
    return _authRequest(() => ApiClient.post('/auth/login', {
          'email': email.trim().toLowerCase(),
          'password': password,
        }, auth: false));
  }

  // ── Quick Demo Login ────────────────────────────────────────────────────────
  /// Logs in with one of the built-in accounts (citizen / collector / admin).
  Future<void> demoLogin({required String role}) {
    final acct = demoAccounts[role] ?? demoAccounts['citizen']!;
    return login(email: acct.email, password: acct.password);
  }

  // ── Forgot Password ────────────────────────────────────────────────────────
  Future<void> sendPasswordReset(String email) async {
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
    } catch (_) {}
  }

  // ── Logout ─────────────────────────────────────────────────────────────────
  Future<void> logout() async {
    _token = null;
    _profile = null;
    ApiClient.customToken = null;
    await _saveSessionToken(null);
    notifyListeners();
  }

  // ── Session persistence (survives page reload) ─────────────────────────────
  /// Restores a saved backend session. Call before runApp so the router's first
  /// redirect already sees the user as logged in and keeps the reloaded URL.
  Future<void> restoreSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(_sessionTokenKey);
      if (token == null) return;

      _token = token;
      ApiClient.customToken = token;
      await _fetchProfile();

      if (_profile == null) {
        // Token expired or no longer valid on the server — start fresh at login.
        _token = null;
        ApiClient.customToken = null;
        await prefs.remove(_sessionTokenKey);
      }
    } catch (_) {}
  }

  Future<void> _saveSessionToken(String? token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (token == null) {
        await prefs.remove(_sessionTokenKey);
      } else {
        await prefs.setString(_sessionTokenKey, token);
      }
    } catch (_) {}
  }

  // ── Update FCM Token ───────────────────────────────────────────────────────
  Future<void> updateFcmToken(String token) async {
    try {
      await ApiClient.patch('/auth/fcm-token', {'fcmToken': token});
    } catch (_) {}
  }

  // ── Refresh Profile ────────────────────────────────────────────────────────
  Future<void> refreshProfile() async {
    if (isLoggedIn) {
      await _fetchProfile();
    }
  }
}
