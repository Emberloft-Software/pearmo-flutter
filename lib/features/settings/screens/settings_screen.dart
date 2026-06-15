import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/error_mapper.dart';
import '../../../data/models/profile.dart';
import '../../../providers/auth_providers.dart';
import '../../../providers/profile_providers.dart';
import '../../../providers/repository_providers.dart';
import '../../../shared/widgets/widgets.dart';

/// Profile privacy & visibility settings — all map directly onto the
/// `profiles` row via `ProfileRepository.updateSettings`.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool? _isPhotoPublic;
  bool? _hideFromContacts;
  TimeOfDay? _activeHoursStart;
  TimeOfDay? _activeHoursEnd;
  late TextEditingController _regionController;
  late TextEditingController _countryController;
  bool _initialized = false;
  bool _isSaving = false;
  String? _error;
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    _regionController = TextEditingController();
    _countryController = TextEditingController();
  }

  @override
  void dispose() {
    _regionController.dispose();
    _countryController.dispose();
    super.dispose();
  }

  void _initFrom(Profile profile) {
    if (_initialized) return;
    _initialized = true;
    _isPhotoPublic = profile.isPhotoPublic;
    _hideFromContacts = profile.hideFromContacts;
    _activeHoursStart = _parseTime(profile.activeHoursStart);
    _activeHoursEnd = _parseTime(profile.activeHoursEnd);
    _regionController.text = profile.regionName ?? '';
    _countryController.text = profile.countryCode;
  }

  TimeOfDay? _parseTime(String? value) {
    if (value == null) return null;
    final parts = value.split(':');
    if (parts.length < 2) return null;
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  String _formatTime(TimeOfDay time) =>
      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:00';

  Future<void> _pickTime(bool isStart) async {
    final initial = (isStart ? _activeHoursStart : _activeHoursEnd) ?? TimeOfDay.now();
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _activeHoursStart = picked;
      } else {
        _activeHoursEnd = picked;
      }
    });
  }

  Future<void> _save(String userId) async {
    setState(() {
      _isSaving = true;
      _error = null;
      _saved = false;
    });
    try {
      await ref.read(profileRepositoryProvider).updateSettings(
            userId: userId,
            isPhotoPublic: _isPhotoPublic,
            hideFromContacts: _hideFromContacts,
            activeHoursStart: _activeHoursStart != null ? _formatTime(_activeHoursStart!) : null,
            activeHoursEnd: _activeHoursEnd != null ? _formatTime(_activeHoursEnd!) : null,
            regionName: _regionController.text.trim().isEmpty ? null : _regionController.text.trim(),
            countryCode:
                _countryController.text.trim().isEmpty ? null : _countryController.text.trim().toUpperCase(),
          );
      ref.invalidate(myProfileProvider);
      setState(() => _saved = true);
    } catch (e) {
      setState(() => _error = ErrorMapper.map(e));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(myProfileProvider);
    final userId = ref.watch(currentUserIdProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: profileAsync.when(
        data: (profile) {
          if (profile == null || userId == null) {
            return const EmptyState(icon: Icons.person_outline, title: 'No profile yet');
          }
          _initFrom(profile);
          return _buildBody(userId);
        },
        loading: () => const LoadingIndicator(),
        error: (error, _) => Padding(
          padding: const EdgeInsets.all(20),
          child: ErrorBanner(message: ErrorMapper.map(error)),
        ),
      ),
    );
  }

  Widget _buildBody(String userId) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const SectionHeader(
          title: 'Photo privacy',
          subtitle: 'Avatars are always shown first — your real photo is only shared if you '
              'allow it here.',
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Show my profile photo'),
          value: _isPhotoPublic ?? false,
          onChanged: (value) => setState(() => _isPhotoPublic = value),
        ),
        const SizedBox(height: 16),
        // TODO(backend): this toggle persists to `profiles.hide_from_contacts`,
        // but actually excluding matches requires a contact-hash matching
        // step (reading the user's contacts, hashing numbers, and filtering
        // candidates server-side) that isn't in the handoff's function list yet.
        const SectionHeader(
          title: 'Hide from contacts',
          subtitle: "Don't show my profile to people already in my phone contacts.",
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Hide from my contacts'),
          value: _hideFromContacts ?? false,
          onChanged: (value) => setState(() => _hideFromContacts = value),
        ),
        const SizedBox(height: 16),
        const SectionHeader(
          title: 'Active hours',
          subtitle: "Let matches know when you're usually free to chat.",
        ),
        Row(
          children: [
            Expanded(
              child: _TimeField(
                label: 'Start',
                time: _activeHoursStart,
                onTap: () => _pickTime(true),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _TimeField(
                label: 'End',
                time: _activeHoursEnd,
                onTap: () => _pickTime(false),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const SectionHeader(title: 'Location'),
        TextField(
          controller: _regionController,
          decoration: const InputDecoration(labelText: 'Region / city'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _countryController,
          maxLength: 2,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(labelText: 'Country code (e.g. LK)'),
        ),
        if (_error != null) ...[
          const SizedBox(height: 16),
          ErrorBanner(message: _error!),
        ],
        if (_saved) ...[
          const SizedBox(height: 16),
          Text('Settings saved.', style: AppTextStyles.caption),
        ],
        const SizedBox(height: 24),
        PearmoButton(
          label: 'Save settings',
          icon: Icons.check,
          isLoading: _isSaving,
          onPressed: _isSaving ? null : () => _save(userId),
        ),
      ],
    );
  }
}

class _TimeField extends StatelessWidget {
  const _TimeField({required this.label, required this.time, required this.onTap});

  final String label;
  final TimeOfDay? time;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(labelText: label),
        child: Text(time == null ? 'Not set' : time!.format(context)),
      ),
    );
  }
}
