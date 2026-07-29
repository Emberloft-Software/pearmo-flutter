import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/enums.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/error_mapper.dart';
import '../../../data/models/connection.dart';
import '../../../providers/auth_providers.dart';
import '../../../providers/connections_providers.dart';
import '../../../providers/consent_providers.dart';
import '../../../providers/matches_providers.dart';
import '../../../providers/profile_providers.dart';
import '../../../providers/repository_providers.dart';
import '../../../shared/avatars/avatar_catalog.dart';
import '../../../shared/widgets/widgets.dart';
import '../../safety/widgets/checkin_panel.dart';
import '../widgets/consent_tile.dart';

/// Status + progressive-unlock consent panel for a single connection.
/// Ice-breaker games and chat (Phase 5) hang off this same connection id.
class ConnectionDetailScreen extends ConsumerStatefulWidget {
  const ConnectionDetailScreen({super.key, required this.connectionId});

  final String connectionId;

  @override
  ConsumerState<ConnectionDetailScreen> createState() => _ConnectionDetailScreenState();
}

class _ConnectionDetailScreenState extends ConsumerState<ConnectionDetailScreen> {
  ConsentType? _consentInFlight;
  bool _isEnding = false;
  String? _error;

  Future<void> _toggleConsent(ConsentType type, bool currentlyGranted) async {
    final granting = !currentlyGranted;
    final confirmed = await ConsentDialog.show(context, type: type, granting: granting);
    if (!confirmed) return;

    setState(() {
      _consentInFlight = type;
      _error = null;
    });
    try {
      await ref.read(consentRepositoryProvider).setConsent(
            connectionId: widget.connectionId,
            type: type,
            consenting: granting,
          );
    } catch (e) {
      setState(() => _error = ErrorMapper.map(e));
    } finally {
      if (mounted) setState(() => _consentInFlight = null);
    }
  }

