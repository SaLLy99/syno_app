import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:go_router/go_router.dart';
import 'package:syno_app/domain/entities/match.dart';

import 'package:syno_app/domain/entities/user.dart';
import 'package:syno_app/presentation/providers/auth_providers.dart';
import 'package:syno_app/presentation/providers/recommendation_provider.dart';
import 'package:syno_app/presentation/providers/match_provider.dart';
import 'package:syno_app/presentation/providers/theme_provider.dart';
import 'package:syno_app/theme.dart';

class RecommendationsScreen extends ConsumerStatefulWidget {
  const RecommendationsScreen({super.key});

  @override
  ConsumerState<RecommendationsScreen> createState() => _RecommendationsScreenState();
}

class _RecommendationsScreenState extends ConsumerState<RecommendationsScreen> {
  int _currentIndex = 0;
  PageController? _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.85);
  }

  @override
  void dispose() {
    _pageController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<RecommendationItem>> recommendationsAsync =
        ref.watch(dailyRecommendationsProvider);
    final AppThemeData theme = ref.watch(themeProvider);

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
            Text(
              'recommendations.title'.tr(),
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
        child: recommendationsAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: Colors.white),
          ),
          error: (error, stack) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                const Icon(Icons.error_outline, color: Colors.white, size: 48),
                const SizedBox(height: 16),
                Text(
                  'Error loading recommendations',
                  style: TextStyle(color: Colors.white.withOpacity(0.8)),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => ref.invalidate(dailyRecommendationsProvider),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
          data: (List<RecommendationItem> recommendations) {
            if (recommendations.isEmpty) {
              return _buildEmptyState();
            }
            return _buildRecommendationCards(recommendations, theme);
          },
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Icon(
            Icons.auto_awesome,
            color: Colors.white.withOpacity(0.6),
            size: 64,
          ),
          const SizedBox(height: 24),
          Text(
            'recommendations.empty_title'.tr(),
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'recommendations.empty_subtitle'.tr(),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendationCards(
    List<RecommendationItem> recommendations,
    AppThemeData theme,
  ) {
    return Column(
      children: <Widget>[
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            itemCount: recommendations.length,
            onPageChanged: (int index) {
              setState(() => _currentIndex = index);
            },
            itemBuilder: (BuildContext context, int index) {
              final RecommendationItem rec = recommendations[index];
              return _buildRecommendationCard(rec, theme, index);
            },
          ),
        ),
        _buildPageIndicator(recommendations.length),
        const SizedBox(height: 16),
        _buildActionButtons(recommendations),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildRecommendationCard(RecommendationItem rec, AppThemeData theme, int index) {
    final User? profile = rec.profile;
    if (profile == null) return const SizedBox.shrink();

    final String? photoUrl = profile.photos.isNotEmpty
        ? profile.photos.firstWhere((p) => p.isPrimary, orElse: () => profile.photos.first).url
        : null;

    return AnimatedBuilder(
      animation: _pageController ?? AlwaysStoppedAnimation(0),
      builder: (BuildContext context, Widget? child) {
        return AnimatedScale(
          scale: _currentIndex == index ? 1.0 : 0.9,
          duration: const Duration(milliseconds: 300),
          child: child,
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              if (photoUrl != null)
                Image.network(
                  photoUrl.startsWith('http') ? photoUrl : '${ref.read(backendUrlProvider)}$photoUrl',
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => _buildPlaceholderImage(),
                )
              else
                _buildPlaceholderImage(),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: <Color>[
                      Colors.transparent,
                      Colors.black.withOpacity(0.7),
                    ],
                  ),
                ),
              ),
              Positioned(
                top: 16,
                right: 16,
                child: _buildScoreBadge(rec.compatibilityScore ?? rec.score),
              ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: _buildProfileInfo(profile, rec),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholderImage() {
    return Container(
      color: Colors.grey[800],
      child: const Center(
        child: Icon(Icons.person, color: Colors.white54, size: 80),
      ),
    );
  }

  Widget _buildScoreBadge(int score) {
    Color badgeColor;
    if (score >= 80) {
      badgeColor = Colors.green;
    } else if (score >= 60) {
      badgeColor = Colors.blue;
    } else {
      badgeColor = Colors.orange;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: badgeColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: badgeColor.withOpacity(0.5),
            blurRadius: 8,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(Icons.auto_awesome, color: Colors.white, size: 16),
          const SizedBox(width: 4),
          Text(
            '$score%',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileInfo(User profile, RecommendationItem rec) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  '${profile.name ?? ''} ${profile.lastName ?? ''}'.trim(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (profile.age != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${profile.age}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
            ],
          ),
          if (profile.location != null) ...<Widget>[
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                Icon(Icons.location_on, color: Colors.white.withOpacity(0.8), size: 16),
                const SizedBox(width: 4),
                Text(
                  profile.location!.name,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ],
          if (rec.reasons.isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: rec.reasons.take(3).map((String reason) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    reason,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
          if (rec.cosmicInsight.isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            Text(
              rec.cosmicInsight,
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 14,
                fontStyle: FontStyle.italic,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPageIndicator(int length) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List<Widget>.generate(length, (int index) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: _currentIndex == index ? 24 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: _currentIndex == index
                ? Colors.white
                : Colors.white.withOpacity(0.4),
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }

  Widget _buildActionButtons(List<RecommendationItem> recommendations) {
    if (recommendations.isEmpty) return const SizedBox.shrink();

    final RecommendationItem currentRec = recommendations[_currentIndex];
    final User? profile = currentRec.profile;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        _buildActionButton(
          icon: Icons.close,
          color: Colors.red,
          onTap: () {
            if (_currentIndex < recommendations.length - 1) {
              _pageController?.nextPage(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            }
          },
        ),
        const SizedBox(width: 24),
        _buildActionButton(
          icon: Icons.star,
          color: Colors.amber,
          size: 56,
          onTap: () async {
            if (profile != null) {
              final MatchActions actions = ref.read(matchActionsProvider);
              final Match match = Match(
                id: '',
                userId: '',
                matchedUserId: profile.userId.toString(),
                matchedUser: profile,
                finalScore: (currentRec.compatibilityScore ?? currentRec.score).toDouble(),
                synastryScore: (currentRec.compatibilityScore ?? currentRec.score).toDouble(),
                behavioralScore: null,
                topReasons: currentRec.reasons,
                cosmicInsight: currentRec.cosmicInsight,
                status: MatchStatus.pending,
                createdAt: DateTime.now(),
              );
              final Match? matchedResult = await actions.saveMatch(match);
              if (mounted && matchedResult != null) {
                _showMatchFoundDialog(profile);
              }
            }
          },
        ),
        const SizedBox(width: 24),
        _buildActionButton(
          icon: Icons.favorite,
          color: Colors.pink,
          size: 56,
          onTap: () async {
            if (profile != null) {
              final MatchActions actions = ref.read(matchActionsProvider);
              final Match match = Match(
                id: '',
                userId: '',
                matchedUserId: profile.userId.toString(),
                matchedUser: profile,
                finalScore: (currentRec.compatibilityScore ?? currentRec.score).toDouble(),
                synastryScore: (currentRec.compatibilityScore ?? currentRec.score).toDouble(),
                behavioralScore: null,
                topReasons: currentRec.reasons,
                cosmicInsight: currentRec.cosmicInsight,
                status: MatchStatus.pending,
                createdAt: DateTime.now(),
              );
              final Match? matchedResult = await actions.saveMatch(match);
              if (mounted) {
                if (matchedResult != null) {
                  _showMatchFoundDialog(profile);
                } else {
                  if (_currentIndex < recommendations.length - 1) {
                    _pageController?.nextPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  }
                }
              }
            }
          },
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    double size = 48,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color.withOpacity(0.2),
          shape: BoxShape.circle,
          border: Border.all(color: color, width: 2),
        ),
        child: Icon(icon, color: color, size: size * 0.5),
      ),
    );
  }

  void _showMatchFoundDialog(User matchedUser) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Text(
                '🌟',
                style: TextStyle(fontSize: 48),
              ),
              const SizedBox(height: 16),
              Text(
                'It\'s a Match!',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'You and ${matchedUser.name} liked each other',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  context.push('/chat');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.pink,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Send Message'),
              ),
            ],
          ),
        );
      },
    );
  }
}
