import 'package:flutter/material.dart';
import '../core/api_client.dart';

class NotificationProvider extends ChangeNotifier {
  List<Map<String, dynamic>> _notifications = [];
  bool _loading = false;
  int _unreadCount = 0;

  List<Map<String, dynamic>> get notifications => _notifications;
  bool get loading => _loading;
  int get unreadCount => _unreadCount;

  Future<void> fetchNotifications() async {
    _loading = true;
    notifyListeners();
    try {
      final data = await ApiClient.get('/notifications');
      _notifications = List<Map<String, dynamic>>.from(data['notifications'] ?? []);
      _unreadCount = _notifications.where((n) => n['read'] == false).length;
    } catch (_) {}
    _loading = false;
    notifyListeners();
  }

  Future<void> markRead(String id) async {
    try {
      await ApiClient.patch('/notifications/$id/read', {});
      final idx = _notifications.indexWhere((n) => n['id'] == id);
      if (idx != -1) {
        _notifications[idx] = {..._notifications[idx], 'read': true};
        _unreadCount = _notifications.where((n) => n['read'] == false).length;
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> markAllRead() async {
    try {
      await ApiClient.patch('/notifications/read-all', {});
      _notifications = _notifications.map((n) => {...n, 'read': true}).toList();
      _unreadCount = 0;
      notifyListeners();
    } catch (_) {}
  }
}
