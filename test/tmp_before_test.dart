import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pearmo/features/auth/screens/login_screen.dart';

void main() {
  testWidgets('PRE-FIX LoginScreen overflows with keyboard up', (t) async {
    const size = Size(360, 720);
    t.view.physicalSize = size;
    t.view.devicePixelRatio = 1.0;
    await t.pumpWidget(ProviderScope(
      child: MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: size,
            viewInsets: EdgeInsets.only(bottom: 300),
          ),
          child: const LoginScreen(),
        ),
      ),
    ));
    await t.pump();
    final err = t.takeException();
    // ignore: avoid_print
    print('PRE-FIX RESULT: $err');
    expect(err, isNotNull);
  });
}
