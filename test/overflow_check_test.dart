// Regression tests for horizontal overflow and truncated text: the shared
// widgets whose Rows have to survive narrow phones and large text scales.
//
// Note on font metrics: flutter_test substitutes a font that draws every
// glyph a full em wide, roughly double a real proportional face. So these
// tests are good at catching *structural* overflow (a Row with no flexible
// child) but must not assert exact wrapping behaviour, which would be
// measuring the test font rather than the app.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pearmo/core/constants/enums.dart';
import 'package:pearmo/core/theme/app_theme.dart';
import 'package:pearmo/core/utils/validators.dart';
import 'package:pearmo/shared/widgets/hero_profile_card.dart';
import 'package:pearmo/shared/widgets/pearmo_button.dart';
import 'package:pearmo/shared/widgets/status_pill.dart';
import 'package:pearmo/shared/widgets/tier_chip.dart';

const sizes = <Size>[Size(320, 640), Size(360, 720), Size(412, 915)];
const scales = <double>[1.0, 1.3, 2.0];

Future<void> sweep(
  WidgetTester tester,
  String name,
  Widget Function() build,
) async {
  for (final size in sizes) {
    for (final scale in scales) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(
            size: size,
            textScaler: TextScaler.linear(scale),
          ),
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: build(),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      final err = tester.takeException();
      expect(err, isNull, reason: '$name at $size scale $scale: $err');
    }
  }
}

void main() {
  testWidgets('PearmoButton row', (t) async {
    await sweep(
      t,
      'button',
      () => const Row(
        children: [
          Expanded(
            child: PearmoButton(
              label: 'Submitted, awaiting review',
              icon: Icons.shield_outlined,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: PearmoButton(label: 'Send Request', icon: Icons.favorite),
          ),
        ],
      ),
    );
  });

  testWidgets('StatusPill longest label', (t) async {
    await sweep(
      t,
      'pill',
      () => Row(
        children: [
          const SizedBox(width: 64, height: 64),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                StatusPill(
                  label: ConnectionStatus.accepted.label,
                  color: Colors.blue,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  });

  testWidgets('TierChip', (t) async {
    await sweep(
      t,
      'chip',
      () => Row(
        children: [
          const Flexible(child: Text('26 · Non-binary')),
          const SizedBox(width: 6),
          Flexible(
            child: TierChip(tier: VerificationTier.unverified, compact: true),
          ),
        ],
      ),
    );
  });

  testWidgets('HeroProfileCard editorial', (t) async {
    await sweep(
      t,
      'hero-editorial',
      () => const HeroProfileCard(
        avatarId: 'fox',
        title: '26 · Non-binary',
        displayName: 'The Golden Retriever',
        kicker: 'Profile · They/Them',
        subtitle: 'Colombo District',
        tierLabel: 'Selfie verified',
        isVerified: true,
      ),
    );
  });

  testWidgets('HeroProfileCard centered', (t) async {
    await sweep(
      t,
      'hero-centered',
      () => const HeroProfileCard(
        avatarId: 'fox',
        title: '26 · Non-binary',
        subtitle: 'Colombo District',
        tierLabel: 'Selfie verified',
        isVerified: true,
        matchPercent: 87,
      ),
    );
  });

  // `InputDecoration` caps helper and error text at one line by default,
  // which ellipsises rather than wraps — the login screen's helper text was
  // cut to "Your 10-digit mobile number, no need to t…" on narrower phones.
  // Asserting the cap (not the wrapping) keeps this independent of the test
  // font's exaggerated metrics.
  group('input helper/error text can wrap', () {
    Future<RenderParagraph> paragraphFor(
      WidgetTester tester,
      InputDecoration decoration,
      String text,
    ) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(24),
              child: TextFormField(decoration: decoration),
            ),
          ),
        ),
      );
      await tester.pump();
      return tester.renderObject<RenderParagraph>(find.text(text));
    }

    testWidgets('helper text is allowed more than one line', (t) async {
      const helper = '10 digits, no need to type +94';
      final para = await paragraphFor(
        t,
        const InputDecoration(helperText: helper),
        helper,
      );
      expect(para.maxLines, greaterThan(1));
    });

    testWidgets('the longest validator message is allowed to wrap', (t) async {
      // 62 characters — the widest error the app can produce.
      final message = Validators.phone('not a number')!;
      final para = await paragraphFor(
        t,
        InputDecoration(errorText: message),
        message,
      );
      expect(para.maxLines, greaterThanOrEqualTo(3));
    });
  });
}
