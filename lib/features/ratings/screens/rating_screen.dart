import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/error_mapper.dart';
import '../../../data/models/connection_rating.dart';
import '../../../providers/auth_providers.dart';
import '../../../providers/repository_providers.dart';
import '../../../shared/widgets/widgets.dart';

/// Private post-connection rating — only the rater ever sees these numbers,
/// they feed into the matching algorithm and trust scores server-side.
class RatingScreen extends ConsumerStatefulWidget {
  const RatingScreen({super.key, required this.connectionId, required this.ratedId});

  final String connectionId;
  final String ratedId;

  @override
  ConsumerState<RatingScreen> createState() => _RatingScreenState();
}

class _RatingScreenState extends ConsumerState<RatingScreen> {
  int _respectfulness = 3;
  int _communication = 3;
  int _ghostingBehaviour = 3;
  int _overall = 3;
  bool _isSubmitting = false;
  String? _error;
  bool _checkingPriorRating = true;
  bool _alreadyRated = false;

  @override
  void initState() {
    super.initState();
    _checkPriorRating();
  }

  Future<void> _checkPriorRating() async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;
    final rated = await ref.read(ratingsRepositoryProvider).hasRated(
          connectionId: widget.connectionId,
          raterId: userId,
        );
    if (mounted) {
      setState(() {
        _alreadyRated = rated;
        _checkingPriorRating = false;
      });
    }
  }

  Future<void> _submit(String userId) async {
    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    try {
      await ref.read(ratingsRepositoryProvider).submitRating(ConnectionRating(
            connectionId: widget.connectionId,
            raterId: userId,
            ratedId: widget.ratedId,
            respectfulness: _respectfulness,
            communication: _communication,
            ghostingBehaviour: _ghostingBehaviour,
            overall: _overall,
          ));
      if (mounted) context.pop();
    } catch (e) {
      setState(() => _error = ErrorMapper.map(e));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final userId = ref.watch(currentUserIdProvider);

    if (_checkingPriorRating) {
      return Scaffold(
        appBar: AppBar(title: const Text('Rate this connection')),
        body: const LoadingIndicator(),
      );
    }

    if (_alreadyRated) {
      return Scaffold(
        appBar: AppBar(title: const Text('Rate this connection')),
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            "You've already rated this connection.",
            style: AppTextStyles.body,
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Rate this connection')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            "This is private and only used to improve your future matches — the other "
            "person won't see your rating.",
            style: AppTextStyles.body,
          ),
          const SizedBox(height: 24),
          _RatingSlider(
            label: 'Respectfulness',
            value: _respectfulness,
            onChanged: (v) => setState(() => _respectfulness = v),
          ),
          _RatingSlider(
            label: 'Communication',
            value: _communication,
            onChanged: (v) => setState(() => _communication = v),
          ),
          _RatingSlider(
            label: 'Showed up / did not ghost',
            value: _ghostingBehaviour,
            onChanged: (v) => setState(() => _ghostingBehaviour = v),
          ),
          _RatingSlider(
            label: 'Overall experience',
            value: _overall,
            onChanged: (v) => setState(() => _overall = v),
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            ErrorBanner(message: _error!),
          ],
          const SizedBox(height: 24),
          PearmoButton(
            label: 'Submit rating',
            icon: Icons.star_outline,
            isLoading: _isSubmitting,
            onPressed: (_isSubmitting || userId == null) ? null : () => _submit(userId),
          ),
        ],
      ),
    );
  }
}

class _RatingSlider extends StatelessWidget {
  const _RatingSlider({required this.label, required this.value, required this.onChanged});

  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTextStyles.bodyMedium),
          Row(
            children: List.generate(5, (index) {
              final starValue = index + 1;
              return IconButton(
                onPressed: () => onChanged(starValue),
                icon: Icon(
                  starValue <= value ? Icons.star : Icons.star_border,
                  color: AppColors.primary,
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}
