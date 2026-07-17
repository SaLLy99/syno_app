import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:syno_app/domain/entities/match.dart';
import 'package:syno_app/domain/entities/synastry_data.dart';
import 'package:syno_app/presentation/providers/theme_provider.dart';
import 'package:syno_app/theme.dart';

class SynastryReportScreen extends ConsumerWidget {
  final Match match;

  const SynastryReportScreen({super.key, required this.match});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppThemeData theme = ref.watch(themeProvider);
    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: BoxDecoration(gradient: theme.gradient),
        child: CustomScrollView(
          slivers: <Widget>[
            SliverAppBar(
              pinned: true,
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(
                icon: Icon(Icons.arrow_back, color: theme.primaryTextColor),
                onPressed: () => context.pop(),
              ),
              title: Text(
                'Full Synastry Report',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: theme.primaryTextColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: AppSpacing.paddingLg,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    _buildHeader(context),
                    const SizedBox(height: AppSpacing.xl),
                    _buildOverallInterpretation(context),
                    const SizedBox(height: AppSpacing.xl),
                    _buildDetailedAspects(context),
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

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: AppSpacing.paddingLg,
      decoration: BoxDecoration(
        gradient: CosmicColors.cosmicGradient,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: CosmicColors.cosmicPurple30, // Use const color
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: <Widget>[
          Text(
            'Cosmic Compatibility Analysis',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'You & ${match.matchedUser.name}',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Colors.white.withOpacity(0.9),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Overall Score: ${match.synastryData.overallScore.toStringAsFixed(0)}%',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverallInterpretation(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Overall Interpretation',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Container(
          padding: AppSpacing.paddingMd,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Text(
            match.synastryData.interpretation,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Colors.white.withOpacity(0.9),
              height: 1.6,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailedAspects(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Detailed Planetary Aspects',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        ...match.synastryData.detailedAspects.map((Aspect aspect) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.lg),
              child: Container(
                padding: AppSpacing.paddingMd,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(
                    color: _getAspectColor(aspect.score).withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                            vertical: AppSpacing.xs,
                          ),
                          decoration: BoxDecoration(
                            color: _getAspectColor(aspect.score).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                          ),
                          child: Text(
                            aspect.aspectType,
                            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              color: _getAspectColor(aspect.score),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            '${aspect.planet1} - ${aspect.planet2}',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Text(
                          '${aspect.score.toStringAsFixed(0)}%',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: _getAspectColor(aspect.score),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      aspect.description,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withOpacity(0.8),
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            )),
      ],
    );
  }

  Color _getAspectColor(double score) {
    if (score >= 80) return CosmicColors.cosmicPurple;
    if (score >= 65) return CosmicColors.cosmicPink;
    if (score >= 50) return CosmicColors.cosmicBlue;
    return Colors.grey;
  }
}
