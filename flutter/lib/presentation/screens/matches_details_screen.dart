import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:go_router/go_router.dart';
import 'package:syno_app/domain/entities/match.dart';
import 'package:syno_app/domain/entities/user.dart';
import 'package:syno_app/presentation/providers/auth_providers.dart';
import 'package:syno_app/presentation/widgets/compatibility_meter.dart';
import 'package:syno_app/presentation/widgets/cosmic_button.dart';
import 'package:syno_app/presentation/widgets/match_badge.dart';
import 'package:syno_app/presentation/widgets/match_score_badge.dart';
import 'package:syno_app/theme.dart';
import 'package:syno_app/presentation/providers/block_provider.dart';
import 'package:syno_app/presentation/providers/theme_provider.dart';

class MatchDetailsScreen extends ConsumerStatefulWidget {
  final Match match;

  const MatchDetailsScreen({super.key, required this.match});

  @override
  ConsumerState<MatchDetailsScreen> createState() => _MatchDetailsScreenState();
}

class _MatchDetailsScreenState extends ConsumerState<MatchDetailsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late Map<String, double> _dimensions;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    final Match match = widget.match;
    _dimensions = {
      'Romance': match.synastryData.venusMarsScore,
      'Communication': match.synastryData.mercuryScore,
      'Emotional': match.synastryData.moonScore,
      'Long-term': match.synastryData.saturnScore,
      'Chemistry': match.synastryData.venusMarsScore * 0.95,
      'Spiritual': match.synastryData.nodesScore,
    };
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppThemeData theme = ref.watch(themeProvider);
    final Match match = widget.match;
    final User user = match.matchedUser;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: theme.gradient),
        child: Column(
          children: [
            _buildHeader(context, match, user),
            _buildScoreStrip(context, match),
            _buildTabBar(context),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildAboutTab(user),
                  _buildPhotosTab(user),
                  _buildLifestyleTab(user),
                  _buildBirthChartTab(user),
                  _buildSynastryTab(context, match),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, Match match, User user) {
    return Container(
      height: 320,
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              user.photos.isNotEmpty ? user.photos.first.getFullUrl(ref.read(backendUrlProvider)) : '',
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                color: CosmicColors.cosmicPurple,
                child: const Icon(Icons.person, size: 100, color: Colors.white),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withOpacity(0.9)],
                ),
              ),
            ),
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              left: 8,
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => context.pop(),
              ),
            ),
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              right: 8,
              child: Row(
                children: [
                  MatchScoreBadge(score: match.averageScore, size: 56),
                  const SizedBox(width: 8),
                  PopupMenuButton<String>(
                    icon: Icon(Icons.more_vert, color: Colors.white.withOpacity(0.8)),
                    onSelected: (v) => _handleMenuAction(context, v),
                    itemBuilder: (_) => [
                      PopupMenuItem(value: 'synastry', child: Text('Full Synastry Report')),
                      PopupMenuItem(value: 'block', child: Text('Block User')),
                    ],
                    color: const Color(0xFF2D1B4E),
                  ),
                ],
              ),
            ),
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${user.name}, ${user.age}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (user.location != null)
                    Text(
                      user.location!.localizedDisplayName,
                      style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 14),
                    ),
                  const SizedBox(height: 6),
                  _buildBadgesRow(match),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBadgesRow(Match match) {
    final badges = MatchBadge.getBadgesForScore(match.finalScore, _dimensions);
    if (badges.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: badges.map((b) => MatchBadge(type: b, size: 22)).toList(),
    );
  }

  Widget _buildScoreStrip(BuildContext context, Match match) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: _dimensions.entries.take(4).map((e) {
          final Color scoreColor = e.value >= 80
              ? const Color(0xFF60A5FA)
              : e.value >= 60
                  ? const Color(0xFF3B82F6)
                  : const Color(0xFF93C5FD);
          return Column(
            children: [
              Text(
                '${e.value.toInt()}%',
                style: TextStyle(
                  color: scoreColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              Text(
                e.key,
                style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 10),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTabBar(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white.withOpacity(0.5),
        indicatorColor: const Color(0xFF3B82F6),
        indicatorSize: TabBarIndicatorSize.label,
        labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        unselectedLabelStyle: const TextStyle(fontSize: 12),
        dividerColor: Colors.transparent,
        tabs: const [
          Tab(text: 'About'),
          Tab(text: 'Photos'),
          Tab(text: 'Lifestyle'),
          Tab(text: 'Chart'),
          Tab(text: 'Synastry'),
        ],
      ),
    );
  }

  Widget _buildAboutTab(User user) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (user.bio != null && user.bio!.isNotEmpty) ...[
            _sectionTitle('About Me'),
            const SizedBox(height: 8),
            Text(
              user.bio!,
              style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 15, height: 1.5),
            ),
            const SizedBox(height: 20),
          ],
          if (user.hobbies.isNotEmpty) ...[
            _sectionTitle('Interests'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: user.hobbies.map((h) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: CosmicColors.cosmicPurple.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: CosmicColors.cosmicPurple.withOpacity(0.3)),
                ),
                child: Text(h.name, style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 13)),
              )).toList(),
            ),
            const SizedBox(height: 20),
          ],
          if (user.coreValues.isNotEmpty) ...[
            _sectionTitle('Core Values'),
            const SizedBox(height: 8),
            ...user.coreValues.map((v) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: CosmicColors.cosmicPink, size: 16),
                  const SizedBox(width: 8),
                  Text(v.key, style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 14)),
                ],
              ),
            )),
          ],
          if (user.intentions.isNotEmpty) ...[
            const SizedBox(height: 20),
            _sectionTitle('Looking For'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: user.intentions.map((i) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: CosmicColors.cosmicPink.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: CosmicColors.cosmicPink.withOpacity(0.3)),
                ),
                child: Text(i.key, style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 13)),
              )).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPhotosTab(User user) {
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: user.photos.length,
      itemBuilder: (context, index) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Image.network(
            user.photos[index].getFullUrl(ref.read(backendUrlProvider)),
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => Container(
              color: CosmicColors.cosmicPurple.withOpacity(0.3),
              child: const Icon(Icons.person, color: Colors.white38, size: 40),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLifestyleTab(User user) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _lifestyleRow(Icons.cake, 'Age', '${user.age}'),
          _lifestyleRow(Icons.straighten, 'Height', user.height != null ? '${user.height!.toInt()} cm' : 'Not specified'),
          if (user.sex != null) _lifestyleRow(Icons.person, 'Gender', user.sex!.name),
          if (user.orientation != null) _lifestyleRow(Icons.favorite, 'Orientation', user.orientation!.name),
          if (user.professions.isNotEmpty)
            _lifestyleRow(Icons.work, 'Occupation', user.professions.first.name),
          if (user.educations.isNotEmpty)
            _lifestyleRow(Icons.school, 'Education', user.educations.first.name),
        ],
      ),
    );
  }

  Widget _buildBirthChartTab(User user) {
    final String? zodiac = user.zodiacSign;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          if (zodiac != null) ...[
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    CosmicColors.cosmicPurple.withOpacity(0.2),
                    CosmicColors.cosmicPink.withOpacity(0.2),
                  ],
                ),
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(color: CosmicColors.cosmicPurple.withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  Text(_getZodiacEmoji(zodiac), style: const TextStyle(fontSize: 48)),
                  const SizedBox(height: 12),
                  Text(
                    zodiac,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Sun Sign',
                    style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 14),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
          _sectionTitle('Planet Positions'),
          const SizedBox(height: 8),
          _planetRow('Sun', zodiac ?? 'Unknown', '☉'),
          _planetRow('Moon', 'Scorpio', '☽'),
          _planetRow('Mercury', 'Gemini', '☿'),
          _planetRow('Venus', 'Taurus', '♀'),
          _planetRow('Mars', 'Aries', '♂'),
          const SizedBox(height: 20),
          _sectionTitle('Elements'),
          const SizedBox(height: 8),
          Row(
            children: [
              _elementBar('Fire', 0.3, const Color(0xFFEF4444)),
              const SizedBox(width: 8),
              _elementBar('Earth', 0.25, const Color(0xFF10B981)),
              const SizedBox(width: 8),
              _elementBar('Air', 0.25, CosmicColors.cosmicBlue),
              const SizedBox(width: 8),
              _elementBar('Water', 0.2, CosmicColors.cosmicPurple),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSynastryTab(BuildContext context, Match match) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Column(
              children: [
                Text(
                  'Overall Compatibility',
                  style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 14),
                ),
                const SizedBox(height: 8),
                MatchScoreBadge(score: match.averageScore, size: 80),
                const SizedBox(height: 8),
                Text(
                  '${match.averageScore.toInt()}% Match',
                  style: const TextStyle(
                    color: Color(0xFF60A5FA),
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _sectionTitle('Compatibility Breakdown'),
          const SizedBox(height: 12),
          CompatibilityMeter(label: 'Romance', emoji: '❤️', score: match.synastryData.romanceScore),
          CompatibilityMeter(label: 'Communication', emoji: '🧠', score: match.synastryData.communicationScore),
          CompatibilityMeter(label: 'Emotional', emoji: '🌙', score: match.synastryData.emotionalScore),
          CompatibilityMeter(label: 'Long-term', emoji: '💍', score: match.synastryData.longTermScore),
          CompatibilityMeter(label: 'Chemistry', emoji: '⚡', score: match.synastryData.chemistryScore),
          CompatibilityMeter(label: 'Spiritual', emoji: '✨', score: match.synastryData.spiritualScore),
          const SizedBox(height: 24),
          _buildInsightCard(context, match),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3B82F6),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => context.push('/synastry-detail', extra: match),
              icon: const Icon(Icons.auto_awesome),
              label: const Text('View Full Synastry Report'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInsightCard(BuildContext context, Match match) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF3B82F6).withOpacity(0.15),
            const Color(0xFF1D4ED8).withOpacity(0.15),
          ],
        ),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: const Color(0xFF3B82F6).withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, color: Color(0xFF60A5FA), size: 20),
              const SizedBox(width: 8),
              Text(
                'Cosmic Insight',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            match.cosmicInsight,
            style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 14, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _lifestyleRow(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          Icon(icon, color: CosmicColors.cosmicPink, size: 20),
          const SizedBox(width: 12),
          Text(label, style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 14)),
          const Spacer(),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _planetRow(String planet, String sign, String symbol) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        children: [
          Text(symbol, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 12),
          Text(planet, style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 14)),
          const Spacer(),
          Text(sign, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _elementBar(String label, double value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(label, style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 11)),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: value,
              backgroundColor: Colors.white.withOpacity(0.1),
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 60,
            ),
          ),
        ],
      ),
    );
  }

  String _getZodiacEmoji(String sign) {
    const emojis = {
      'Aries': '♈', 'Taurus': '♉', 'Gemini': '♊', 'Cancer': '♋',
      'Leo': '♌', 'Virgo': '♍', 'Libra': '♎', 'Scorpio': '♏',
      'Sagittarius': '♐', 'Capricorn': '♑', 'Aquarius': '♒', 'Pisces': '♓',
    };
    return emojis[sign] ?? '⭐';
  }

  void _handleMenuAction(BuildContext context, String action) {
    switch (action) {
      case 'synastry':
        context.push('/synastry-detail', extra: widget.match);
        break;
      case 'block':
        _showBlockDialog(context);
        break;
    }
  }

  void _showBlockDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2D1B4E),
        title: const Text('Block User', style: TextStyle(color: Colors.white)),
        content: Text(
          'Are you sure you want to block ${widget.match.matchedUser.name}?',
          style: TextStyle(color: Colors.white.withOpacity(0.8)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(blockActionsProvider).block(widget.match.matchedUserId);
              if (context.mounted) context.pop();
            },
            child: const Text('Block', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
