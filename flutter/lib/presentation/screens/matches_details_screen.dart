import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:go_router/go_router.dart';
import 'package:syno_app/domain/entities/match.dart';
import 'package:syno_app/presentation/widgets/cosmic_button.dart';
import 'package:syno_app/presentation/widgets/match_score_badge.dart';
import 'package:syno_app/theme.dart';
import 'package:syno_app/presentation/providers/block_provider.dart';
import 'package:syno_app/presentation/providers/theme_provider.dart';

class MatchDetailsScreen extends ConsumerWidget {
  final Match match;

  const MatchDetailsScreen({super.key, required this.match});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(themeProvider);
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: theme.gradient),
        child: CustomScrollView(
          slivers: [
            _buildAppBar(context),
            SliverToBoxAdapter(
              child: Padding(
                padding: AppSpacing.paddingLg,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildScoreSection(context),
                    const SizedBox(height: AppSpacing.xl),
                    _buildCosmicInsight(context),
                    const SizedBox(height: AppSpacing.xl),
                    _buildTopReasons(context),
                    const SizedBox(height: AppSpacing.xl),
                    _buildSynastryHighlights(context),
                    const SizedBox(height: AppSpacing.xl),
                    _buildActionButtons(context),
                    const SizedBox(height: AppSpacing.xl),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 400,
      pinned: true,
      backgroundColor: CosmicColors.deepSpace,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => context.pop(),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              match.matchedUser.photos.first.url,
              fit: BoxFit.cover,
              errorBuilder: (BuildContext context, Object error, StackTrace? stackTrace) => Container(
                color: CosmicColors.cosmicPurple,
                child: const Icon(Icons.person, size: 100, color: Colors.white),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent, // Colors.transparent is already const
                    CosmicColors.deepSpace.withOpacity(0.9),
                  ],
                ),
              ),
            ),
            Positioned(
              bottom: 60,
              left: AppSpacing.lg,
              right: AppSpacing.lg,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${match.matchedUser.name}, ${match.matchedUser.age}',
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    match.matchedUser.bio.toString(),
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScoreSection(BuildContext context) {
    return Center(
      child: Column(
        children: [
          MatchScoreBadge(score: match.finalScore, size: 100),
          const SizedBox(height: AppSpacing.md),
          Text(
            'match_details.match_percentage'.tr(args: [match.finalScore.toStringAsFixed(0)]),
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'match_details.synastry_score'.tr(args: [match.synastryScore.toStringAsFixed(0)]),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withOpacity(0.7),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Text(
                'match_details.behavioral_score'.tr(args: [match.behavioralScore.toStringAsFixed(0)]),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCosmicInsight(BuildContext context) {
    return Container(
      padding: AppSpacing.paddingLg,
      decoration: BoxDecoration(
        gradient: const LinearGradient( // Restored const
          colors: [
            CosmicColors.cosmicPurple30,
            CosmicColors.cosmicPink30,
          ],
        ),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: CosmicColors.cosmicPurple50,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, color: CosmicColors.cosmicPink, size: 24),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'match_details.cosmic_insight'.tr(),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            match.cosmicInsight,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Colors.white.withOpacity(0.9),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopReasons(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'match_details.top_reasons'.tr(),
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        ...match.topReasons.map((String reason) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: Container(
                padding: AppSpacing.paddingMd,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Text(
                  reason,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ),
            )),
      ],
    );
  }

  Widget _buildSynastryHighlights(BuildContext context) {
    final List<Map<String, dynamic>> highlights = <Map<String, dynamic>>[
      <String, dynamic>{'label': 'match_details.highlights.emotional'.tr(), 'score': match.synastryData.moonScore},
      <String, dynamic>{'label': 'match_details.highlights.communication'.tr(), 'score': match.synastryData.mercuryScore},
      <String, dynamic>{'label': 'match_details.highlights.romantic'.tr(), 'score': match.synastryData.venusMarsScore},
      <String, dynamic>{'label': 'match_details.highlights.soul_bond'.tr(), 'score': match.synastryData.nodesScore},
      <String, dynamic>{'label': 'match_details.highlights.long_term'.tr(), 'score': match.synastryData.saturnScore},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'match_details.synastry_breakdown'.tr(),
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        ...highlights.map((Map<String, dynamic> h) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        h['label'] as String,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withOpacity(0.8),
                        ),
                      ),
                      Text(
                        '${(h['score'] as double).toStringAsFixed(0)}%',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    child: LinearProgressIndicator(
                      value: (h['score'] as double) / 100,
                      backgroundColor: Colors.white.withOpacity(0.2),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        (h['score'] as double) >= 75
                            ? CosmicColors.cosmicPurple
                            : (h['score'] as double) >= 60
                                ? CosmicColors.cosmicPink
                                : CosmicColors.cosmicBlue,
                      ),
                      minHeight: 8,
                    ),
                  ),
                ],
              ),
            )),
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Consumer(builder: (BuildContext context, WidgetRef ref, _) {
      final AsyncValue<bool> isBlockedAsync = ref.watch(isUserBlockedProvider(match.matchedUserId));
      return Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: CosmicButton(
              text: 'match_details.view_full_report'.tr(),
              icon: Icons.article,
              onPressed: () => context.push('/synastry-report', extra: match),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            child: CosmicButton(
              text: 'match_details.send_message'.tr(),
              icon: Icons.chat,
              isOutlined: true,
              onPressed: () => context.push('/chat', extra: match),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          isBlockedAsync.when(
            data: (bool isBlocked) => SizedBox(
              width: double.infinity,
              child: CosmicButton(
                text: isBlocked ? 'match_details.unblock_user'.tr() : 'match_details.block_user'.tr(),
                icon: isBlocked ? Icons.lock_open : Icons.block,
                isOutlined: true,
                onPressed: () => _showBlockSheet(context, ref, isBlocked),
              ),
            ),
            loading: () => const SizedBox.shrink(),
            error: (Object e, _) => const SizedBox.shrink(),
          ),
        ],
      );
    });
  }

  void _showBlockSheet(BuildContext context, WidgetRef ref, bool isBlocked) {
    showModalBottomSheet(
      context: context,
      backgroundColor: CosmicColors.deepSpace,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Padding(
            padding: AppSpacing.paddingLg,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.security, color: Colors.white),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      isBlocked ? 'match_details.unblock_sheet_title'.tr() : 'match_details.block_sheet_title'.tr(),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  isBlocked
                      ? 'match_details.unblock_sheet_subtitle'.tr()
                      : 'match_details.block_sheet_subtitle'.tr(),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withOpacity(0.7),
                      ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text('match_details.cancel'.tr(), style: const TextStyle(color: Colors.white)),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isBlocked ? CosmicColors.cosmicBlue : Colors.red,
                        ),
                        onPressed: () async {
                          Navigator.of(context).pop();
                          if (isBlocked) {
                            await ref.read(blockActionsProvider).unblock(match.matchedUserId);
                          } else {
                            await ref.read(blockActionsProvider).block(match.matchedUserId);
                          }
                        },
                        icon: Icon(isBlocked ? Icons.lock_open : Icons.block, color: Colors.white),
                        label: Text(isBlocked ? 'match_details.unblock'.tr() : 'match_details.block'.tr(), style: const TextStyle(color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
