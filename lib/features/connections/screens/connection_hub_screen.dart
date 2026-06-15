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
    final userId = ref.watch(currentUserIdProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Connections')),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async {
          ref.invalidate(activeConnectionProvider);
          ref.invalidate(incomingRequestsProvider);
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
                  return const EmptyState(
                    icon: Icons.favorite_border,
                    title: 'No active connection',
                    message:
                        'When you and a match both want to connect, your conversation starts '
                        'here — one connection at a time, so you can focus on getting to know '
                        'each other.',
                  );
                }
                return PearmoCard(
                  onTap: () => context.push('/connection/${connection.id}'),
                  child: Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: _statusColor(connection.status.dbValue),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(connection.status.label, style: AppTextStyles.title),
                            const SizedBox(height: 4),
                            Text(
                              connection.status.canChat
                                  ? 'Chat is open — keep getting to know each other.'
                                  : 'Break the ice with a quick game before chat unlocks.',
                              style: AppTextStyles.caption,
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: AppColors.textSecondary),
                    ],
                  ),
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

  Color _statusColor(String status) => switch (status) {
        'pending' => AppColors.statusPending,
        'ice_breaking' => AppColors.statusIceBreaking,
        'limited_chat' => AppColors.statusLimitedChat,
        'open_chat' => AppColors.statusOpenChat,
        'media_unlocked' => AppColors.statusMediaUnlocked,
        'date_planned' => AppColors.statusDatePlanned,
        _ => AppColors.statusEnded,
      };
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

    return PearmoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (profileAsync != null)
                profileAsync.when(
                  data: (profile) => AvatarDisplay(avatarId: profile.avatarId, size: 48),
                  loading: () => const SizedBox(width: 48, height: 48),
                  error: (_, _) => const SizedBox(width: 48, height: 48),
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Someone wants to connect with you',
                  style: AppTextStyles.bodyMedium,
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