  Future<void> _endConnection(String userId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('End this connection?'),
        content: const Text(
          "This will end things for both of you and you'll be free to receive new daily matches.",
        ),
        actions: [
          PearmoButton(
            label: 'Cancel',
            variant: PearmoButtonVariant.text,
            expand: false,
            onPressed: () => Navigator.of(context).pop(false),
          ),
          PearmoButton(
            label: 'End connection',
            variant: PearmoButtonVariant.danger,
            expand: false,
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() {
      _isEnding = true;
      _error = null;
    });
    try {
      await ref.read(connectionsRepositoryProvider).endConnection(
            connectionId: widget.connectionId,
            endedBy: userId,
          );
      ref.invalidate(activeConnectionProvider);
      if (mounted) context.pop();
    } catch (e) {
      setState(() => _error = ErrorMapper.map(e));
    } finally {
      if (mounted) setState(() => _isEnding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final connectionAsync = ref.watch(connectionStreamProvider(widget.connectionId));
    final userId = ref.watch(currentUserIdProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Connection'),
        actions: [
          connectionAsync.maybeWhen(
            data: (connection) => connection == null || userId == null
                ? const SizedBox.shrink()
                : IconButton(
                    onPressed: () => context.push(
                        '/report?reportedId=${connection.otherUserId(userId)}&connectionId=${widget.connectionId}'),
                    icon: const Icon(Icons.flag_outlined),
                    tooltip: 'Report',
                  ),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: connectionAsync.when(
        data: (connection) {
          if (connection == null || userId == null) {
            return const EmptyState(
              icon: Icons.link_off,
              title: 'Connection not found',
            );
          }
          return _buildBody(context, connection, userId);
        },
        loading: () => const LoadingIndicator(),
        error: (error, _) => Padding(
          padding: const EdgeInsets.all(20),
          child: ErrorBanner(message: ErrorMapper.map(error)),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, Connection connection, String userId) {
    final otherUserId = connection.otherUserId(userId);
    final profileAsync = ref.watch(candidateProfileProvider(otherUserId));
    final consentsAsync = ref.watch(activeConsentsProvider(widget.connectionId));

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        profileAsync.when(
          data: (profile) {
            final character = AvatarCatalog.resolve(profile.avatarId).character;
            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.divider),
              ),
              child: Row(
                children: [
                  SignedAvatarDisplay(
                    avatarId: profile.avatarId,
                    photoPath: profile.profilePhotoUrl,
                    showPhoto: profile.hasPublicPhoto,
                    size: 64,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${profile.age} · ${profile.gender.label}',
                            style: AppTextStyles.title),
                        const SizedBox(height: 2),
                        Text('The ${character.name}', style: AppTextStyles.caption),
                        const SizedBox(height: 8),
                        StatusPill(
                          label: connection.status.label,
                          color: StatusPill.colorFor(connection.status.dbValue),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
          loading: () => const LoadingIndicator(),
          error: (error, _) => ErrorBanner(message: ErrorMapper.map(error)),
        ),
        // What you two have in common — real genre overlap between your own
        // profile and theirs (both already loaded; no extra queries). The
        // match % chip appears only if this person's daily-match row is
        // still around; otherwise it's omitted rather than faked.
        Builder(builder: (context) {
          final myProfile = ref.watch(myProfileProvider).valueOrNull;
          final theirProfile = ref.watch(candidateProfileProvider(otherUserId)).valueOrNull;
          if (myProfile == null || theirProfile == null) return const SizedBox.shrink();
          final shared =
              theirProfile.musicGenres.where(myProfile.musicGenres.contains).toList();
          if (shared.isEmpty) return const SizedBox.shrink();
          final score = ref
              .watch(dailyMatchCardsProvider)
              .valueOrNull
              ?.where((c) => c.match.candidateId == otherUserId)
              .firstOrNull
              ?.match
              .score;
          return Padding(
            padding: const EdgeInsets.only(top: 12),
            child: TasteMatchCard(
              myAvatarId: myProfile.avatarId,
              theirAvatarId: theirProfile.avatarId,
              sharedGenres: shared,
              matchPercent: score == null ? null : (score * 100).round().clamp(0, 100),
            ),
          );
        }),
        const SizedBox(height: 12),
        // Always available while the connection is live — not just before
        // chat unlocks. `ice_breaker_sessions` RLS has no status
        // restriction at all (see CLAUDE.md), so there's no backend reason
        // to hide this once chat opens; it's just a fun optional extra
        // from then on instead of the unlock incentive.
        if (connection.status != ConnectionStatus.ended)
          Material(
            color: AppColors.secondaryLight,
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => context.push('/connection/${widget.connectionId}/games'),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.secondary),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.extension_outlined, color: AppColors.secondaryDark),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        connection.status.canChat
                            ? 'Play an ice-breaker game together.'
                            : 'Play an ice-breaker game together to unlock chat.',
                        style: AppTextStyles.bodyMedium
                            .copyWith(color: AppColors.secondaryDark),
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: AppColors.secondaryDark),
                  ],
                ),
              ),
            ),
          ),
        if (connection.status.canChat) ...[
          const SizedBox(height: 12),
          PearmoButton(
            label: 'Open chat',
            icon: Icons.chat_bubble_outline,
            onPressed: () => context.push('/connection/${widget.connectionId}/chat'),
          ),
        ],
        if (connection.status == ConnectionStatus.ended) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              'This connection has ended. Head back to Matches to find someone new.',
              style: AppTextStyles.body,
            ),
          ),
          const SizedBox(height: 12),
          PearmoButton(
            label: 'Rate this connection',
            variant: PearmoButtonVariant.outline,
            icon: Icons.star_outline,
            onPressed: () =>
                context.push('/connection/${widget.connectionId}/rate?ratedId=$otherUserId'),
          ),
        ],
        if (connection.status.canChat) ...[
          const SizedBox(height: 24),
          CheckinPanel(connectionId: widget.connectionId),
        ],
        const SizedBox(height: 24),
        const SectionHeader(
          title: 'Shared unlocks',
          subtitle: 'Each of these only unlocks once you both agree.',
        ),
        consentsAsync.when(
          data: (consents) => Column(
            children: ConsentType.values
                .map((type) {
                  final granted = isConsentGranted(consents, widget.connectionId, type.dbValue);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: ConsentTile(
                      type: type,
                      isGranted: granted,
                      isLoading: _consentInFlight == type,
                      onTap: () => _toggleConsent(type, granted),
                    ),
                  );
                })
                .toList(),
          ),
          loading: () => const LoadingIndicator(),
          error: (error, _) => ErrorBanner(message: ErrorMapper.map(error)),
        ),
        if (_error != null) ...[
          const SizedBox(height: 16),
          ErrorBanner(message: _error!),
        ],
        if (connection.status != ConnectionStatus.ended) ...[
          const SizedBox(height: 24),
          PearmoButton(
            label: 'End connection',
            variant: PearmoButtonVariant.danger,
            icon: Icons.close,
            isLoading: _isEnding,
            onPressed: _isEnding ? null : () => _endConnection(userId),
          ),
        ],
      ],
    );
  }
}
