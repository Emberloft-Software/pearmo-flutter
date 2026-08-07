import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/config/supabase_config.dart';
import 'core/notifications/notification_service.dart';

/// Runs in a separate background isolate whenever a push arrives while the
/// app is backgrounded/terminated — that isolate doesn't share state with
/// the main one, so Firebase has to be re-initialized here. Deliberately
/// empty otherwise: the FCM `notification` payload alone is enough for the
/// OS to show a system-tray banner with no Dart code involved; this only
/// exists so `firebase_messaging` has a registered handler, leaving room
/// for a silent/data-only push to do something later.
@pragma('vm:entry-point')
Future<void> _firebaseBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundHandler);

  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
  );
  // Local notifications are still used for the check-in alarm and to
  // display push while the app is foregrounded — see
  // PushNotificationListener and CLAUDE.md "Push notifications".
  await NotificationService.instance.init();

  runApp(const ProviderScope(child: PearmoApp()));
}
