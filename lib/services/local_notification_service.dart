import 'dart:ui' show Color;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

class LocalNotificationService {
  static const int _learnReminderId = 1101;
  static const int _sleepReminderId = 1102;

  static const AndroidNotificationChannel _familyReminderChannel =
      AndroidNotificationChannel(
        'family_reminders',
        'Pengingat TARA',
        description: 'Pengingat jadwal anak dan pemberitahuan Delegasi.',
        importance: Importance.high,
      );

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) return;

    tz_data.initializeTimeZones();

    // Ikon status bar Android harus siluet putih; ikon berwarna tampil sebagai kotak abu-abu.
    const androidSettings = AndroidInitializationSettings(
      '@drawable/ic_stat_tara',
    );
    // Izin iOS diminta saat dibutuhkan lewat ensurePermission, bukan saat aplikasi dibuka.
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestSoundPermission: false,
      requestBadgePermission: false,
    );
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
    );

    await _plugin.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // Handle notification tap if needed.
      },
    );

    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    await androidPlugin?.createNotificationChannel(_familyReminderChannel);
    _initialized = true;
  }

  /// Meminta izin notifikasi bila belum ada. Mengembalikan true bila notifikasi boleh tampil.
  static Future<bool> ensurePermission() async {
    await initialize();
    final iosPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    if (iosPlugin != null) {
      if ((await iosPlugin.checkPermissions())?.isEnabled ?? false) return true;
      return await iosPlugin.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
    }
    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (androidPlugin == null) return false;
    if (await androidPlugin.areNotificationsEnabled() ?? false) return true;
    return await androidPlugin.requestNotificationsPermission() ?? false;
  }

  static Future<void> requestPermissions() => ensurePermission();

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

  static Future<void> showNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    await initialize();

    const androidDetails = AndroidNotificationDetails(
      'family_reminders',
      'Pengingat TARA',
      channelDescription: 'Pengingat jadwal anak dan pemberitahuan Delegasi.',
      importance: Importance.high,
      priority: Priority.high,
      ticker: 'notification',
      color: Color(0xFFF06292),
    );
    // Di iOS notifikasi juga ditampilkan saat aplikasi sedang terbuka.
    const details = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(presentAlert: true, presentBanner: true, presentSound: true),
    );

    await _plugin.show(
      id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title: title,
      body: body,
      notificationDetails: details,
      payload: payload,
    );
  }

  /// Nomor notifikasi yang stabil untuk satu jadwal. Dihitung sendiri (FNV-1a) karena
  /// String.hashCode tidak dijamin sama di setiap kali aplikasi dijalankan.
  static int reminderId(String scheduleId) {
    var hash = 0x811c9dc5;
    for (final unit in scheduleId.codeUnits) {
      hash = ((hash ^ unit) * 0x01000193) & 0x7fffffff;
    }
    return 20000 + hash % 1000000;
  }

  static int _legacyReminderId(String scheduleId) =>
      20000 + scheduleId.hashCode.abs() % 1000000;

  /// Memasang pengingat jadwal di perangkat. [repeatRule]: none, daily, atau weekly.
  /// Mengembalikan false bila waktu jadwal sekali-jalan sudah lewat.
  static Future<bool> scheduleReminder({
    required String scheduleId,
    required DateTime time,
    required String repeatRule,
    required String title,
    required String body,
  }) async {
    await requestPermissions();
    final local = time.toLocal();
    var scheduled = tz.TZDateTime.from(local, tz.local);
    final now = tz.TZDateTime.now(tz.local);
    if (repeatRule == 'none') {
      if (!scheduled.isAfter(now)) return false;
    } else {
      final step = Duration(days: repeatRule == 'weekly' ? 7 : 1);
      while (!scheduled.isAfter(now)) {
        scheduled = scheduled.add(step);
      }
    }
    // Pengingat yang dipasang versi lama memakai nomor berbeda; dibatalkan agar tidak berbunyi dua kali.
    await _plugin.cancel(id: _legacyReminderId(scheduleId));
    await _plugin.zonedSchedule(
      id: reminderId(scheduleId),
      scheduledDate: scheduled,
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
      payload: 'schedule:$scheduleId',
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: switch (repeatRule) {
        'daily' => DateTimeComponents.time,
        'weekly' => DateTimeComponents.dayOfWeekAndTime,
        _ => null,
      },
    );
    return true;
  }

  static Future<void> cancelReminder(String scheduleId) async {
    await initialize();
    await _plugin.cancel(id: reminderId(scheduleId));
    await _plugin.cancel(id: _legacyReminderId(scheduleId));
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
