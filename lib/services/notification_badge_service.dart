import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

/// Simple notification badge counter service
/// Stores unread notification count in local preferences
/// Provides real-time stream updates when count changes
class NotificationBadgeService {
  static const String _unreadCountKey = 'notification_unread_count';
  static const String _lastCheckKey = 'notification_last_check';

  // Singleton instance untuk stream
  static final NotificationBadgeService _instance =
      NotificationBadgeService._internal();

  late StreamController<int> _countController;

  NotificationBadgeService._internal() {
    _countController = StreamController<int>.broadcast();
  }

  factory NotificationBadgeService() {
    return _instance;
  }

  /// Stream of unread notification count changes (real-time)
  static Stream<int> get countStream {
    return _instance._countController.stream;
  }

  /// Get current unread notification count
  static Future<int> getUnreadCount() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_unreadCountKey) ?? 0;
  }

  /// Set unread notification count dan emit to stream
  static Future<void> setUnreadCount(int count) async {
    final prefs = await SharedPreferences.getInstance();
    final newCount = count > 0 ? count : 0;
    await prefs.setInt(_unreadCountKey, newCount);
    await prefs.setInt(_lastCheckKey, DateTime.now().millisecondsSinceEpoch);
    // Broadcast count change to all listeners
    _instance._countController.add(newCount);
  }

  /// Increment unread count (new notification received)
  static Future<void> incrementUnreadCount() async {
    final current = await getUnreadCount();
    await setUnreadCount(current + 1);
  }

  /// Decrement unread count (notification read)
  static Future<void> decrementUnreadCount() async {
    final current = await getUnreadCount();
    if (current > 0) {
      await setUnreadCount(current - 1);
    }
  }

  /// Clear all unread notifications
  static Future<void> clearUnreadCount() async {
    await setUnreadCount(0);
  }

  /// Check if there are unread notifications
  static Future<bool> hasUnread() async {
    final count = await getUnreadCount();
    return count > 0;
  }

  /// Get last notification check timestamp
  static Future<DateTime?> getLastCheckTime() async {
    final prefs = await SharedPreferences.getInstance();
    final timestamp = prefs.getInt(_lastCheckKey);
    if (timestamp == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(timestamp);
  }

  /// Dispose stream controller
  static void dispose() {
    _instance._countController.close();
  }
}
