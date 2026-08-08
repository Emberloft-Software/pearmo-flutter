import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Selected tab of `HomeShell`'s bottom navigation. Lifted out of the
/// widget's own `setState` so a notification tap can switch tabs — an
/// incoming connection request has to land on the Connections tab, where
/// the Accept/Decline buttons live.
final homeTabIndexProvider = StateProvider<int>((ref) => 0);

/// Indices of `HomeShell._screens`, named so callers don't pass bare ints.
class HomeTab {
  HomeTab._();

  static const int matches = 0;
  static const int connections = 1;
  static const int profile = 2;
}
