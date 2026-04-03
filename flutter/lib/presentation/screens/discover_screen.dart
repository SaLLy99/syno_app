import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:go_router/go_router.dart';
import 'package:syno_app/domain/entities/match.dart';
import 'package:syno_app/presentation/providers/match_provider.dart';
import 'package:syno_app/presentation/widgets/bottom_nav_bar.dart';
import 'package:syno_app/presentation/widgets/match_score_badge.dart';
import 'package:syno_app/theme.dart';
import 'package:syno_app/presentation/providers/theme_provider.dart';

class DiscoverScreen extends ConsumerStatefulWidget {
  const DiscoverScreen({super.key});

  @override
  ConsumerState<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends ConsumerState<DiscoverScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<Match>> potentialMatchesAsync = ref.watch(potentialMatchesProvider);
    final theme = ref.watch(themeProvider);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
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
            Text('discover.title'.tr(),
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(gradient: theme.gradient),
        child: Stack(
          children: [
            Positioned(
              top: 120,
              left: 0,
              right: 0,
              child: Container(
                height: 250,
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: <Color>[
                      const Color(0xFFDB2777).withOpacity(0.1),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            SafeArea(
              child: potentialMatchesAsync.when(
                data: (List<Match> matches) {
                  if (matches.isEmpty) {
                    return _buildEmptyState(context);
                  }
                  return _buildMatchCards(context, matches);
                },
                loading: () => Center(child: Text('discover.loading'.tr(), style: const TextStyle(color: Colors.white70))),
                error: (Object error, StackTrace stack) => Center(
                  child: Text(
                    'discover.error_subtitle'.tr(),
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.white),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMatchCards(BuildContext context, List<Match> matches) {
    if (_currentIndex >= matches.length) {
      return _buildEmptyState(context);
    }

    final Match currentMatch = matches[_currentIndex];

    return Stack(
      children: <Widget>[
        for (int i = _currentIndex; i < (_currentIndex + 2).clamp(0, matches.length); i++)
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.only(
                left: AppSpacing.md + (i - _currentIndex) * 8,
                right: AppSpacing.md + (i - _currentIndex) * 8,
                top: AppSpacing.md + (i - _currentIndex) * 8,
                bottom: 120 + (i - _currentIndex) * 8,
              ),
              child: _buildMatchCard(context, matches[i]),
            ),
          ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 20,
          child: _buildActionButtons(currentMatch),
        ),
      ],
    );
  }

  Widget _buildMatchCard(BuildContext context, Match match) {
    return GestureDetector(
      onTap: () => context.push('/match-details', extra: match),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.xl),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Colors.white24, // Use a const color or withOpacity
              blurRadius: 20,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.xl),
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
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
                    colors: <Color>[
                      Colors.transparent,
                      Colors.black.withOpacity(0.8),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons(Match match) {
    return Padding(
      padding: AppSpacing.horizontalXl,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: <Widget>[
          _buildActionButton(
            icon: Icons.close,
            color: Colors.red,
            onPressed: () async {
              await ref.read(matchActionsProvider).saveMatch(match.copyWith(status: MatchStatus.declined));
              setState(() => _currentIndex++);
            },
          ),
          _buildActionButton(
            icon: Icons.info_outline,
            color: CosmicColors.cosmicBlue,
            size: 56,
            onPressed: () => context.push('/match-details', extra: match),
          ),
          _buildActionButton(
            icon: Icons.favorite,
            color: CosmicColors.cosmicPink,
            onPressed: () async {
              await ref.read(matchActionsProvider).saveMatch(match.copyWith(status: MatchStatus.accepted));
              setState(() => _currentIndex++);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
    double size = 64,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: IconButton(
        icon: Icon(icon, color: color, size: size * 0.5),
        onPressed: onPressed,
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
                shape: BoxShape.circle, // Removed const
                color: Colors.white.withOpacity(0.1),
              ),
              child: const Icon(Icons.favorite_border, size: 64, color: Colors.white),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text(
              'discover.no_matches_title'.tr(),
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'discover.no_matches_subtitle'.tr(),
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
}
