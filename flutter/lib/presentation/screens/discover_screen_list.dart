import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:syno_app/domain/entities/match.dart';
import 'package:syno_app/presentation/providers/auth_providers.dart';
import 'package:syno_app/presentation/providers/match_provider.dart';
import 'package:syno_app/presentation/widgets/match_found_dialog.dart';
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
    final AppThemeData theme = ref.watch(themeProvider);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: theme.gradient),
        child: SafeArea(
          child: Column(
            children: <Widget>[
              _buildAppBar(context),
              Expanded(
                child: potentialMatchesAsync.when(
                  data: (List<Match> matches) {
                    if (matches.isEmpty) {
                      return _buildEmptyState(context);
                    }
                    return _buildMatchCards(context, matches);
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (Object error, StackTrace stack) => Center(
                    child: Text(
                      'Error loading matches',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.white),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNav(context),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return Padding(
      padding: AppSpacing.paddingMd,
      child: Row(
        children: <Widget>[
          const SizedBox(width: 48), // Placeholder for alignment
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
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    'Discover', // Changed title to 'Discover'
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white),
            onPressed: () => context.push('/profile'),
          ),
        ],
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
              color: CosmicColors.black30,
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
                match.matchedUser.photos.first.getFullUrl(ref.read(backendUrlProvider)),
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
              Positioned(
                top: AppSpacing.md,
                right: AppSpacing.md,
                child: MatchScoreBadge(score: match.finalScore),
              ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Padding(
                  padding: AppSpacing.paddingLg,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              '${match.matchedUser.name}, ${match.matchedUser.age}',
                              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        match.cosmicInsight,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withOpacity(0.9),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        match.matchedUser.bio.toString(),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withOpacity(0.8),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
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
              final Match? matchedResult = await ref.read(matchActionsProvider).saveMatch(match.copyWith(status: MatchStatus.accepted));
              setState(() => _currentIndex++);
              if (matchedResult != null && context.mounted) {
                MatchFoundDialog.show(
                  context,
                  matchedUser: match.matchedUser,
                  match: matchedResult,
                  baseUrl: ref.read(backendUrlProvider),
                );
              }
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
          BoxShadow( // Cannot be const as 'color' is dynamic
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
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.1),
              ),
              child: const Icon(Icons.favorite_border, size: 64, color: Colors.white),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text(
              'No More Matches',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Check back later for new cosmic connections',
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

  Widget _buildBottomNav(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: CosmicColors.deepSpace,
        boxShadow: <BoxShadow>[
          BoxShadow( // Restored const
            color: CosmicColors.black20,
            blurRadius: 10,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: AppSpacing.verticalSm,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: <Widget>[
              _buildNavItem(Icons.explore, 'Discover', true, () {}),
              _buildNavItem(Icons.favorite, 'Matches', false, () => context.push('/matches')),
            _buildNavItem(Icons.chat, 'Chat', false, () => context.push('/chat')),
              _buildNavItem(Icons.person, 'Profile', false, () => context.push('/profile')),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, bool isActive, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            icon,
            color: isActive ? CosmicColors.cosmicPink : Colors.white.withOpacity(0.6),
            size: 28,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: isActive ? CosmicColors.cosmicPink : Colors.white.withOpacity(0.6),
              fontSize: 12,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
