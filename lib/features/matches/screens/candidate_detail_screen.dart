import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/error_mapper.dart';
import '../../../data/models/public_profile.dart';
import '../../../providers/auth_providers.dart';
import '../../../providers/connections_providers.dart';
import '../../../providers/matches_providers.dart';
import '../../../providers/repository_providers.dart';
import '../../../shared/widgets/widgets.dart';

/// Full view of one of today's candidates. The user decides here whether to
/// send a connection request or pass — there is no swipe gesture.
class CandidateDetailScreen extends ConsumerStatefulWidget {
  const CandidateDetailScreen({super.key, required this.candidateId});

  final String candidateId;

  @override
  ConsumerState<CandidateDetailScreen> createState() => _CandidateDetailScreenState();
}

class _CandidateDetailScreenState extends ConsumerState<CandidateDetailScreen> {
  bool _isActing = false;
  String? _error;

  Future<void> _pass() async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;

    setState(() {
      _isActing = true;
      _error = null;
    });
    try {
      await ref.read(matchesRepositoryProvider).markMatchAction(
            userId: userId,
            candidateId: widget.candidateId,
            action: 'passed',
          );
      ref.invalidate(dailyMatchCardsProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() => _error = ErrorMapper.map(e));
    } finally {
      if (mounted) setState(() => _isActing = false);
    }
  }

  Future<void> _sendRequest() async {
    if (_isActing) return;
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;

    // Set before the first await so a second fast tap can't slip through
    // while this call is still checking `canSendRequestProvider`.
    setState(() {
      _isActing = true;
      _error = null;
    });

    final canSend = await ref.read(canSendRequestProvider.future);
    if (!canSend) {
      setState(() {
        _isActing = false;
        _error =
            'You already have an active connection. End it before connecting with someone new.';
      });
      return;
    }

    try {
      await ref.read(connectionsRepositoryProvider).sendConnectionRequest(
            userId: userId,
            candidateId: widget.candidateId,
          );
      ref.invalidate(dailyMatchCardsProvider);
      ref.invalidate(activeConnectionProvider);
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Request sent! Pearmo will let you know if they accept.')),
        );
      }
    } catch (e) {
      setState(() => _error = ErrorMapper.map(e));
    } finally {
      if (mounted) setState(() => _isActing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(candidateProfileProvider(widget.candidateId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            onPressed: () => context.push('/report?reportedId=${widget.candidateId}'),
            icon: const Icon(Icons.flag_outlined),
            tooltip: 'Report',
          ),
        ],
      ),
      body: profileAsync.when(
        data: (profile) => _buildBody(context, profile),
        loading: () => const LoadingIndicator(),
        error: (error, _) => Padding(
          padding: const EdgeInsets.all(20),
          child: ErrorBanner(message: ErrorMapper.map(error)),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, PublicProfile profile) {
    // Today's match row for this candidate (already fetched for the list
    // screen) — reused here for the score chip. Purely display data.
    final matchCards = ref.watch(dailyMatchCardsProvider).valueOrNull;
    final score = matchCards
        ?.where((c) => c.match.candidateId == widget.candidateId)
        .firstOrNull
        ?.match
        .score;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              HeroProfileCard(
                avatarId: profile.avatarId,
                photoPath: profile.profilePhotoUrl,
                showPhoto: profile.hasPublicPhoto,
                title: '${profile.age} · ${profile.gender.label}',
                subtitle: profile.regionName,
                tierLabel: profile.verificationTier.label,
                isVerified: profile.verificationTier.label != 'Unverified',
                matchPercent: score == null ? null : (score * 100).round().clamp(0, 100),
              ),
              const SizedBox(height: 12),
              if (profile.audioIntroUrl != null && profile.audioIntroUrl!.isNotEmpty) ...[
                AudioIntroPlayer(storagePath: profile.audioIntroUrl!),
                const SizedBox(height: 12),
              ],
              QuoteCard(
                label: 'In their own words',
                text: profile.aboutText,
                emptyPlaceholder: 'No bio yet.',
              ),
              const SizedBox(height: 12),
              BentoCard(
                label: 'Looking for',
                child: AttributeChipList(labels: [profile.relationshipIntent.label]),
              ),
              if (profile.partnerValues.isNotEmpty) ...[
                const SizedBox(height: 12),
                BentoCard(
                  label: 'Values most in a partner',
                  child:
                      AttributeChipList(labels: profile.partnerValues.map((e) => e.label).toList()),
                ),
              ],
              if (profile.musicGenres.isNotEmpty) ...[
                const SizedBox(height: 12),
                BentoCard(
                  label: 'Music taste',
                  child:
                      AttributeChipList(labels: profile.musicGenres.map((e) => e.label).toList()),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 16),
                ErrorBanner(message: _error!),
              ],
            ],
          ),
        ),
        SafeArea(
          minimum: const EdgeInsets.all(20),
          child: Row(
            children: [
              Expanded(
                child: PearmoButton(
                  label: 'Pass',
                  variant: PearmoButtonVariant.outline,
                  icon: Icons.close,
                  isLoading: _isActing,
                  onPressed: _isActing ? null : _pass,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: PearmoButton(
                  label: 'Send Request',
                  icon: Icons.favorite,
                  isLoading: _isActing,
                  onPressed: _isActing ? null : _sendRequest,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
