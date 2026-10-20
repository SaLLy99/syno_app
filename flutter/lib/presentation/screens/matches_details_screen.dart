import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:go_router/go_router.dart';
import 'package:syno_app/domain/entities/match.dart';
import 'package:syno_app/domain/entities/natal_chart.dart';
import 'package:syno_app/domain/entities/synastry_data.dart';
import 'package:syno_app/domain/entities/user.dart';
import 'package:syno_app/data/services/astrology_api_service.dart';
import 'package:syno_app/domain/entities/astrology_system.dart';
import 'package:syno_app/presentation/providers/auth_providers.dart';
import 'package:syno_app/presentation/providers/user_provider.dart';
import 'package:syno_app/presentation/widgets/match_badge.dart';
import 'package:syno_app/presentation/widgets/score_breakdown.dart';
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
  Map<String, double> _dimensions = <String, double>{};
  NatalChart? _birthChart;
  NatalChart? _synastryChart1;
  NatalChart? _synastryChart2;
  SynastryData? _loadedSynastry;
  bool _loadingSynastry = true;
  bool _showElements = true;

  SynastryData get _effectiveSynastry => _loadedSynastry ?? widget.match.synastryDataOrEmpty;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    final SynastryData initial = widget.match.synastryDataOrEmpty;
    _dimensions = _buildDimensions(initial);
    _loadCharts();
  }

  Future<void> _loadCharts() async {
    final backendUrl = ref.read(backendUrlProvider);
    final apiService = AstrologyApiService(backendUrl);
    final User user = widget.match.matchedUser;
    final currentUser = ref.read(currentUserProvider).value;

    debugPrint('[MatchDetails] _loadCharts: matchedUser=${user.name}, birthDate=${user.birthDate}, birthTime=${user.birthTime}, lat=${user.location?.latitude}, lon=${user.location?.longitude}');
    debugPrint('[MatchDetails] _loadCharts: currentUser=${currentUser?.name}, birthDate=${currentUser?.birthDate}, birthTime=${currentUser?.birthTime}, lat=${currentUser?.location?.latitude}, lon=${currentUser?.location?.longitude}');
    debugPrint('[MatchDetails] _loadCharts: match.synastryData=${widget.match.synastryData}, synastryScore=${widget.match.synastryScore}');

    if (user.birthDate != null) {
      final chart = await apiService.getChart(user);
      debugPrint('[MatchDetails] _loadCharts: matchedUser chart=${chart != null ? 'loaded' : 'null'}');
      if (mounted) setState(() => _birthChart = chart);
    } else {
      debugPrint('[MatchDetails] _loadCharts: matchedUser has NO birthDate, skipping chart');
    }

    if (currentUser?.birthDate != null && user.birthDate != null) {
      final c1 = await apiService.getChart(currentUser!);
      final c2 = await apiService.getChart(user);
      debugPrint('[MatchDetails] _loadCharts: synastry charts - c1=${c1 != null ? 'loaded' : 'null'}, c2=${c2 != null ? 'loaded' : 'null'}');
      if (mounted) {
        setState(() {
          _synastryChart1 = c1;
          _synastryChart2 = c2;
        });
      }

      debugPrint('[MatchDetails] _loadCharts: fetching synastry from API...');
      final synastry = await apiService.getSynastry(currentUser, user);
        debugPrint('[MatchDetails] _loadCharts: synastry from API=${synastry != null ? 'loaded' : 'null'}');
        if (synastry != null) {
          debugPrint('[MatchDetails] SYNASTRY API RESULT: overall=${synastry.overallScore}, moon=${synastry.moonScore}, mercury=${synastry.mercuryScore}, venusMars=${synastry.venusMarsScore}, nodes=${synastry.nodesScore}, saturn=${synastry.saturnScore}');
          debugPrint('[MatchDetails] SYNASTRY API DIMENSIONS: romance=${synastry.romanceScore}, communication=${synastry.communicationScore}, emotional=${synastry.emotionalScore}, longTerm=${synastry.longTermScore}, chemistry=${synastry.chemistryScore}, spiritual=${synastry.spiritualScore}');
          debugPrint('[MatchDetails] SYNASTRY API ASPECTS (${synastry.detailedAspects.length}): ${synastry.detailedAspects.take(3).map((a) => '${a.planet1}${a.aspectType}${a.planet2}(orb=${a.orb?.toStringAsFixed(1)},harmonious=${a.isHarmonious})').join('; ')}');
          debugPrint('[MatchDetails] SYNASTRY API AI: used=${synastry.aiUsed}, interpLen=${synastry.interpretation.length}, strengths=${synastry.strengths.length}, challenges=${synastry.challenges.length}');
        }
      if (mounted) {
        setState(() {
          _loadingSynastry = false;
          final syn = synastry ?? _effectiveSynastry;
          _loadedSynastry = synastry ?? _loadedSynastry;
          _dimensions = _buildDimensions(syn);
        });
      }
    } else {
      debugPrint('[MatchDetails] _loadCharts: missing birth data - currentUser=${currentUser?.birthDate != null ? 'has' : 'NO'} birthDate, matchedUser=${user.birthDate != null ? 'has' : 'NO'} birthDate');
      if (mounted) setState(() => _loadingSynastry = false);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Map<String, double> _buildDimensions(SynastryData syn) => <String, double>{
        'romance': syn.romanceScore,
        'communication': syn.communicationScore,
        'emotional': syn.emotionalScore,
        'long_term': syn.longTermScore,
        'chemistry': syn.chemistryScore,
        'spiritual': syn.spiritualScore,
      };

  String _dimLabel(String key) {
    switch (key) {
      case 'romance':
        return 'match_details.match_info.romance'.tr();
      case 'communication':
        return 'match_details.highlights.communication'.tr();
      case 'emotional':
        return 'match_details.highlights.emotional'.tr();
      case 'long_term':
        return 'match_details.highlights.long_term'.tr();
      case 'chemistry':
        return 'match_details.match_info.chemistry'.tr();
      case 'spiritual':
        return 'match_details.match_info.spiritual'.tr();
      default:
        return key;
    }
  }

  String _scoreLevel(double score) {
    if (score >= 85) return 'match_details.match_info.level_exceptional'.tr();
    if (score >= 70) return 'match_details.match_info.level_strong'.tr();
    if (score >= 55) return 'match_details.match_info.level_good'.tr();
    return 'match_details.match_info.level_growing'.tr();
  }

  String _firstSentence(String text, {int maxLength = 130}) {
    if (text.isEmpty) return '';
    final int idx = text.indexOf('. ');
    String excerpt = idx > 0 ? text.substring(0, idx + 1) : text;
    if (excerpt.length > maxLength) {
      excerpt = '${excerpt.substring(0, maxLength).trimRight()}…';
    }
    return excerpt;
  }

  bool get _hasApiSynastry => _loadedSynastry != null || widget.match.synastryData != null;

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
              child: PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, color: Colors.white.withOpacity(0.8)),
                onSelected: (v) => _handleMenuAction(context, v),
                itemBuilder: (_) => [
                   PopupMenuItem(value: 'compatibility', child: Text('match_details.compatibility_report'.tr())),
                   PopupMenuItem(value: 'synastry', child: Text('match_details.full_match_report'.tr())),
                   PopupMenuItem(value: 'block', child: Text('match_details.block_user'.tr())),
                ],
                color: const Color(0xFF2D1B4E),
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
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.chat_bubble_outline, color: Colors.white, size: 18),
                          SizedBox(width: 8),
                           Text('match_details.send_message'.tr(), style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
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
    if (_loadingSynastry) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white.withOpacity(0.5)),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'match_details.match_info.finding_scores'.tr(),
              style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
            ),
          ],
        ),
      );
    }

    if (!_hasApiSynastry) return const SizedBox.shrink();

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
                _dimLabel(e.key),
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
        tabs: [
          Tab(text: 'match_details.tab_about'.tr()),
          Tab(text: 'match_details.tab_photos'.tr()),
          Tab(text: 'match_details.tab_lifestyle'.tr()),
          Tab(text: 'match_details.tab_chart'.tr()),
          Tab(text: 'match_details.tab_match_info'.tr()),
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
            _sectionTitle('match_details.about_me'.tr()),
            const SizedBox(height: 8),
            Text(
              user.bio!,
              style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 15, height: 1.5),
            ),
            const SizedBox(height: 20),
          ],
          if (user.hobbies.isNotEmpty) ...[
            _sectionTitle('match_details.interests'.tr()),
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
            _sectionTitle('match_details.core_values'.tr()),
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
            _sectionTitle('match_details.looking_for'.tr()),
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
          _lifestyleRow(Icons.cake, 'match_details.age'.tr(), '${user.age}'),
          _lifestyleRow(Icons.straighten, 'match_details.height'.tr(), user.height != null ? '${user.height!.toInt()} cm' : 'Not specified'),
          if (user.sex != null) _lifestyleRow(Icons.person, 'match_details.gender'.tr(), user.sex!.name),
          if (user.orientation != null) _lifestyleRow(Icons.favorite, 'match_details.orientation'.tr(), user.orientation!.name),
          if (user.professions.isNotEmpty)
            _lifestyleRow(Icons.work, 'match_details.occupation'.tr(), user.professions.first.name),
          if (user.educations.isNotEmpty)
            _lifestyleRow(Icons.school, 'match_details.education'.tr(), user.educations.first.name),
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
          _sectionTitle('match_details.planet_positions'.tr()),
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
            _sectionTitle('match_details.houses'.tr()),
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

  Widget _buildSynastryTab(BuildContext context, Match match) {
    final currentUser = ref.watch(currentUserProvider).value;
    final AstrologySystem system = ref.watch(astrologySystemProvider);
    NatalChart? chart1 = _synastryChart1;
    NatalChart? chart2 = _synastryChart2;
    final SynastryData synData = _effectiveSynastry;

    final bool hasBirthData = currentUser?.birthDate != null && match.matchedUser.birthDate != null;
    final bool canCalculate = hasBirthData;
    final bool hasSynastryData = synData.detailedAspects.isNotEmpty || synData.interpretation.isNotEmpty;

    debugPrint('[MatchDetails][MatchInfo] tab loaded: score=${match.synastryScore}, hasBirthData=$hasBirthData, hasSynastryData=$hasSynastryData, aiUsed=${synData.aiUsed}, aspects=${synData.detailedAspects.length}');
    debugPrint('[MatchDetails][MatchInfo] SYNASTRY DATA: overall=${synData.overallScore}, romance=${synData.romanceScore}, communication=${synData.communicationScore}, emotional=${synData.emotionalScore}, longTerm=${synData.longTermScore}, chemistry=${synData.chemistryScore}, spiritual=${synData.spiritualScore}');
    debugPrint('[MatchDetails][MatchInfo] SYNASTRY SCORES: moon=${synData.moonScore}, mercury=${synData.mercuryScore}, venusMars=${synData.venusMarsScore}, nodes=${synData.nodesScore}, saturn=${synData.saturnScore}');
    debugPrint('[MatchDetails][MatchInfo] SYNASTRY TEXT: interpretation=${synData.interpretation.length} chars, communication=${synData.communicationText.length} chars, emotional=${synData.emotionalDynamicText.length} chars');
    debugPrint('[MatchDetails][MatchInfo] SYNASTRY STRENGTHS: ${synData.strengths}');
    debugPrint('[MatchDetails][MatchInfo] SYNASTRY CHALLENGES: ${synData.challenges}');
    debugPrint('[MatchDetails][MatchInfo] SYNASTRY ASPECTS (${synData.detailedAspects.length}): ${synData.detailedAspects.take(5).map((a) => '${a.planet1}${a.aspectSymbol}${a.planet2}=${a.score.toStringAsFixed(0)}%').join(', ')}');

    if (!canCalculate) {
      return _buildSynastryMissingDataState(context, match, currentUser);
    }

    if (_loadingSynastry || (!hasSynastryData && _loadedSynastry == null)) {
      return _buildSynastryLoadingState(context);
    }

    if (!hasSynastryData) {
      return _buildSynastryMissingDataState(context, match, currentUser);
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildMatchInfoHeader(context, match, synData),
          const SizedBox(height: 20),
          if (chart1 != null && chart2 != null) ...[
            _buildMatchZodiacComparison(context, chart1, chart2, system, match),
            const SizedBox(height: 20),
          ],
          _buildMatchBreakdown(context, synData, match),
          const SizedBox(height: 20),
          if (synData.topAspects.isNotEmpty) ...[
            TopAspectsCard(aspects: synData.topAspects),
            const SizedBox(height: 20),
          ],
          _buildMatchHighlights(context, synData),
          const SizedBox(height: 20),
          if (synData.interpretation.isNotEmpty) ...[
            _buildMatchInterpretation(context, synData),
            const SizedBox(height: 20),
          ],
          _buildInsightCard(context, match, synData),
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
              label: Text('match_details.match_info.see_full_synastry'.tr()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMatchInfoHeader(BuildContext context, Match match, SynastryData synData) {
    // Prefer the canonical match score so this header, the discover badge,
    // the match list and the report screen can never disagree.
    final double matchScore = match.finalScore;
    final double score = matchScore > 0
        ? matchScore
        : synData.primaryScore(fallback: match.finalScore);
    final Color scoreColor = score >= 85
        ? const Color(0xFF10B981)
        : score >= 70
            ? const Color(0xFF3B82F6)
            : score >= 55
                ? CosmicColors.sunsetOrange
                : const Color(0xFFEF4444);

    final String matchLabel = score >= 85
        ? 'match_details.match_info.exceptional_match'.tr()
        : score >= 70
            ? 'match_details.match_info.strong_connection'.tr()
            : score >= 55
                ? 'match_details.match_info.good_potential'.tr()
                : 'match_details.match_info.growing_together'.tr();

    debugPrint('[MatchDetails][MatchInfo] header: score=$score, label=$matchLabel');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            scoreColor.withOpacity(0.2),
            const Color(0xFF1A0B2E),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scoreColor.withOpacity(0.4), width: 1.5),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildMatchUserAvatar(ref.watch(currentUserProvider).value, isLeft: true),
              const SizedBox(width: 16),
              Column(
                children: [
                  Icon(Icons.favorite, color: scoreColor, size: 28),
                  const SizedBox(height: 4),
                  Text(
                    matchLabel,
                    style: TextStyle(color: scoreColor, fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(width: 16),
              _buildMatchUserAvatar(match.matchedUser, isLeft: false),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '${score.toInt()}%',
            style: TextStyle(
              color: scoreColor,
              fontSize: 48,
              fontWeight: FontWeight.bold,
              height: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'match_details.match_info.overall_compatibility'.tr(),
            style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13, letterSpacing: 1.2),
          ),
          if (match.scoreParts.isNotEmpty) ...[
            const SizedBox(height: 16),
            ScorePartsRow(parts: match.scoreParts),
          ],
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildQuickStat('match_details.match_info.romance'.tr(), '${synData.romanceScore.toInt()}%', CosmicColors.cosmicPink),
              Container(width: 1, height: 30, color: Colors.white.withOpacity(0.1)),
              _buildQuickStat('match_details.highlights.emotional'.tr(), '${synData.emotionalScore.toInt()}%', CosmicColors.cosmicPurple),
              Container(width: 1, height: 30, color: Colors.white.withOpacity(0.1)),
              _buildQuickStat('match_details.highlights.long_term'.tr(), '${synData.longTermScore.toInt()}%', const Color(0xFF10B981)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSecondaryScoreChip(String label, double score) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(0.15)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${score.toInt()}%',
            style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
          ),
          Text(
            label,
            style: TextStyle(color: Colors.white.withOpacity(0.65), fontSize: 10),
          ),
        ],
      ),
    );
  }

  Widget _buildMatchUserAvatar(User? user, {required bool isLeft}) {
    return Column(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withOpacity(0.2), width: 2),
          ),
          child: ClipOval(
            child: user?.photos.isNotEmpty == true
                ? Image.network(
                    user!.photos.first.getFullUrl(ref.read(backendUrlProvider)),
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: CosmicColors.cosmicPurple.withOpacity(0.3),
                      child: Icon(Icons.person, color: Colors.white.withOpacity(0.5), size: 28),
                    ),
                  )
                : Container(
                    color: CosmicColors.cosmicPurple.withOpacity(0.3),
                    child: Icon(Icons.person, color: Colors.white.withOpacity(0.5), size: 28),
                  ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          isLeft ? 'match_details.match_info.you'.tr() : (user?.name ?? 'match_details.match_info.them'.tr()),
          style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 11, fontWeight: FontWeight.w500),
        ),
        if (user?.birthDate != null) ...[
          const SizedBox(height: 2),
          Text(
            user!.getZodiacSign(ref.read(astrologySystemProvider)) ?? '',
            style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 10),
          ),
        ],
      ],
    );
  }

  Widget _buildQuickStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11),
        ),
      ],
    );
  }

  Widget _buildMatchZodiacComparison(BuildContext context, NatalChart chart1, NatalChart chart2, AstrologySystem system, Match match) {
    final String? sun1 = chart1.getSunSign();
    final String? moon1 = chart1.getMoonSign();
    final String? rising1 = chart1.getAscendantSign();
    final String? sun2 = chart2.getSunSign();
    final String? moon2 = chart2.getMoonSign();
    final String? rising2 = chart2.getAscendantSign();

    debugPrint('[MatchDetails][MatchInfo] zodiac comparison: user1 sun=$sun1 moon=$moon1 rising=$rising1, user2 sun=$sun2 moon=$moon2 rising=$rising2');

    final String matchedName = match.matchedUser.name ?? 'match_details.match_info.them'.tr();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.wb_sunny, color: Color(0xFFFBBF24), size: 18),
              const SizedBox(width: 8),
              Text(
                'match_details.match_info.zodiac_overview'.tr(),
                style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'match_details.match_info.you'.tr(),
                    textAlign: TextAlign.end,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: SizedBox(width: 52),
                ),
                Expanded(
                  child: Text(
                    matchedName,
                    textAlign: TextAlign.start,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          _buildZodiacComparisonRow('Sun', _getZodiacEmoji(sun1 ?? ''), sun1 ?? '?', _getZodiacEmoji(sun2 ?? ''), sun2 ?? '?'),
          const SizedBox(height: 10),
          _buildZodiacComparisonRow('Moon', _getZodiacEmoji(moon1 ?? ''), moon1 ?? '?', _getZodiacEmoji(moon2 ?? ''), moon2 ?? '?'),
          const SizedBox(height: 10),
          _buildZodiacComparisonRow('Rising', _getZodiacEmoji(rising1 ?? ''), rising1 ?? '?', _getZodiacEmoji(rising2 ?? ''), rising2 ?? '?'),
        ],
      ),
    );
  }

  Widget _buildZodiacComparisonRow(String label, String emoji1, String sign1, String emoji2, String sign2) {
    return Row(
      children: [
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(sign1, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
              const SizedBox(width: 6),
              Text(emoji1, style: const TextStyle(fontSize: 18)),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: SizedBox(
            width: 52,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(label, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 10, fontWeight: FontWeight.w600)),
              ),
            ),
          ),
        ),
        Expanded(
          child: Row(
            children: [
              Text(emoji2, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 6),
              Text(sign2, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMatchBreakdown(BuildContext context, SynastryData synData, Match match) {
    debugPrint('[MatchDetails][MatchInfo] breakdown: romance=${synData.romanceScore}, communication=${synData.communicationScore}, emotional=${synData.emotionalScore}, longTerm=${synData.longTermScore}, chemistry=${synData.chemistryScore}, spiritual=${synData.spiritualScore}');

    final List<MapEntry<String, Map<String, dynamic>>> categories = [
      MapEntry('match_details.match_info.romance'.tr(), {
        'score': synData.romanceScore,
        'emoji': '❤️',
        'color': CosmicColors.cosmicPink,
        'apiText': synData.loveLanguage.isNotEmpty ? synData.loveLanguage : synData.interpretation,
      }),
      MapEntry('match_details.highlights.communication'.tr(), {
        'score': synData.communicationScore,
        'emoji': '🧠',
        'color': CosmicColors.cosmicBlue,
        'apiText': synData.communicationText,
      }),
      MapEntry('match_details.highlights.emotional'.tr(), {
        'score': synData.emotionalScore,
        'emoji': '🌙',
        'color': CosmicColors.cosmicPurple,
        'apiText': synData.emotionalDynamicText,
      }),
      MapEntry('match_details.highlights.soul_bond'.tr(), {
        'score': synData.chemistryScore,
        'emoji': '⚡',
        'color': CosmicColors.sunsetOrange,
        'apiText': synData.intimacyText.isNotEmpty ? synData.intimacyText : synData.loveLanguage,
      }),
      MapEntry('match_details.highlights.long_term'.tr(), {
        'score': synData.longTermScore,
        'emoji': '💍',
        'color': const Color(0xFF10B981),
        'apiText': synData.trustLoyalty.isNotEmpty ? synData.trustLoyalty : synData.valuesText,
      }),
      MapEntry('match_details.match_info.spiritual'.tr(), {
        'score': synData.spiritualScore,
        'emoji': '✨',
        'color': const Color(0xFF8B5CF6),
        'apiText': synData.growthDynamicText,
      }),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.pie_chart_outline, color: Color(0xFF3B82F6), size: 18),
              const SizedBox(width: 8),
              Text(
                'match_details.match_info.compatibility_breakdown'.tr(),
                style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...categories.map((entry) {
            final double score = entry.value['score'] as double;
            final Color color = entry.value['color'] as Color;
            final String emoji = entry.value['emoji'] as String;
            final String apiText = _firstSentence(entry.value['apiText'] as String);
            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(emoji, style: const TextStyle(fontSize: 14)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          entry.key,
                          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          _scoreLevel(score),
                          style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${score.toInt()}%',
                        style: TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  if (apiText.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      apiText,
                      style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 11, height: 1.4),
                    ),
                  ],
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: score / 100,
                      backgroundColor: Colors.white.withOpacity(0.08),
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                      minHeight: 6,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildMatchHighlights(BuildContext context, SynastryData synData) {
    final List<String> strengths = synData.strengths;
    final List<String> challenges = synData.challenges;

    debugPrint('[MatchDetails][MatchInfo] highlights: strengths=${strengths.length}, challenges=${challenges.length}');

    if (strengths.isEmpty && challenges.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, color: CosmicColors.cosmicPink, size: 18),
              const SizedBox(width: 8),
              Text(
                'match_details.match_info.connection_highlights'.tr(),
                style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (strengths.isNotEmpty) ...[
            Text(
              'match_details.match_info.what_make_you_click'.tr(),
              style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.5),
            ),
            const SizedBox(height: 8),
            ...strengths.take(4).map((s) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 2),
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: Color(0xFF10B981),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      s,
                      style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 13, height: 1.4),
                    ),
                  ),
                ],
              ),
            )),
          ],
          if (challenges.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'match_details.match_info.areas_to_nurture'.tr(),
              style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.5),
            ),
            const SizedBox(height: 8),
            ...challenges.take(3).map((c) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 2),
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: CosmicColors.sunsetOrange,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      c,
                      style: TextStyle(color: Colors.white.withOpacity(0.75), fontSize: 13, height: 1.4),
                    ),
                  ),
                ],
              ),
            )),
          ],
        ],
      ),
    );
  }

  Widget _buildMatchInterpretation(BuildContext context, SynastryData synData) {
    debugPrint('[MatchDetails][MatchInfo] interpretation: len=${synData.interpretation.length}, hasCommunication=${synData.communicationText.isNotEmpty}, hasEmotional=${synData.emotionalDynamicText.isNotEmpty}');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            CosmicColors.cosmicPurple.withOpacity(0.1),
            CosmicColors.cosmicPink.withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: CosmicColors.cosmicPurple.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: CosmicColors.cosmicPurple.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.auto_stories, color: CosmicColors.cosmicPurple, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'match_details.match_info.your_match_reading'.tr(),
                  style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _ExpandableBody(
            text: synData.interpretation,
            style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 13, height: 1.6),
          ),
          if (synData.communicationText.isNotEmpty) ...[
            const SizedBox(height: 14),
            _buildMiniReading('match_details.match_info.how_you_communicate'.tr(), Icons.chat_bubble_outline, CosmicColors.cosmicBlue, synData.communicationText),
          ],
          if (synData.emotionalDynamicText.isNotEmpty) ...[
            const SizedBox(height: 10),
            _buildMiniReading('match_details.match_info.emotional_bond'.tr(), Icons.favorite_outline, CosmicColors.cosmicPink, synData.emotionalDynamicText),
          ],
          if (synData.loveLanguage.isNotEmpty) ...[
            const SizedBox(height: 10),
            _buildMiniReading('match_details.match_info.love_language'.tr(), Icons.redeem, const Color(0xFFF472B6), synData.loveLanguage),
          ],
          if (synData.trustLoyalty.isNotEmpty) ...[
            const SizedBox(height: 10),
            _buildMiniReading('match_details.match_info.trust_loyalty'.tr(), Icons.shield_outlined, const Color(0xFF10B981), synData.trustLoyalty),
          ],
          if (synData.intimacyText.isNotEmpty) ...[
            const SizedBox(height: 10),
            _buildMiniReading('match_details.match_info.intimacy'.tr(), Icons.local_fire_department_outlined, CosmicColors.sunsetOrange, synData.intimacyText),
          ],
          if (synData.conflictStyle.isNotEmpty) ...[
            const SizedBox(height: 10),
            _buildMiniReading('match_details.match_info.conflict_style'.tr(), Icons.balance, const Color(0xFFF59E0B), synData.conflictStyle),
          ],
          if (synData.valuesText.isNotEmpty) ...[
            const SizedBox(height: 10),
            _buildMiniReading('match_details.match_info.shared_values'.tr(), Icons.diamond_outlined, CosmicColors.sunsetOrange, synData.valuesText),
          ],
          if (synData.growthDynamicText.isNotEmpty) ...[
            const SizedBox(height: 10),
            _buildMiniReading('match_details.match_info.growth_together'.tr(), Icons.trending_up, const Color(0xFF10B981), synData.growthDynamicText),
          ],
        ],
      ),
    );
  }

  Widget _buildMiniReading(String title, IconData icon, Color color, String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 14),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _ExpandableBody(
            text: text,
            style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12, height: 1.5),
            accentColor: color,
          ),
        ],
      ),
    );
  }

  Widget _buildSynastryLoadingState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 60,
              height: 60,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(CosmicColors.cosmicPurple),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'match_details.match_info.calculating_connection'.tr(),
              style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 16, fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'match_details.match_info.analyzing_alignments'.tr(),
              style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSynastryMissingDataState(BuildContext context, Match match, User? currentUser) {
    final List<String> missingItems = [];
    final bool currentUserMissingBirth = currentUser?.birthDate == null;
    final bool matchedMissingBirth = match.matchedUser.birthDate == null;
    final bool currentUserMissingLocation = currentUser?.location == null;
    final bool matchedMissingLocation = match.matchedUser.location == null;

    if (currentUserMissingBirth) missingItems.add('Your birth date');
    if (matchedMissingBirth) missingItems.add('${match.matchedUser.name ?? 'This person'}\'s birth date');
    if (currentUserMissingLocation) missingItems.add('Your birth location');
    if (matchedMissingLocation) missingItems.add('${match.matchedUser.name ?? 'This person'}\'s birth location');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const SizedBox(height: 40),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: CosmicColors.cosmicPurple.withOpacity(0.2)),
            ),
            child: Column(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: CosmicColors.cosmicPurple.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.auto_awesome,
                    color: CosmicColors.cosmicPurple,
                    size: 40,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'match_details.match_info.need_both_birthdays'.tr(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'match_details.match_info.need_both_birthdays_desc'.tr(),
                  style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 14, height: 1.5),
                  textAlign: TextAlign.center,
                ),
                if (missingItems.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF97316).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFF97316).withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.info_outline, color: Color(0xFFF97316), size: 16),
                            const SizedBox(width: 8),
                            Text(
                              'match_details.match_info.missing_information'.tr(),
                              style: TextStyle(color: const Color(0xFFF97316), fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ...missingItems.map((item) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            '  - $item',
                            style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12),
                          ),
                        )),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                if (currentUserMissingBirth || currentUserMissingLocation)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: CosmicColors.cosmicPurple,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => context.push('/edit-profile'),
                      icon: const Icon(Icons.edit, size: 18),
                      label: Text('match_details.match_info.complete_profile'.tr()),
                    ),
                  ),
                if (!currentUserMissingBirth && !currentUserMissingLocation && (matchedMissingBirth || matchedMissingLocation)) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'match_details.match_info.waiting_for_partner_birth'.tr(args: [match.matchedUser.name ?? 'match_details.match_info.them'.tr()]),
                      style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13, height: 1.5),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  CosmicColors.cosmicPurple.withOpacity(0.1),
                  CosmicColors.cosmicPink.withOpacity(0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: CosmicColors.cosmicPurple.withOpacity(0.2)),
            ),
            child: Column(
              children: [
                Text(
                   'match_details.match_info.how_connect_title'.tr(),
                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                   'match_details.match_info.how_connect_desc'.tr(),
                  style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12, height: 1.5),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInsightCard(BuildContext context, Match match, SynastryData synData) {
    final bool fromApi = synData.overallVerdict.isNotEmpty;
    final String text = fromApi ? synData.overallVerdict : match.cosmicInsight;
    if (text.trim().isEmpty) return const SizedBox.shrink();

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
                fromApi
                    ? 'match_details.match_info.verdict'.tr()
                    : 'match_details.cosmic_insight'.tr(),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (synData.aiUsed) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: CosmicColors.cosmicPink.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'match_details.match_info.ai_generated'.tr(),
                    style: TextStyle(color: CosmicColors.cosmicPink, fontSize: 9, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Text(
            text,
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
        title: Text('match_details.block_user'.tr(), style: const TextStyle(color: Colors.white)),
        content: Text(
          'Are you sure you want to block ${widget.match.matchedUser.name}?',
          style: TextStyle(color: Colors.white.withOpacity(0.8)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('match_details.cancel'.tr(), style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(blockActionsProvider).block(widget.match.matchedUserId);
              if (context.mounted) context.pop();
            },
            child: Text('match_details.block'.tr(), style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class _ExpandableBody extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final Color accentColor;
  final int previewMax;

  const _ExpandableBody({
    required this.text,
    this.style,
    this.accentColor = CosmicColors.cosmicPurple,
    this.previewMax = 220,
  });

  @override
  State<_ExpandableBody> createState() => _ExpandableBodyState();
}

class _ExpandableBodyState extends State<_ExpandableBody> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final bool longText = widget.text.length > widget.previewMax;
    final String body = longText && !_expanded
        ? '${widget.text.substring(0, widget.previewMax).trimRight()}…'
        : widget.text;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(body, style: widget.style),
        if (longText) ...[
          const SizedBox(height: 6),
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Text(
              _expanded ? 'Show less' : 'Read more',
              style: TextStyle(
                color: widget.accentColor,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
