import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

class LocalNotificationService {
  static const int _learnReminderId = 1101;
  static const int _sleepReminderId = 1102;

  static const AndroidNotificationChannel _familyReminderChannel =
      AndroidNotificationChannel(
        'family_reminders',
        'Family Reminders',
        description: 'Reminder otomatis belajar dan tidur untuk anak.',
        importance: Importance.high,
      );

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) return;

    tz_data.initializeTimeZones();

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const initSettings = InitializationSettings(android: androidSettings);

    await _plugin.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // Handle notification tap
        print('Notification tapped with payload: ${response.payload}');
      },
    );

    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    await androidPlugin?.createNotificationChannel(_familyReminderChannel);
    _initialized = true;
  }

  static Future<void> requestPermissions() async {
    await initialize();
    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidPlugin?.requestNotificationsPermission();
  }

  static Future<void> syncFamilyReminders({
    required bool autoReminderEnabled,
    required int learnReminderHour,
    required int sleepReminderHour,
  }) async {
    await initialize();

    if (!autoReminderEnabled) {
      await cancelFamilyReminders();
      return;
    }

    await requestPermissions();

    await _scheduleDailyReminder(
      id: _learnReminderId,
      hour: learnReminderHour,
      title: 'Waktunya Belajar',
      body: 'Ayo mulai sesi belajar hari ini. Targetkan fokus 60 menit.',
      payload: 'learn_reminder',
    );

    await _scheduleDailyReminder(
      id: _sleepReminderId,
      hour: sleepReminderHour,
      title: 'Waktunya Tidur',
      body: 'Saatnya bersiap tidur supaya besok tetap segar dan fokus.',
      payload: 'sleep_reminder',
    );
  }

  static Future<void> cancelFamilyReminders() async {
    await initialize();
    await _plugin.cancel(id: _learnReminderId);
    await _plugin.cancel(id: _sleepReminderId);
  }

  static Future<void> _scheduleDailyReminder({
    required int id,
    required int hour,
    required String title,
    required String body,
    required String payload,
  }) async {
    final scheduledDate = _nextInstanceOfHour(hour);

    await _plugin.zonedSchedule(
      id: id,
      scheduledDate: scheduledDate,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _familyReminderChannel.id,
          _familyReminderChannel.name,
          channelDescription: _familyReminderChannel.description,
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      title: title,
      body: body,
      payload: payload,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  static tz.TZDateTime _nextInstanceOfHour(int hour) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
    );

    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    return scheduledDate;
  }
}
