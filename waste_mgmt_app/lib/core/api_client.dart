import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiClient {
  static String? customToken;

  // Phones can't reach "localhost" on the laptop. Build with:
  //   flutter build apk --dart-define=API_URL=http://<laptop-ip>:3000/api
  // Default 10.0.2.2 is the Android emulator's alias for the host machine.
  static const _apiUrl = String.fromEnvironment('API_URL', defaultValue: 'http://10.0.2.2:3000/api');
  static const _serverUrlKey = 'server_url';

  /// Set from the login screen's "Server address" dialog so the laptop IP can
  /// change (new Wi-Fi) without rebuilding the APK.
  static String? serverOverride;

  static String get baseUrl {
    if (kIsWeb) {
      return '/api';
    }
    return serverOverride ?? _apiUrl;
  }

  static Future<void> loadServerOverride() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      serverOverride = prefs.getString(_serverUrlKey);
    } catch (_) {}
  }

  static Future<void> setServerOverride(String url) async {
    var clean = url.trim();
    if (clean.endsWith('/')) clean = clean.substring(0, clean.length - 1);
    if (!clean.startsWith('http')) clean = 'http://$clean';
    if (!clean.endsWith('/api')) clean = '$clean/api';
    serverOverride = clean;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_serverUrlKey, clean);
  }

  static Future<String?> _getToken() async {
    if (customToken != null) return customToken;
    try {
      final user = FirebaseAuth.instance.currentUser;
      return await user?.getIdToken();
    } catch (_) {
      return null;
    }
  }

  /// True if the backend's /health endpoint answers.
  static Future<bool> ping() async {
    try {
      final healthUrl = baseUrl.replaceFirst(RegExp(r'/api$'), '/health');
      final res = await http.get(Uri.parse(healthUrl)).timeout(const Duration(seconds: 5));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  static Future<Map<String, String>> _headers({bool auth = true}) async {
    final headers = {
      'Content-Type': 'application/json',
      'Cache-Control': 'no-cache',
      'Pragma': 'no-cache',
    };
    if (auth) {
      final token = await _getToken();
      if (token != null) headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  static Future<Map<String, dynamic>> get(String path) async {
    final response = await http.get(
      Uri.parse('$baseUrl$path'),
      headers: await _headers(),
    ).timeout(const Duration(seconds: 15));
    return _parse(response);
  }

  static Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body, {
    bool auth = true,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl$path'),
      headers: await _headers(auth: auth),
      body: jsonEncode(body),
    ).timeout(const Duration(seconds: 15));
    return _parse(response);
  }

  static Future<Map<String, dynamic>> patch(
    String path,
    Map<String, dynamic> body,
  ) async {
    final response = await http.patch(
      Uri.parse('$baseUrl$path'),
      headers: await _headers(),
      body: jsonEncode(body),
    ).timeout(const Duration(seconds: 15));
    return _parse(response);
  }

  static Future<Map<String, dynamic>> delete(String path) async {
    final response = await http.delete(
      Uri.parse('$baseUrl$path'),
      headers: await _headers(),
    ).timeout(const Duration(seconds: 15));
    return _parse(response);
  }

  static Map<String, dynamic> _parse(http.Response response) {
    final raw = response.body.trim();
    if (raw.isEmpty) {
      if (response.statusCode >= 400) {
        throw ApiException('Request failed (${response.statusCode})', statusCode: response.statusCode);
      }
      return {};
    }

    try {
      final decoded = jsonDecode(raw);
      if (response.statusCode >= 400) {
        final errorMsg = (decoded is Map && decoded['error'] != null)
            ? decoded['error'].toString()
            : 'Request failed (${response.statusCode})';
        throw ApiException(errorMsg, statusCode: response.statusCode);
      }
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      return {'data': decoded};
    } catch (e) {
      if (e is ApiException) rethrow;
      if (response.statusCode >= 400) {
        throw ApiException('Server error (${response.statusCode})', statusCode: response.statusCode);
      }
      return {};
    }
  }
}

class ApiException implements Exception {
  final String message;
  final int statusCode;
  const ApiException(this.message, {required this.statusCode});

  @override
  String toString() => 'ApiException($statusCode): $message';
}
