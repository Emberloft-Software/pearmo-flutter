import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/error_mapper.dart';
import '../../../providers/auth_providers.dart';
import '../../../providers/connections_providers.dart';
import '../../../providers/matches_providers.dart';
import '../../../providers/repository_providers.dart';
import '../../../shared/widgets/widgets.dart';

/// The connection tab: shows an incoming request to respond to, or the
/// user's current active connection status. The full chat/consent/games
/// hub for an active connection is built out in Phase 4.
class ConnectionHubScreen extends ConsumerStatefulWidget {
  const ConnectionHubScreen({super.key});

  @override
  ConsumerState<ConnectionHubScreen> createState() => _ConnectionHubScreenState();
}

class _ConnectionHubScreenState extends ConsumerState<ConnectionHubScreen> {
  String? _respondingTo;
  String? _error;

  Future<void> _respond(String connectionId, bool accept) async {
    setState(() {
      _respondingTo = connectionId;
      _error = null;
    });
    try {
      await ref.read(connectionsRepositoryProvider).respondToConnection(
            connectionId: connectionId,
            accept: accept,
          );
      ref.invalidate(incomingRequestsProvider);
      ref.invalidate(activeConnectionProvider);
    } catch (e) {
      setState(() => _error = ErrorMapper.map(e));
    } finally {
      if (mounted) setState(() => _respondingTo = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeAsync = ref.watch(activeConnectionProvider);
    final incomingAsync = ref.watch(incomingRequestsProvider);
    final outgoingAsync = ref.watch(outgoingPendingRequestProvider);
    final userId = ref.watch(currentUserIdProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Connections')),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async {
          ref.invalidate(activeConnectionProvider);
          ref.invalidate(incomingRequestsProvider);
          ref.invalidate(outgoingPendingRequestProvider);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          children: [
            if (_error != null) ...[
              ErrorBanner(message: _error!),
              const SizedBox(height: 16),
            ],
            incomingAsync.when(
              data: (requests) {
                if (requests.isEmpty) return const SizedBox.shrink();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionHeader(title: 'New requests'),
                    ...requests.map((request) {
                      final otherUserId = userId != null ? request.otherUserId(userId) : null;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _IncomingRequestCard(
                          candidateId: otherUserId,
                          isResponding: _respondingTo == request.id,
                          onAccept: () => _respond(request.id, true),
                          onDecline: () => _respond(request.id, false),
                        ),
                      );
                    }),
                    const SizedBox(height: 24),
                  ],
                );
              },
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: LoadingIndicator(),
              ),
              error: (error, _) => ErrorBanner(message: ErrorMapper.map(error)),
            ),
            const SectionHeader(title: 'Your connection'),
            activeAsync.when(
              data: (connection) {
                if (connection == null) {
                  // No active connection yet — but a sent request might
                  // still be awaiting a response, which `activeConnection`
                  // deliberately excludes (see `getActiveConnection`). Show
                  // that instead of a plain "nothing here" empty state.
                  return outgoingAsync.when(
                    data: (outgoing) {
                      if (outgoing == null) {
                        return const EmptyState(
                          icon: Icons.favorite_border,
                          title: 'No active connection',
                          message:
                              'When you and a match both want to connect, your conversation starts '
                              'here, one connection at a time, so you can focus on getting to know '
                              'each other.',
                        );
                      }
                      return _ActiveConnectionCard(
                        otherUserId: outgoing.receiverId,
                        statusLabel: 'Waiting for response',
                        statusColor: StatusPill.colorFor('pending'),
                        caption: "Request sent. We'll let you know as soon as they respond.",
                        onTap: null,
                      );
                    },
                    loading: () => const LoadingIndicator(),
                    error: (error, _) => ErrorBanner(message: ErrorMapper.map(error)),
                  );
                }
                final statusColor = StatusPill.colorFor(connection.status.dbValue);
                final otherUserId = userId != null ? connection.otherUserId(userId) : null;
                return _ActiveConnectionCard(
                  otherUserId: otherUserId,
                  statusLabel: connection.status.label,
                  statusColor: statusColor,
                  caption: connection.status.canChat
                      ? 'Chat is open. Keep getting to know each other.'
                      : 'Break the ice with a quick game before chat unlocks.',
                  onTap: () => context.push('/connection/${connection.id}'),
                );
              },
              loading: () => const LoadingIndicator(),
              error: (error, _) => ErrorBanner(message: ErrorMapper.map(error)),
            ),
          ],
        ),
      ),
    );
  }

}

/// The single active connection, as a tappable bento card: the other
/// person's avatar on the stage gradient, a color-coded status pill and a
/// one-line hint of what to do next.
class _ActiveConnectionCard extends ConsumerWidget {
  const _ActiveConnectionCard({
    required this.otherUserId,
    required this.statusLabel,
    required this.statusColor,
    required this.caption,
    required this.onTap,
  });

  final String? otherUserId;
  final String statusLabel;
  final Color statusColor;
  final String caption;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync =
        otherUserId != null ? ref.watch(candidateProfileProvider(otherUserId!)) : null;

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.divider),
          ),
          child: Row(
            children: [
              if (profileAsync != null)
                profileAsync.when(
                  data: (profile) => AvatarDisplay(avatarId: profile.avatarId, size: 64),
                  loading: () => const SizedBox(width: 64, height: 64),
                  error: (_, _) => const SizedBox(width: 64, height: 64),
                ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    StatusPill(label: statusLabel, color: statusColor),
                    const SizedBox(height: 8),
                    Text(caption, style: AppTextStyles.caption),
                  ],
                ),
              ),
              if (onTap != null) const Icon(Icons.chevron_right, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

class _IncomingRequestCard extends ConsumerWidget {
  const _IncomingRequestCard({
    required this.candidateId,
    required this.isResponding,
    required this.onAccept,
    required this.onDecline,
  });

  final String? candidateId;
  final bool isResponding;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync =
        candidateId != null ? ref.watch(candidateProfileProvider(candidateId!)) : null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.pink.withValues(alpha: 0.45), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (profileAsync != null)
                profileAsync.when(
                  data: (profile) => AvatarDisplay(avatarId: profile.avatarId, size: 52),
                  loading: () => const SizedBox(width: 52, height: 52),
                  error: (_, _) => const SizedBox(width: 52, height: 52),
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Someone wants to connect', style: AppTextStyles.title),
                    const SizedBox(height: 2),
                    Text(
                      'Open to see if the spark is mutual.',
                      style: AppTextStyles.caption.copyWith(color: AppColors.magenta),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: PearmoButton(
                  label: 'Decline',
                  variant: PearmoButtonVariant.outline,
                  isLoading: isResponding,
                  onPressed: isResponding ? null : onDecline,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: PearmoButton(
                  label: 'Accept',
                  isLoading: isResponding,
                  onPressed: isResponding ? null : onAccept,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
