import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:go_router/go_router.dart';
import 'package:syno_app/domain/entities/match.dart';
import 'package:syno_app/domain/entities/natal_chart.dart';
import 'package:syno_app/domain/entities/user.dart';
import 'package:syno_app/data/services/astrology_api_service.dart';
import 'package:syno_app/domain/entities/astrology_system.dart';
import 'package:syno_app/presentation/providers/auth_providers.dart';
import 'package:syno_app/presentation/providers/user_provider.dart';
import 'package:syno_app/presentation/widgets/compatibility_meter.dart';
import 'package:syno_app/presentation/widgets/cosmic_button.dart';
import 'package:syno_app/presentation/widgets/match_badge.dart';
import 'package:syno_app/presentation/widgets/match_score_badge.dart';
import 'package:syno_app/presentation/widgets/zodiac_wheel_widget.dart';
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
  NatalChart? _birthChart;
  NatalChart? _synastryChart1;
  NatalChart? _synastryChart2;
  bool _showElements = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    final Match match = widget.match;
    _dimensions = {
      'Romance': match.synastryData.romanceScore,
      'Communication': match.synastryData.communicationScore,
      'Emotional': match.synastryData.emotionalScore,
      'Long-term': match.synastryData.longTermScore,
      'Chemistry': match.synastryData.chemistryScore,
      'Spiritual': match.synastryData.spiritualScore,
    };
    _loadCharts();
  }

  Future<void> _loadCharts() async {
    final backendUrl = ref.read(backendUrlProvider);
    final apiService = AstrologyApiService(backendUrl);
    final User user = widget.match.matchedUser;
    final currentUser = ref.read(currentUserProvider).value;

    if (user.birthDate != null) {
      final chart = await apiService.getChart(user);
      if (mounted) setState(() => _birthChart = chart);
    }

    if (currentUser?.birthDate != null && user.birthDate != null) {
      final c1 = await apiService.getChart(currentUser!);
      final c2 = await apiService.getChart(user);
      if (mounted) {
        setState(() {
          _synastryChart1 = c1;
          _synastryChart2 = c2;
        });
      }
    }
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
                  MatchScoreBadge(score: match.synastryScore, size: 56),
                  const SizedBox(width: 8),
                  PopupMenuButton<String>(
                    icon: Icon(Icons.more_vert, color: Colors.white.withOpacity(0.8)),
                    onSelected: (v) => _handleMenuAction(context, v),
                    itemBuilder: (_) => [
                      PopupMenuItem(value: 'compatibility', child: Text('Compatibility Report')),
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
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () => context.push('/chat', extra: match),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF6C63FF), Color(0xFF3B82F6)],
                        ),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.chat_bubble_outline, color: Colors.white, size: 18),
                          SizedBox(width: 8),
                          Text('Send Message', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                        ],
                      ),
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

  Widget _buildBadgesRow(Match match) {
    final badges = MatchBadge.getBadgesForScore(match.synastryScore, _dimensions);
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
    final AstrologySystem system = ref.watch(astrologySystemProvider);
    NatalChart? chart = _birthChart;

    final String? zodiac = user.getZodiacSign(system);
    final bool hasChart = chart != null;
    final Map<String, double> elements = chart?.getElementDistribution() ?? {'Fire': 0, 'Earth': 0, 'Air': 0, 'Water': 0};
    final Map<String, double> modalities = chart?.getModalityDistribution() ?? {'Cardinal': 0, 'Fixed': 0, 'Mutable': 0};
    final List<MapEntry<String, String>> planetSigns = chart?.getPlanetSigns() ?? [];
    final String? risingSign = chart?.getAscendantSign();
    final String? moonSign = _getMoonSign(planetSigns);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildChartHeader(zodiac, risingSign, moonSign),
          const SizedBox(height: 20),
          if (!hasChart)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFF97316).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFF97316).withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Color(0xFFF97316), size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Chart data unavailable. Birth date and location are needed for accurate chart calculation.',
                      style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          _buildChartSection(
            'Sun in ${zodiac ?? "Unknown"}',
            Icons.wb_sunny,
            const Color(0xFFFBBF24),
            _getZodiacDescription(zodiac),
          ),
          const SizedBox(height: 16),
          if (risingSign != null)
            _buildChartSection(
              'Rising in $risingSign',
              Icons.terrain,
              const Color(0xFF60A5FA),
              _getRisingDescription(risingSign),
            ),
          if (risingSign != null) const SizedBox(height: 16),
          if (moonSign != null)
            _buildChartSection(
              'Moon in $moonSign',
              Icons.nightlight_round,
              CosmicColors.cosmicPurple,
              _getMoonDescription(moonSign),
            ),
          if (moonSign != null) const SizedBox(height: 16),
          _buildDistributionSection(elements, modalities, planetSigns),
          const SizedBox(height: 20),
          _buildPlanetPlacementSection(planetSigns),
          const SizedBox(height: 20),
          _sectionTitle('Planet Positions'),
          const SizedBox(height: 12),
          ...planetSigns.map((entry) {
            final String planet = entry.key;
            final String sign = entry.value;
            final String symbol = NatalChart.planetSymbols[planet] ?? planet[0];
            final PlanetData? planetData = chart?.planetDataMap[planet];
            return _planetSection(planet, sign, symbol, planetData);
          }),
          if (chart?.houses != null) ...[
            const SizedBox(height: 20),
            _sectionTitle('Houses'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: chart!.houses!.entries.map((entry) {
                final String sign = NatalChart.signFromDegree(entry.value);
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: Column(
                    children: [
                      Text(entry.key, style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 11)),
                      const SizedBox(height: 2),
                      Text(sign, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildChartHeader(String? zodiac, String? rising, String? moon) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [CosmicColors.cosmicPurple, CosmicColors.cosmicPink],
        ),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: const [BoxShadow(color: CosmicColors.cosmicPurple30, blurRadius: 20, offset: Offset(0, 10))],
      ),
      child: Column(
        children: [
          const Text('Birth Chart Overview', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              if (zodiac != null) _chartPill(_getZodiacEmoji(zodiac), zodiac, 'Sun'),
              if (moon != null) _chartPill(_getZodiacEmoji(moon), moon, 'Moon'),
              if (rising != null) _chartPill(_getZodiacEmoji(rising), rising, 'Rising'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chartPill(String emoji, String sign, String label) {
    return Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 32)),
        const SizedBox(height: 4),
        Text(sign, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
        Text(label, style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 11)),
      ],
    );
  }

  Widget _buildChartSection(String title, IconData icon, Color color, String description) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 10),
          Text(description, style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13, height: 1.5)),
        ],
      ),
    );
  }

  Widget _planetSection(String planet, String sign, String symbol, PlanetData? planetData) {
    final String degree = planetData?.displayWithRetrograde ?? '';
    final int? house = planetData?.house;
    final bool retrograde = planetData?.retrograde ?? false;

    const Map<String, Color> elementColors = {
      'Fire': Color(0xFFEF4444),
      'Earth': Color(0xFF10B981),
      'Air': Color(0xFF3B82F6),
      'Water': Color(0xFF8B5CF6),
    };
    final String element = NatalChart.elementForSign(sign);
    final Color elementColor = elementColors[element] ?? Colors.white;

    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: elementColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: elementColor.withOpacity(0.3)),
            ),
            child: Center(child: Text(symbol, style: TextStyle(fontSize: 20, color: elementColor))),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(planet, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: CosmicColors.cosmicPink.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(sign, style: TextStyle(color: CosmicColors.cosmicPink, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                    if (retrograde) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF97316).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text('R', style: TextStyle(color: Color(0xFFF97316), fontSize: 9, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (degree.isNotEmpty) ...[
                      Icon(Icons.speed, size: 12, color: Colors.white.withOpacity(0.4)),
                      const SizedBox(width: 3),
                      Text(degree, style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 11)),
                      const SizedBox(width: 10),
                    ],
                    if (house != null) ...[
                      Icon(Icons.home, size: 12, color: Colors.white.withOpacity(0.4)),
                      const SizedBox(width: 3),
                      Text('House $house', style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 11)),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String? _getMoonSign(List<MapEntry<String, String>> planetSigns) {
    try {
      return planetSigns.firstWhere((e) => e.key == 'Moon').value;
    } catch (_) {
      return null;
    }
  }

  String _getZodiacDescription(String? sign) {
    const Map<String, String> desc = {
      'Aries': 'Bold, ambitious, and fiercely independent. Aries dives headfirst into challenges with unwavering confidence.',
      'Taurus': 'Grounded, loyal, and patient. Taurus values stability and enjoys life\'s sensual pleasures.',
      'Gemini': 'Curious, adaptable, and communicative. Gemini thrives on intellectual stimulation and variety.',
      'Cancer': 'Nurturing, intuitive, and deeply emotional. Cancer builds meaningful connections rooted in care.',
      'Leo': 'Creative, generous, and magnetic. Leo shines brightest when expressing their authentic self.',
      'Virgo': 'Analytical, practical, and thoughtful. Virgo finds beauty in precision and meaningful work.',
      'Libra': 'Harmonious, charming, and fair-minded. Libra seeks balance and meaningful relationships.',
      'Scorpio': 'Passionate, perceptive, and transformative. Scorpio connects on the deepest emotional levels.',
      'Sagittarius': 'Adventurous, optimistic, and philosophical. Sagittarius inspire growth through exploration.',
      'Capricorn': 'Disciplined, ambitious, and reliable. Capricorn builds lasting foundations for success.',
      'Aquarius': 'Innovative, independent, and humanitarian. Aquarius envisions a better future for all.',
      'Pisces': 'Compassionate, artistic, and deeply empathetic. Pisces intuitively understands others\' feelings.',
    };
    return desc[sign] ?? 'A unique cosmic energy shaping personality and destiny.';
  }

  String _getRisingDescription(String? sign) {
    const Map<String, String> desc = {
      'Aries': 'Projects confidence and initiative. Others see you as a natural leader who takes action.',
      'Taurus': 'Appears calm, reliable, and grounded. First impressions convey warmth and dependability.',
      'Gemini': 'Comes across as quick-witted and social. Others perceive you as engaging and communicative.',
      'Cancer': 'Projects sensitivity and nurturing energy. Others see you as caring and protective.',
      'Leo': 'Appears charismatic and confident. First impressions are bold and warmly expressive.',
      'Virgo': 'Projects attentiveness and precision. Others see you as thoughtful and capable.',
      'Libra': 'Appears graceful and diplomatic. First impressions convey charm and fairness.',
      'Scorpio': 'Projects intensity and depth. Others sense a powerful, magnetic presence.',
      'Sagittarius': 'Appears enthusiastic and adventurous. Others see you as optimistic and free-spirited.',
      'Capricorn': 'Projects maturity and ambition. First impressions convey strength and determination.',
      'Aquarius': 'Appears unique and visionary. Others see you as innovative and independent.',
      'Pisces': 'Projects gentleness and intuition. Others sense warmth and spiritual awareness.',
    };
    return desc[sign] ?? 'Your rising sign shapes how others first perceive you.';
  }

  String _getMoonDescription(String? sign) {
    const Map<String, String> desc = {
      'Aries': 'Emotionally driven by passion and independence. Needs excitement and direct expression.',
      'Taurus': 'Seeks emotional security and comfort. Finds peace in routine, nature, and sensuality.',
      'Gemini': 'Processes emotions through communication. Needs variety and intellectual connection.',
      'Cancer': 'Deeply emotional and intuitive. Nurtures others and craves emotional safety.',
      'Leo': 'Needs recognition and creative expression. Emotions are warm, generous, and dramatic.',
      'Virgo': 'Processes feelings analytically. Finds comfort in being useful and organized.',
      'Libra': 'Seeks emotional harmony and partnership. Needs beauty, balance, and social connection.',
      'Scorpio': 'Experiences emotions with intense depth. Values authenticity and transformation.',
      'Sagittarius': 'Needs freedom and adventure to feel emotionally fulfilled. Optimistic outlook.',
      'Capricorn': 'Processes emotions privately. Finds security through achievement and structure.',
      'Aquarius': 'Needs intellectual freedom and humanitarian purpose. Emotions are unconventional.',
      'Pisces': 'Deeply empathetic and spiritually attuned. Feels emotions of others as their own.',
    };
    return desc[sign] ?? 'Your moon sign reveals your inner emotional world and needs.';
  }

  String _getElementDescription(Map<String, double> elements) {
    final String dominant = elements.entries.reduce((a, b) => a.value > b.value ? a : b).key;
    const Map<String, String> desc = {
      'Fire': 'Dominant Fire energy brings passion, creativity, and dynamic action. You lead with enthusiasm and courage.',
      'Earth': 'Dominant Earth energy brings stability, practicality, and groundedness. You build with patience and reliability.',
      'Air': 'Dominant Air energy brings intellect, communication, and social connection. You thrive on ideas and dialogue.',
      'Water': 'Dominant Water energy brings intuition, empathy, and emotional depth. You feel deeply and connect souls.',
    };
    return desc[dominant] ?? 'A balanced mix of elemental energies.';
  }

  String _getModalityDescription(Map<String, double> modalities) {
    final String dominant = modalities.entries.reduce((a, b) => a.value > b.value ? a : b).key;
    const Map<String, String> desc = {
      'Cardinal': 'Cardinal energy drives initiative and leadership. You start new projects and inspire change.',
      'Fixed': 'Fixed energy brings determination and perseverance. You maintain and deepen what matters most.',
      'Mutable': 'Mutable energy brings adaptability and flexibility. You evolve and find harmony in change.',
    };
    return desc[dominant] ?? 'A balanced mix of initiating, stabilizing, and adapting energies.';
  }

  String _getPlanetDescription(String planet, String sign) {
    const Map<String, Map<String, String>> desc = {
      'Sun': {'default': 'Core identity and life purpose. Defines who you are at your essence.'},
      'Moon': {'default': 'Inner emotional world. Governs instincts, habits, and subconscious needs.'},
      'Mercury': {'default': 'Communication style and thinking patterns. Shapes how you process information.'},
      'Venus': {'default': 'Love language and values. Defines what you find beautiful and how you relate.'},
      'Mars': {'default': 'Drive and ambition. Governs how you pursue goals and express desire.'},
      'Jupiter': {'default': 'Growth and expansion. Where you find luck, wisdom, and abundance.'},
      'Saturn': {'default': 'Discipline and life lessons. Where you build structure and maturity.'},
      'Ascendant': {'default': 'Outward persona and first impression. The mask you show the world.'},
    };
    final String planetDesc = desc[planet]?['default'] ?? 'Planetary influence on your chart.';
    return '$planet in $sign — $planetDesc';
  }

  Widget _buildSynastryTab(BuildContext context, Match match) {
    final currentUser = ref.watch(currentUserProvider).value;
    final AstrologySystem system = ref.watch(astrologySystemProvider);
    NatalChart? chart1 = _synastryChart1;
    NatalChart? chart2 = _synastryChart2;

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
                MatchScoreBadge(score: match.synastryScore, size: 80),
                const SizedBox(height: 8),
                Text(
                  '${match.synastryScore.toInt()}% Match',
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
          if (chart1 != null && chart2 != null) ...[
            Center(
              child: ZodiacWheelWidget(
                chart: chart1,
                chart2: chart2,
                showBothCharts: true,
                size: 260,
                system: system,
              ),
            ),
            const SizedBox(height: 20),
          ],
          _sectionTitle('Compatibility Breakdown'),
          const SizedBox(height: 12),
          CompatibilityMeter(label: 'Romance', emoji: '❤️', score: match.synastryData.romanceScore),
          CompatibilityMeter(label: 'Communication', emoji: '🧠', score: match.synastryData.communicationScore),
          CompatibilityMeter(label: 'Emotional', emoji: '🌙', score: match.synastryData.emotionalScore),
          CompatibilityMeter(label: 'Long-term', emoji: '💍', score: match.synastryData.longTermScore),
          CompatibilityMeter(label: 'Chemistry', emoji: '⚡', score: match.synastryData.chemistryScore),
          CompatibilityMeter(label: 'Spiritual', emoji: '✨', score: match.synastryData.spiritualScore),
          const SizedBox(height: 24),
          if (match.synastryData.detailedAspects.isNotEmpty) ...[
            _sectionTitle('Key Aspects'),
            const SizedBox(height: 12),
            ...match.synastryData.detailedAspects.take(8).map((aspect) {
              final Color aspectColor = aspect.isHarmonious
                  ? const Color(0xFF10B981)
                  : const Color(0xFFEF4444);
              final String aspectSymbol = aspect.aspectType == 'Conjunction' ? '☌'
                  : aspect.aspectType == 'Trine' ? '△'
                  : aspect.aspectType == 'Sextile' ? '✦'
                  : aspect.aspectType == 'Square' ? '□'
                  : '☍';
              return Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: aspectColor.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: aspectColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          aspectSymbol,
                          style: TextStyle(color: aspectColor, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${aspect.planet1} ${aspect.aspectType} ${aspect.planet2}',
                            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            aspect.description,
                            style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 11),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    if (aspect.planet1Sign != null && aspect.planet2Sign != null) ...[
                      Column(
                        children: [
                          Text(
                            _getZodiacEmoji(aspect.planet1Sign!),
                            style: const TextStyle(fontSize: 16),
                          ),
                          Text(
                            _getZodiacEmoji(aspect.planet2Sign!),
                            style: const TextStyle(fontSize: 16),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              );
            }),
          ],
          if (match.synastryData.interpretation.isNotEmpty) ...[
            const SizedBox(height: 24),
            _sectionTitle('Overall Reading'),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF60A5FA).withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF60A5FA).withOpacity(0.2)),
              ),
              child: Text(
                match.synastryData.interpretation,
                style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 13, height: 1.5),
              ),
            ),
          ],
          if (match.synastryData.strengths.isNotEmpty) ...[
            const SizedBox(height: 24),
            _sectionTitle('Strengths'),
            const SizedBox(height: 12),
            ...match.synastryData.strengths.map((s) => Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF10B981).withOpacity(0.2)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('✨ ', style: TextStyle(fontSize: 14)),
                  Expanded(
                    child: Text(s, style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 13)),
                  ),
                ],
              ),
            )),
          ],
          if (match.synastryData.challenges.isNotEmpty) ...[
            const SizedBox(height: 24),
            _sectionTitle('Challenges'),
            const SizedBox(height: 12),
            ...match.synastryData.challenges.map((c) => Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.2)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('⚡ ', style: TextStyle(fontSize: 14)),
                  Expanded(
                    child: Text(c, style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 13)),
                  ),
                ],
              ),
            )),
          ],
          if (match.synastryData.communicationText.isNotEmpty) ...[
            const SizedBox(height: 24),
            _sectionTitle('Communication Style'),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: Text(
                match.synastryData.communicationText,
                style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 13, height: 1.5),
              ),
            ),
          ],
          if (match.synastryData.emotionalDynamicText.isNotEmpty) ...[
            const SizedBox(height: 24),
            _sectionTitle('Emotional Dynamic'),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: Text(
                match.synastryData.emotionalDynamicText,
                style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 13, height: 1.5),
              ),
            ),
          ],
          if (match.synastryData.growthDynamicText.isNotEmpty) ...[
            const SizedBox(height: 24),
            _sectionTitle('Growth Potential'),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: Text(
                match.synastryData.growthDynamicText,
                style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 13, height: 1.5),
              ),
            ),
          ],
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



  String _getZodiacEmoji(String sign) {
    const emojis = {
      'Aries': '♈', 'Taurus': '♉', 'Gemini': '♊', 'Cancer': '♋',
      'Leo': '♌', 'Virgo': '♍', 'Libra': '♎', 'Scorpio': '♏',
      'Sagittarius': '♐', 'Capricorn': '♑', 'Aquarius': '♒', 'Pisces': '♓',
    };
    return emojis[sign] ?? '⭐';
  }

  Widget _buildDistributionSection(
    Map<String, double> elements,
    Map<String, double> modalities,
    List<MapEntry<String, String>> planetSigns,
  ) {
    final Map<String, double> data = _showElements ? elements : modalities;
    final String description = _showElements
        ? _getElementDescription(elements)
        : _getModalityDescription(modalities);

    const Map<String, Color> elementColors = {
      'Fire': Color(0xFFEF4444),
      'Earth': Color(0xFF10B981),
      'Air': Color(0xFF3B82F6),
      'Water': Color(0xFF8B5CF6),
    };
    const Map<String, Color> modalityColors = {
      'Cardinal': Color(0xFFF97316),
      'Fixed': Color(0xFF8B5CF6),
      'Mutable': Color(0xFF06B6D4),
    };
    final Map<String, Color> colors = _showElements ? elementColors : modalityColors;

    const Map<String, String> elementIcons = {
      'Fire': '🔥', 'Earth': '🌍', 'Air': '💨', 'Water': '💧',
    };
    const Map<String, String> modalityIcons = {
      'Cardinal': '🚀', 'Fixed': '🔒', 'Mutable': '🔄',
    };
    final Map<String, String> icons = _showElements ? elementIcons : modalityIcons;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _showElements ? Icons.local_fire_department : Icons.autorenew,
                color: _showElements ? const Color(0xFFEF4444) : const Color(0xFFF97316),
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                _showElements ? 'Element Balance' : 'Modality Profile',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.all(3),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _showElements = true),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: _showElements
                            ? const Color(0xFFEF4444).withOpacity(0.2)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: _showElements
                            ? Border.all(color: const Color(0xFFEF4444).withOpacity(0.4))
                            : null,
                      ),
                      child: Center(
                        child: Text(
                          '🔥 Elements',
                          style: TextStyle(
                            color: _showElements ? Colors.white : Colors.white.withOpacity(0.5),
                            fontSize: 13,
                            fontWeight: _showElements ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _showElements = false),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: !_showElements
                            ? const Color(0xFFF97316).withOpacity(0.2)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: !_showElements
                            ? Border.all(color: const Color(0xFFF97316).withOpacity(0.4))
                            : null,
                      ),
                      child: Center(
                        child: Text(
                          '🔄 Modalities',
                          style: TextStyle(
                            color: !_showElements ? Colors.white : Colors.white.withOpacity(0.5),
                            fontSize: 13,
                            fontWeight: !_showElements ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            description,
            style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12),
          ),
          const SizedBox(height: 12),
          ...data.entries.map((entry) {
            final String category = entry.key;
            final double value = entry.value;
            final Color color = colors[category] ?? Colors.white;
            final String icon = icons[category] ?? '';
            final List<String> planetsInCategory = _getPlanetsInCategory(category, planetSigns, _showElements);

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: color.withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(icon, style: const TextStyle(fontSize: 18)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  category,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  '${(value * 100).round()}%',
                                  style: TextStyle(
                                    color: color,
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: value,
                                backgroundColor: Colors.white.withOpacity(0.08),
                                valueColor: AlwaysStoppedAnimation<Color>(color),
                                minHeight: 6,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (planetsInCategory.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: planetsInCategory.map((planet) {
                        final String sign = _getSignForPlanet(planet, planetSigns);
                        final String symbol = NatalChart.planetSymbols[planet] ?? planet[0];
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: color.withOpacity(0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(symbol, style: TextStyle(color: color, fontSize: 12)),
                              const SizedBox(width: 4),
                              Text(
                                planet,
                                style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w500),
                              ),
                              if (sign.isNotEmpty) ...[
                                const SizedBox(width: 4),
                                Text(_getZodiacEmoji(sign), style: const TextStyle(fontSize: 11)),
                              ],
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ] else ...[
                    const SizedBox(height: 8),
                    Text(
                      'No planets in this category',
                      style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 11, fontStyle: FontStyle.italic),
                    ),
                  ],
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  List<String> _getPlanetsInCategory(
    String category,
    List<MapEntry<String, String>> planetSigns,
    bool isElement,
  ) {
    return planetSigns.where((entry) {
      final String sign = entry.value;
      if (isElement) {
        return NatalChart.elementForSign(sign) == category;
      } else {
        return NatalChart.modalityForSign(sign) == category;
      }
    }).map((entry) => entry.key).toList();
  }

  String _getSignForPlanet(String planet, List<MapEntry<String, String>> planetSigns) {
    for (final entry in planetSigns) {
      if (entry.key == planet) return entry.value;
    }
    return '';
  }

  Widget _buildPlanetPlacementSection(List<MapEntry<String, String>> planetSigns) {
    if (planetSigns.isEmpty) return const SizedBox.shrink();

    const Map<String, Color> elementColors = {
      'Fire': Color(0xFFEF4444),
      'Earth': Color(0xFF10B981),
      'Air': Color(0xFF3B82F6),
      'Water': Color(0xFF8B5CF6),
    };
    const Map<String, Color> modalityColors = {
      'Cardinal': Color(0xFFF97316),
      'Fixed': Color(0xFF8B5CF6),
      'Mutable': Color(0xFF06B6D4),
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.grid_on, color: Color(0xFF60A5FA), size: 20),
              const SizedBox(width: 8),
              const Text(
                'Planet Placement',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Where each planet falls in element and modality',
            style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.03),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withOpacity(0.06)),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.06),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                  ),
                  child: const Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Text('Planet', style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.w600)),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text('Sign', style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.w600)),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text('Element', style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.w600)),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text('Modality', style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                ),
                ...planetSigns.asMap().entries.map((mapEntry) {
                  final int index = mapEntry.key;
                  final MapEntry<String, String> entry = mapEntry.value;
                  final String planet = entry.key;
                  final String sign = entry.value;
                  final String symbol = NatalChart.planetSymbols[planet] ?? planet[0];
                  final String element = NatalChart.elementForSign(sign);
                  final String modality = NatalChart.modalityForSign(sign);
                  final Color elementColor = elementColors[element] ?? Colors.white;
                  final Color modalityColor = modalityColors[modality] ?? Colors.white;
                  final bool isLast = index == planetSigns.length - 1;

                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      border: isLast ? null : Border(bottom: BorderSide(color: Colors.white.withOpacity(0.05))),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: Row(
                            children: [
                              Text(symbol, style: const TextStyle(fontSize: 14)),
                              const SizedBox(width: 6),
                              Text(
                                planet,
                                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            '${_getZodiacEmoji(sign)} $sign',
                            style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 11),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: elementColor.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              element,
                              style: TextStyle(color: elementColor, fontSize: 11, fontWeight: FontWeight.w600),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: modalityColor.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              modality,
                              style: TextStyle(color: modalityColor, fontSize: 11, fontWeight: FontWeight.w600),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _handleMenuAction(BuildContext context, String action) {
    switch (action) {
      case 'compatibility':
        context.push('/compatibility-report', extra: {
          'matchId': widget.match.backendMatchId ?? 0,
          'matchedUserName': widget.match.matchedUser.name ?? 'User',
        });
        break;
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
