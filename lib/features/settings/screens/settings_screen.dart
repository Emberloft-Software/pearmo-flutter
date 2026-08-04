import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/enums.dart';
import '../../../core/theme/app_colors.dart';
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
  bool? _isProfileActive;
  TimeOfDay? _activeHoursStart;
  TimeOfDay? _activeHoursEnd;
  late TextEditingController _regionController;
  late TextEditingController _countryController;
  bool _initialized = false;
  bool _isSaving = false;
  String? _error;
  bool _saved = false;
  bool _isUploadingPhoto = false;
  String? _photoError;
  bool _isDeletingAccount = false;
  String? _deleteError;

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
    _isProfileActive = profile.isProfileActive;
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

  Future<void> _addPicture(String userId, VerificationTier? tier) async {
    if (!(tier?.isAtLeastSelfieVerified ?? false)) {
      final wantsToVerify = await VerifyToUnlockDialog.show(context);
      if (wantsToVerify && mounted) context.push('/verification');
      return;
    }

    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return;

    setState(() {
      _isUploadingPhoto = true;
      _photoError = null;
    });
    try {
      final storage = ref.read(storageRepositoryProvider);
      final profileRepo = ref.read(profileRepositoryProvider);
      final path = await storage.uploadProfilePhoto(userId, File(picked.path));
      await profileRepo.updateProfilePhotoPath(userId, path);
      await profileRepo.updateSettings(userId: userId, isPhotoPublic: true);
      setState(() => _isPhotoPublic = true);
      ref.invalidate(myProfileProvider);
    } catch (e) {
      setState(() => _photoError = ErrorMapper.map(e));
    } finally {
      if (mounted) setState(() => _isUploadingPhoto = false);
    }
  }

  Future<void> _setPhotoVisibility(String userId, bool value) async {
    setState(() => _isPhotoPublic = value);
    try {
      await ref.read(profileRepositoryProvider).updateSettings(userId: userId, isPhotoPublic: value);
      ref.invalidate(myProfileProvider);
    } catch (e) {
      setState(() => _photoError = ErrorMapper.map(e));
    }
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
            isProfileActive: _isProfileActive,
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

  Future<void> _confirmDeleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete your account?'),
        content: const Text(
          'This permanently removes your photos, voice intro, and identity documents, and '
          'hides your profile from everyone. This cannot be undone.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Delete', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _isDeletingAccount = true;
      _deleteError = null;
    });
    try {
      await ref.read(authRepositoryProvider).deleteAccount();
      // Signed out inside deleteAccount() — the router takes over from here.
    } catch (e) {
      setState(() => _deleteError = ErrorMapper.map(e));
    } finally {
      if (mounted) setState(() => _isDeletingAccount = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(myProfileProvider);
    final userId = ref.watch(currentUserIdProvider);
    final tierAsync = ref.watch(myVerificationTierProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: profileAsync.when(
        data: (profile) {
          if (profile == null || userId == null) {
            return const EmptyState(icon: Icons.person_outline, title: 'No profile yet');
          }
          _initFrom(profile);
          return _buildBody(userId, profile, tierAsync.valueOrNull);
        },
        loading: () => const LoadingIndicator(),
        error: (error, _) => Padding(
          padding: const EdgeInsets.all(20),
          child: ErrorBanner(message: ErrorMapper.map(error)),
        ),
      ),
    );
  }

  Widget _buildBody(String userId, Profile profile, VerificationTier? tier) {
    final unlocked = tier?.isAtLeastSelfieVerified ?? false;
    final hasPhoto = profile.profilePhotoUrl != null && profile.profilePhotoUrl!.isNotEmpty;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const SectionHeader(
          title: 'Profile photo',
          subtitle: 'Avatars are always shown first. Add a real photo once you\'re verified.',
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: hasPhoto
              ? SignedAvatarDisplay(
                  avatarId: profile.avatarId,
                  photoPath: profile.profilePhotoUrl,
                  showPhoto: true,
                  size: 44,
                )
              : Icon(unlocked ? Icons.add_a_photo_outlined : Icons.lock_outline,
                  color: unlocked ? null : AppColors.textSecondary),
          title: Text(hasPhoto ? 'Change picture' : 'Add picture'),
          subtitle: Text(
            unlocked
                ? (hasPhoto ? 'Tap to choose a different photo.' : 'Choose a photo to add to your profile.')
                : 'Verify you\'re real to unlock this.',
          ),
          trailing: _isUploadingPhoto ? const LoadingIndicator() : const Icon(Icons.chevron_right),
          onTap: _isUploadingPhoto ? null : () => _addPicture(userId, tier),
        ),
        if (hasPhoto) ...[
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Visible to others'),
            value: _isPhotoPublic ?? false,
            onChanged: (value) => _setPhotoVisibility(userId, value),
          ),
        ],
        if (_photoError != null) ...[
          const SizedBox(height: 8),
          ErrorBanner(message: _photoError!),
        ],
        const SizedBox(height: 16),
        const SectionHeader(
          title: 'Pause my profile',
          subtitle: 'Hide your profile from new matches without deleting anything. Existing '
              'chats stay open, and you can turn this back on any time.',
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Profile visible to new matches'),
          value: _isProfileActive ?? true,
          onChanged: (value) => setState(() => _isProfileActive = value),
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
        const SizedBox(height: 40),
        const SectionHeader(
          title: 'Danger zone',
          subtitle: 'Permanently deletes your photos, voice intro, and identity documents, and '
              "hides your profile. This can't be undone. Your account can't be recovered "
              'afterward, but you can always sign up again with a new account.',
        ),
        if (_deleteError != null) ...[
          const SizedBox(height: 8),
          ErrorBanner(message: _deleteError!),
        ],
        const SizedBox(height: 12),
        PearmoButton(
          label: 'Delete account',
          variant: PearmoButtonVariant.danger,
          icon: Icons.delete_outline,
          isLoading: _isDeletingAccount,
          onPressed: _isDeletingAccount ? null : _confirmDeleteAccount,
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
