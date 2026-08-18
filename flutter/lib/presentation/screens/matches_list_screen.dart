import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:go_router/go_router.dart';
import 'package:syno_app/domain/entities/match.dart';
import 'package:syno_app/domain/entities/synastry_data.dart';
import 'package:syno_app/domain/entities/user.dart';
import 'package:syno_app/presentation/providers/match_provider.dart';
import 'package:syno_app/presentation/providers/auth_providers.dart';
import 'package:syno_app/presentation/widgets/match_score_badge.dart';
import 'package:syno_app/theme.dart';
import 'package:syno_app/presentation/providers/theme_provider.dart';

class MatchesListScreen extends ConsumerWidget {
  const MatchesListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<BackendMatchItem>> matchesAsync = ref.watch(matchesFromBackendProvider);
    final AppThemeData theme = ref.watch(themeProvider);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: theme.gradient),
        child: SafeArea(
          child: Column(
            children: <Widget>[
              _buildAppBar(context),
              Expanded(
                child: matchesAsync.when(
                  data: (List<BackendMatchItem> matches) {
                    final accepted = matches.where((m) => m.status == 'accepted').toList();
                    if (accepted.isEmpty) {
                      return _buildEmptyState(context);
                    }
                    return ListView.builder(
                      padding: AppSpacing.paddingMd,
                      itemCount: accepted.length,
                      itemBuilder: (BuildContext context, int index) {
                        final match = accepted[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.md),
                          child: _buildMatchCard(context, match, ref),
                        );
                      },
                    );
                  },
                  loading: () => Center(child: Text('matches_list.loading'.tr(), style: const TextStyle(color: Colors.white70))),
                  error: (Object error, StackTrace stack) => _buildErrorState(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return Padding(
      padding: AppSpacing.paddingMd,
      child: Row(
        children: <Widget>[
          const SizedBox(width: 48),
          Expanded(
            child: Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: SizedBox(
                      width: 30,
                      height: 30,
                      child: ClipOval(
                        child: Image.asset(
                          'assets/icons/dreamflow_icon.jpg',
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                  Text(
                    'matches_list.title'.tr(),
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildMatchCard(BuildContext context, BackendMatchItem match, WidgetRef ref) {
    final String? baseUrl = ref.read(backendUrlProvider);
    final String photoUrl = match.matchedPhotoUrl != null && baseUrl != null
        ? '$baseUrl${match.matchedPhotoUrl}'
        : '';

    final matchObj = Match(
      id: match.matchId.toString(),
      userId: '0',
      matchedUserId: match.matchedUserId.toString(),
      matchedUser: User(
        id: match.matchedUserId,
        userId: match.matchedUserId,
        name: match.matchedName ?? 'Unknown',
        photos: photoUrl.isNotEmpty ? [Photo(id: 0, url: photoUrl, isPrimary: true)] : [],
      ),
      finalScore: (match.compatibilityScore ?? 0).toDouble(),
      synastryScore: 0,
      behavioralScore: 0,
      topReasons: const <String>[],
      cosmicInsight: 'Cosmic connection found',
      synastryData: SynastryData(
        moonScore: 0, mercuryScore: 0, venusMarsScore: 0,
        nodesScore: 0, saturnScore: 0,
        detailedAspects: const <Aspect>[],
        interpretation: '',
      ),
      status: MatchStatus.accepted,
      createdAt: DateTime.now(),
      backendMatchId: match.matchId,
    );

    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(
        children: <Widget>[
          GestureDetector(
            onTap: () => context.push('/match-details', extra: matchObj),
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(AppRadius.lg),
                bottomLeft: Radius.circular(AppRadius.lg),
              ),
              child: photoUrl.isNotEmpty
                  ? Image.network(
                      photoUrl,
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                      errorBuilder: (BuildContext context, Object error, StackTrace? stackTrace) => _buildPlaceholderPhoto(),
                    )
                  : _buildPlaceholderPhoto(),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: GestureDetector(
                          onTap: () => context.push('/match-details', extra: matchObj),
                          child: Text(
                            match.matchedName ?? 'Unknown',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      MatchScoreBadge(score: (match.compatibilityScore ?? 0).toDouble(), size: 34),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => context.push('/match-details', extra: matchObj),
                          child: Text(
                            '${(match.compatibilityScore ?? 0)}% compatible',
                            style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => context.push('/chat', extra: matchObj),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF6C63FF), Color(0xFF3B82F6)],
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.chat_bubble_outline, color: Colors.white, size: 12),
                              SizedBox(width: 3),
                              Text('Message', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholderPhoto() {
    return Container(
      width: 80,
      height: 80,
      color: CosmicColors.cosmicPurple,
      child: const Icon(Icons.person, size: 32, color: Colors.white),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: AppSpacing.paddingXl,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.1),
              ),
              child: const Icon(Icons.favorite_border, size: 64, color: Colors.white),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text(
              'matches_list.no_matches_title'.tr(),
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'matches_list.no_matches_subtitle'.tr(),
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Colors.white.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context) {
    return Center(
      child: Padding(
        padding: AppSpacing.paddingXl,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.1),
              ),
              child: const Icon(Icons.error_outline, size: 64, color: Colors.white),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text(
              'matches_list.error_title'.tr(),
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'matches_list.error_subtitle'.tr(),
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.white.withOpacity(0.7)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
