import 'dart:convert';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/notifications/notification_destination.dart';
import '../../core/notifications/notification_service.dart';
import '../../core/router/app_router.dart';
import '../../providers/auth_providers.dart';
import '../../providers/home_tab_provider.dart';
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

    // Tap handling, all three entry points. Without these a tap just opened
    // the app on whatever screen it was already showing.
    //
    // 1. App backgrounded, user taps the tray notification.
    FirebaseMessaging.onMessageOpenedApp.listen((message) => _openFor(message.data));

    // 2. App was fully terminated and launched *by* the tap. Safe to consume
    //    here rather than in `main()`: this widget only mounts inside
    //    `HomeShell`, so the session is restored and the router is already
    //    settled on `/home` by now.
    FirebaseMessaging.instance.getInitialMessage().then((message) {
      if (message != null) _openFor(message.data);
    });

    // 3. App in the foreground — FCM delivers silently, so `_handleForeground
    //    Message` re-shows it locally; this routes taps on that local banner.
    NotificationService.instance.onTap = (payload) {
      try {
        final decoded = jsonDecode(payload);
        if (decoded is Map) _openFor(Map<String, dynamic>.from(decoded));
      } catch (_) {
        // Malformed payload: opening the app with no navigation is the right
        // fallback, and never worth crashing over.
      }
    };
  }

  @override
  void dispose() {
    // Don't leave a closure pointing at this (disposed) State behind.
    if (NotificationService.instance.onTap != null) {
      NotificationService.instance.onTap = null;
    }
    super.dispose();
  }

  /// Navigates to wherever [data] points, if anywhere.
  void _openFor(Map<String, dynamic> data) {
    if (!mounted) return;
    final destination = destinationFor(data);
    if (destination == null) return;

    final tab = destination.homeTab;
    if (tab != null) ref.read(homeTabIndexProvider.notifier).state = tab;

    // `/home` is the shell this widget already lives in — selecting the tab
    // above is the whole navigation in that case.
    if (destination.route != '/home') {
      ref.read(routerProvider).push(destination.route);
    }
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
      // Carried through so a tap on this locally-shown banner navigates the
      // same way a tray notification does.
      payload: jsonEncode(message.data),
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
