import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/matches_providers.dart';
import 'loading_indicator.dart';

/// Plays a candidate's or the current user's voice intro from a private
/// storage path, signing the URL on demand.
class AudioIntroPlayer extends ConsumerStatefulWidget {
  const AudioIntroPlayer({super.key, required this.storagePath, this.compact = false});

  final String storagePath;

  /// Compact mode: just a circular play/pause button (for embedding in the
  /// profile hero card) instead of the full "Voice intro" row.
  final bool compact;

  @override
  ConsumerState<AudioIntroPlayer> createState() => _AudioIntroPlayerState();
}

class _AudioIntroPlayerState extends ConsumerState<AudioIntroPlayer> {
  final _player = AudioPlayer();
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _player.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _isPlaying = false);
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _toggle(String url) async {
    if (_isPlaying) {
      await _player.pause();
    } else {
      await _player.play(UrlSource(url));
    }
    setState(() => _isPlaying = !_isPlaying);
  }

  @override
  Widget build(BuildContext context) {
    final signedUrl = ref.watch(signedAudioIntroUrlProvider(widget.storagePath));

    if (widget.compact) {
      return signedUrl.when(
        data: (url) => Material(
          color: Colors.white.withValues(alpha: 0.95),
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () => _toggle(url),
            child: SizedBox(
              width: 44,
              height: 44,
              child: Icon(
                _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: AppColors.primaryDark,
                size: 26,
              ),
            ),
          ),
        ),
        loading: () => Container(
          width: 44,
          height: 44,
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.95),
            shape: BoxShape.circle,
          ),
          child: const CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
        ),
        error: (_, _) => const SizedBox.shrink(),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.secondaryLight,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      ),
      child: Row(
        children: [
          signedUrl.when(
            data: (url) => IconButton(
              onPressed: () => _toggle(url),
              icon: Icon(
                _isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill,
                color: AppColors.secondaryDark,
                size: 36,
              ),
            ),
            loading: () => const SizedBox(
              width: 48,
              height: 48,
              child: Padding(padding: EdgeInsets.all(12), child: LoadingIndicator()),
            ),
            error: (_, _) => const Icon(Icons.error_outline, color: AppColors.error),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text('Voice intro', style: AppTextStyles.bodyMedium),
          ),
        ],
      ),
    );
  }
}
