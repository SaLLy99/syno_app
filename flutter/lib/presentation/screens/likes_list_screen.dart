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

class LikesListScreen extends ConsumerWidget {
  const LikesListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<IncomingLike>> likesAsync = ref.watch(incomingLikesProvider);
    final AppThemeData theme = ref.watch(themeProvider);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: theme.gradient),
        child: SafeArea(
          child: Column(
            children: <Widget>[
              _buildAppBar(context, likesAsync),
              Expanded(
                child: likesAsync.when(
                  data: (List<IncomingLike> likes) {
                    if (likes.isEmpty) {
                      return _buildEmptyState(context);
                    }
                    return ListView.builder(
                      padding: AppSpacing.paddingMd,
                      itemCount: likes.length,
                      itemBuilder: (BuildContext context, int index) {
                        final IncomingLike like = likes[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.md),
                          child: _buildLikeCard(context, like, ref),
                        );
                      },
                    );
                  },
                  loading: () => Center(child: Text('likes_list.loading'.tr(), style: const TextStyle(color: Colors.white70))),
                  error: (Object error, StackTrace stack) => _buildErrorState(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context, AsyncValue<List<IncomingLike>> likesAsync) {
    return Padding(
      padding: AppSpacing.paddingMd,
      child: Row(
        children: <Widget>[
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
                  onPressed: () => context.go('/discover'),
                ),
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
                          'likes_list.title'.tr(),
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                        likesAsync.when(
                          data: (List<IncomingLike> likes) {
                            if (likes.isEmpty) return const SizedBox.shrink();
                            return Container(
                              margin: const EdgeInsets.only(left: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${likes.length}',
                                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            );
                          },
                          loading: () => const SizedBox.shrink(),
                          error: (_, __) => const SizedBox.shrink(),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLikeCard(BuildContext context, IncomingLike like, WidgetRef ref) {
    final String? baseUrl = ref.read(backendUrlProvider);
    final String photoUrl = like.photoUrl != null && baseUrl != null
        ? '$baseUrl${like.photoUrl}'
        : '';

    int? age;
    if (like.birthDate != null) {
      try {
        final DateTime bd = DateTime.parse(like.birthDate!);
        final DateTime now = DateTime.now();
        age = now.year - bd.year;
        if (now.month < bd.month || (now.month == bd.month && now.day < bd.day)) {
          age--;
        }
      } catch (_) {}
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        children: <Widget>[
          GestureDetector(
            onTap: () {
              final matchObj = Match(
                id: like.matchId.toString(),
                userId: '0',
                matchedUserId: like.userId.toString(),
                matchedUser: User(
                  id: like.userId,
                  userId: like.userId,
                  name: '${like.name ?? 'Unknown'}${like.lastName != null ? ' ${like.lastName}' : ''}',
                  photos: photoUrl.isNotEmpty ? [Photo(id: 0, url: photoUrl, isPrimary: true)] : [],
                  bio: like.bio,
                  birthDate: like.birthDate != null ? DateTime.tryParse(like.birthDate!) : null,
                ),
                finalScore: (like.compatibilityScore ?? 0).toDouble(),
                synastryScore: 0,
                behavioralScore: 0,
                topReasons: const <String>[],
                cosmicInsight: 'Someone is interested in you!',
                synastryData: SynastryData(
                  moonScore: 0, mercuryScore: 0, venusMarsScore: 0,
                  nodesScore: 0, saturnScore: 0,
                  detailedAspects: const <Aspect>[],
                  interpretation: '',
                ),
                status: MatchStatus.accepted,
                createdAt: like.createdAt ?? DateTime.now(),
                backendMatchId: like.matchId,
              );
              context.push('/match-details', extra: matchObj);
            },
            child: Row(
              children: <Widget>[
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(AppRadius.lg),
                    bottomLeft: Radius.circular(AppRadius.lg),
                  ),
                  child: photoUrl.isNotEmpty
                      ? Image.network(
                          photoUrl,
                          width: 100,
                          height: 120,
                          fit: BoxFit.cover,
                          errorBuilder: (BuildContext context, Object error, StackTrace? stackTrace) => Container(
                            width: 100,
                            height: 120,
                            color: CosmicColors.cosmicPurple,
                            child: const Icon(Icons.person, size: 40, color: Colors.white),
                          ),
                        )
                      : Container(
                          width: 100,
                          height: 120,
                          color: CosmicColors.cosmicPurple,
                          child: const Icon(Icons.person, size: 40, color: Colors.white),
                        ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                '${like.name ?? 'Unknown'}${age != null ? ', $age' : ''}',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (like.compatibilityScore != null)
                              MatchScoreBadge(score: like.compatibilityScore!.toDouble(), size: 36),
                          ],
                        ),
                        if (like.locationName != null) ...<Widget>[
                          const SizedBox(height: 4),
                          Text(
                            like.locationName!,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white70),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        if (like.bio != null && like.bio!.isNotEmpty) ...<Widget>[
                          const SizedBox(height: 4),
                          Text(
                            like.bio!,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white54),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await ref.read(matchActionsProvider).declineIncomingLike(like.matchId);
                    },
                    icon: const Icon(Icons.close, color: Colors.red),
                    label: Text('likes_list.decline'.tr(), style: const TextStyle(color: Colors.red)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.red),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final bool success = await ref.read(matchActionsProvider).acceptIncomingLike(like.matchId);
                      if (success && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('likes_list.match_created'.tr()),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.favorite, color: Colors.white),
                    label: Text('likes_list.accept'.tr(), style: const TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: CosmicColors.cosmicPink,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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
              'likes_list.no_likes_title'.tr(),
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'likes_list.no_likes_subtitle'.tr(),
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
              'likes_list.error_title'.tr(),
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'likes_list.error_subtitle'.tr(),
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.white.withOpacity(0.7)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
