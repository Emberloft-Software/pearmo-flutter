import 'package:flutter_local_notifications/flutter_local_notifications.dart';

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
}
