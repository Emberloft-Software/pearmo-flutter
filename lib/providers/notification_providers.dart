import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Connection id of the chat screen currently on top, if any. Set/cleared by
/// `ChatScreen` itself (initState/dispose) — lets the app-wide notification
/// watcher suppress a "new message" alert for the conversation the user is
/// already looking at.
final currentlyOpenChatConnectionIdProvider = StateProvider<String?>((ref) => null);
