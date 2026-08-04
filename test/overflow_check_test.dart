// TEMPORARY: overflow regression sweep. Delete after running.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pearmo/core/constants/enums.dart';
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
}
