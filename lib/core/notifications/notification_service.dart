import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Thin wrapper around `flutter_local_notifications` — shows real OS
/// notification banners triggered locally by the app while it's running
/// (foreground or backgrounded), not server-sent push. That's a deliberate
/// scope choice: true push (delivery while the app is fully killed) needs a
/// Firebase project + APNs cert plus a server-side sender, none of which
/// exist yet — see CLAUDE.md "In-app notifications".
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  int _nextId = 0;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    // Only used to construct TZDateTime for zonedSchedule below — we always
    // anchor to tz.UTC after converting the target instant with .toUtc(),
    // so no device-timezone lookup (e.g. flutter_timezone) is needed: this
    // is a one-shot "fire at this exact instant" alarm, not a recurring
    // schedule where DST-aware local-time matching would matter.
    tz_data.initializeTimeZones();

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    await _plugin.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
    );

    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    await _plugin
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  }

  Future<void> show({required String title, required String body}) async {
    const androidDetails = AndroidNotificationDetails(
      'pearmo_default',
      'Pearmo',
      channelDescription: 'Chat, connection, and game alerts',
      importance: Importance.high,
      priority: Priority.high,
    );
    const details = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(),
    );
    // Cycle a small pool of ids rather than always 0 — using the same id
    // every time would make each new notification silently replace the
    // last one instead of stacking.
    _nextId = (_nextId + 1) % 100;
    await _plugin.show(_nextId, title, body, details);
  }

  /// Schedules a loud, high-priority local alarm for a check-in deadline.
  ///
  /// This is best-effort, not a guarantee — worth being explicit about in
  /// any UI copy that references it:
  /// - Android: uses `AndroidScheduleMode.alarmClock` (the same scheduling
  ///   category real alarm-clock apps use, fires even in low-power idle)
  ///   plus `fullScreenIntent` to try to wake the screen like an alarm.
  ///   Android 12+ requires the user to have granted "Alarms & reminders"
  ///   (`SCHEDULE_EXACT_ALARM`) — some OEMs default this off. Android 14+
  ///   further restricts full-screen intents to apps in alarm/calling
  ///   categories, which may reduce this to a loud heads-up notification
  ///   rather than a true full-screen wake on some devices.
  /// - iOS: a local notification with sound is the best available without
  ///   Apple's separate "critical alerts" entitlement (which bypasses
  ///   silent mode and requires a case-by-case Apple approval for safety
  ///   apps — not something to assume is in place for the beta).
  Future<void> scheduleAlarm({
    required int id,
    required DateTime dateTime,
    required String title,
    required String body,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'pearmo_checkin_alarm',
      'Pearmo check-in alarms',
      channelDescription: 'Safety check-in reminders you set for yourself',
      importance: Importance.max,
      priority: Priority.max,
      category: AndroidNotificationCategory.alarm,
      fullScreenIntent: true,
      playSound: true,
      enableVibration: true,
    );
    const details = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(
        interruptionLevel: InterruptionLevel.timeSensitive,
        presentSound: true,
      ),
    );
    await _plugin.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(dateTime.toUtc(), tz.UTC),
      details,
      androidScheduleMode: AndroidScheduleMode.alarmClock,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> cancelScheduled(int id) => _plugin.cancel(id);
}
