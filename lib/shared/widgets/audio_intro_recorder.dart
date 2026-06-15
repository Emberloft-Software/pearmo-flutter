import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_theme.dart';
import 'pearmo_button.dart';

/// Records a short voice intro (used in onboarding and profile editing).
/// Calls [onRecorded] with the local file path once a recording is
/// finished, or `null` if the user removes it.
class AudioIntroRecorder extends StatefulWidget {
  const AudioIntroRecorder({super.key, required this.onRecorded, this.initialPath});

  final ValueChanged<String?> onRecorded;
  final String? initialPath;

  @override
  State<AudioIntroRecorder> createState() => _AudioIntroRecorderState();
}

class _AudioIntroRecorderState extends State<AudioIntroRecorder> {
  final _recorder = AudioRecorder();
  final _player = AudioPlayer();

  bool _isRecording = false;
  bool _isPlaying = false;
  String? _path;
  Duration _elapsed = Duration.zero;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _path = widget.initialPath;
    _player.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _isPlaying = false);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _recorder.dispose();
    _player.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    if (!await _recorder.hasPermission()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Microphone permission is needed to record an intro.')),
        );
      }
      return;
    }

    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/pearmo_audio_intro_${DateTime.now().millisecondsSinceEpoch}.m4a';

    await _recorder.start(const RecordConfig(encoder: AudioEncoder.aacLc), path: path);
    setState(() {
      _isRecording = true;
      _path = null;
      _elapsed = Duration.zero;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() => _elapsed += const Duration(seconds: 1));
      if (_elapsed.inSeconds >= AppConstants.audioIntroMaxSeconds) {
        _stopRecording();
      }
    });
  }

  Future<void> _stopRecording() async {
    _timer?.cancel();
    final path = await _recorder.stop();
    setState(() {
      _isRecording = false;
      _path = path;
    });
    widget.onRecorded(path);
  }

  Future<void> _togglePlayback() async {
    if (_path == null) return;
    if (_isPlaying) {
      await _player.stop();
      setState(() => _isPlaying = false);
    } else {
      await _player.play(DeviceFileSource(_path!));
      setState(() => _isPlaying = true);
    }
  }

  void _remove() {
    setState(() {
      _path = null;
      _elapsed = Duration.zero;
    });
    widget.onRecorded(null);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  color: AppColors.primaryLight,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _isRecording ? Icons.stop_circle : Icons.mic,
                  color: AppColors.primaryDark,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _isRecording
                      ? 'Recording... ${_elapsed.inSeconds}s'
                      : _path != null
                          ? 'Voice intro recorded'
                          : 'Record up to ${AppConstants.audioIntroMaxSeconds}s introducing yourself',
                  style: AppTextStyles.bodyMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: PearmoButton(
                  label: _isRecording ? 'Stop' : (_path == null ? 'Record' : 'Re-record'),
                  variant: PearmoButtonVariant.outline,
                  icon: _isRecording ? Icons.stop : Icons.fiber_manual_record,
                  onPressed: _isRecording ? _stopRecording : _startRecording,
                ),
              ),
              if (_path != null && !_isRecording) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: PearmoButton(
                    label: _isPlaying ? 'Pause' : 'Play',
                    variant: PearmoButtonVariant.outline,
                    icon: _isPlaying ? Icons.pause : Icons.play_arrow,
                    onPressed: _togglePlayback,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _remove,
                  icon: const Icon(Icons.delete_outline, color: AppColors.danger),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Optional, but a friendly intro helps your matches feel like they know you before they see a photo.',
            style: AppTextStyles.caption,
          ),
        ],
      ),
    );
  }
}
