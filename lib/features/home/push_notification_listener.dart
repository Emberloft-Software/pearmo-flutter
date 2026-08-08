import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/notifications/notification_destination.dart';
import '../../core/notifications/notification_service.dart';
import '../../core/router/app_router.dart';
import '../../providers/auth_providers.dart';
import '../../providers/notification_providers.dart';
import '../../providers/repository_providers.dart';

/// Registers this device for push (FCM) once a user is signed in, and
/// displays a local banner for pushes that arrive while the app is in the
/// foreground — FCM delivers foreground messages silently on both platforms,
/// so something has to turn them into a visible notification;
/// `flutter_local_notifications` (`NotificationService`) is reused for that
/// display, same widget it already used for the check-in alarm.
///
/// Background/terminated delivery needs no Dart code at all: the OS shows
/// the FCM `notification` payload directly from the system tray. That's the
/// entire point of switching to this from the old `NotificationWatcher`,
/// which faked notifications by listening to Supabase Realtime client-side
/// and only ever worked while the app process was alive. See CLAUDE.md
/// "Push notifications".
class PushNotificationListener extends ConsumerStatefulWidget {
  const PushNotificationListener({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<PushNotificationListener> createState() => _PushNotificationListenerState();
}

class _PushNotificationListenerState extends ConsumerState<PushNotificationListener> {
  String? _registeredForUserId;

  @override
  void initState() {
    super.initState();
    // Covers the case where a session is restored on cold start (already
    // logged in by the time this widget mounts) — `ref.listen` in `build`
    // below only fires on *future* changes, not the current value at the
    // time it's registered.
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final userId = ref.read(currentUserIdProvider);
      if (userId != null) _register(userId);
    });

    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Tapping a push opens the screen it's about. Three separate entry
    // points, because the OS delivers the tap differently depending on
    // where the app was:
    //  - backgrounded, OS-rendered banner -> onMessageOpenedApp
    //  - terminated, OS-rendered banner   -> getInitialMessage (once, on
    //    the launch that the notification caused)
    //  - foregrounded, banner rendered by NotificationService itself ->
    //    its own payload callback, wired below
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);
    FirebaseMessaging.instance.getInitialMessage().then((message) {
      if (message != null) _handleNotificationTap(message);
    });
    NotificationService.instance.onNotificationTapped = _navigateTo;
  }

  void _handleNotificationTap(RemoteMessage message) {
    _navigateTo(routeForPushData(message.data));
  }

  void _navigateTo(String? route) {
    if (route == null || !mounted) return;
    // Deferred a frame: a tap from the terminated state resolves before the
    // router has finished its initial redirect (splash -> home), and pushing
    // during that would be dropped.
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(routerProvider).push(route);
    });
  }

  Future<void> _register(String userId) async {
    if (_registeredForUserId == userId) return;
    _registeredForUserId = userId;

    final messaging = FirebaseMessaging.instance;
    await messaging.requestPermission(alert: true, badge: true, sound: true);

    final repo = ref.read(pushTokenRepositoryProvider);
    final platform = Platform.isIOS ? 'ios' : 'android';

    final token = await messaging.getToken();
    if (token != null) await repo.upsertToken(token: token, platform: platform);

    messaging.onTokenRefresh.listen((newToken) {
      repo.upsertToken(token: newToken, platform: platform);
    });
  }

  void _handleForegroundMessage(RemoteMessage message) {
    // Suppress the banner for whichever chat is already open on screen —
    // same suppression `NotificationWatcher` used to do, now driven by the
    // `connection_id` the `send-push` edge function puts in the data
    // payload instead of a Realtime message row.
    final connectionId = message.data['connection_id'];
    if (connectionId != null &&
        ref.read(currentlyOpenChatConnectionIdProvider) == connectionId) {
      return;
    }
    final notification = message.notification;
    if (notification == null) return;
    NotificationService.instance.show(
      title: notification.title ?? 'Pearmo',
      body: notification.body ?? '',
      route: routeForPushData(message.data),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<String?>(currentUserIdProvider, (previous, next) {
      if (next != null && next != previous) _register(next);
    });
    return widget.child;
  }
}
