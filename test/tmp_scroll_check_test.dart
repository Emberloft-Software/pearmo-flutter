// TEMPORARY scratch verification - delete after running.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pearmo/features/auth/screens/blocked_screen.dart';
import 'package:pearmo/features/auth/screens/login_screen.dart';
import 'package:pearmo/features/auth/screens/otp_screen.dart';
import 'package:pearmo/shared/widgets/empty_state.dart';

/// Renders [child] at [size], with [keyboard] logical pixels of bottom inset
/// (what the Scaffold subtracts when the soft keyboard is up).
Future<Object?> render(
  WidgetTester tester,
  Widget child, {
  required Size size,
  double keyboard = 0,
  double textScale = 1.0,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            size: size,
            textScaler: TextScaler.linear(textScale),
            viewInsets: EdgeInsets.only(bottom: keyboard),
          ),
          child: child,
        ),
      ),
    ),
  );
  await tester.pump();
  return tester.takeException();
}

void main() {
  const short = Size(320, 568); // iPhone SE class
  const normal = Size(360, 720);

  testWidgets('LoginScreen: no overflow with keyboard up', (t) async {
    for (final size in [short, normal]) {
      for (final kb in [0.0, 300.0]) {
        final err = await render(t, const LoginScreen(), size: size, keyboard: kb);
        expect(err, isNull, reason: 'login $size keyboard=$kb -> $err');
      }
    }
  });

  testWidgets('OtpScreen: no overflow with keyboard up', (t) async {
    for (final size in [short, normal]) {
      for (final kb in [0.0, 300.0]) {
        final err = await render(
          t,
          const OtpScreen(phone: '+94771234567'),
          size: size,
          keyboard: kb,
        );
        expect(err, isNull, reason: 'otp $size keyboard=$kb -> $err');
      }
    }
  });

  testWidgets('BlockedScreen: no overflow with a long ban reason', (t) async {
    final err = await render(
      t,
      const BlockedScreen(
        banReason: 'This account was suspended following multiple reports of '
            'behaviour that breaks our community safety guidelines. If you '
            'believe this was a mistake, contact support with your number.',
      ),
      size: short,
      textScale: 1.3,
    );
    expect(err, isNull, reason: 'blocked -> $err');
  });

  // Structural reproduction of MatchesScreen's connected branch: banner +
  // connection card + notice. The real screen can't be pumped without a
  // Supabase backend, so this asserts the *shape* is now scroll-safe.
  testWidgets('matches connected layout: card + notice does not overflow',
      (t) async {
    Widget layout({required bool fixed}) => Scaffold(
          appBar: AppBar(title: const Text("Today's Matches")),
          body: Column(
            children: [
              Container(height: 140, color: Colors.grey), // unverified banner
              if (fixed) ...[
                Container(height: 340, color: Colors.blue), // connection card
                const Expanded(
                  child: EmptyState(
                    icon: Icons.favorite,
                    title: 'Matches are paused',
                    message: 'Pearmo is one connection at a time. Your next '
                        'set of matches arrives once this connection ends.',
                  ),
                ),
              ] else
                Expanded(
                  child: ListView(
                    children: [
                      Container(height: 340, color: Colors.blue),
                      const SizedBox(height: 12),
                      const EmptyState(
                        icon: Icons.favorite,
                        title: 'Matches are paused',
                        message: 'Pearmo is one connection at a time. Your '
                            'next set of matches arrives once this connection '
                            'ends.',
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );

    // Old shape overflows...
    final before = await render(t, layout(fixed: true), size: normal);
    expect(before, isNotNull, reason: 'expected the OLD shape to overflow');

    // ...new shape does not, on either size.
    for (final size in [short, normal]) {
      final after = await render(t, layout(fixed: false), size: size);
      expect(after, isNull, reason: 'new matches shape $size -> $after');
    }
  });
}
