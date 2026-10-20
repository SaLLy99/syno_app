import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:syno_app/domain/entities/match.dart';
import 'package:syno_app/domain/entities/natal_chart.dart';
import 'package:syno_app/domain/entities/synastry_data.dart';
import 'package:syno_app/data/services/astrology_api_service.dart';
import 'package:syno_app/domain/entities/astrology_system.dart';
import 'package:syno_app/presentation/providers/auth_providers.dart';
import 'package:syno_app/presentation/providers/user_provider.dart';
import 'package:syno_app/presentation/providers/theme_provider.dart';
import 'package:syno_app/presentation/widgets/score_breakdown.dart';
import 'package:syno_app/presentation/widgets/zodiac_wheel_widget.dart';
import 'package:syno_app/theme.dart';

class SynastryDetailScreen extends ConsumerStatefulWidget {
  final Match match;

  const SynastryDetailScreen({super.key, required this.match});

  @override
  ConsumerState<SynastryDetailScreen> createState() => _SynastryDetailScreenState();
}

class _SynastryDetailScreenState extends ConsumerState<SynastryDetailScreen> {
  NatalChart? _chart1;
  NatalChart? _chart2;
  SynastryData? _loadedSynastry;
  bool _loading = true;
  String? _error;

  SynastryData get _effectiveSynastry => _loadedSynastry ?? widget.match.synastryDataOrEmpty;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final currentUser = ref.read(currentUserProvider).value;
    final backendUrl = ref.read(backendUrlProvider);
    final apiService = AstrologyApiService(backendUrl);

    if (currentUser?.birthDate == null || widget.match.matchedUser.birthDate == null) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'missing_birth_data';
        });
      }
      return;
    }

    try {
      final c1 = await apiService.getChart(currentUser!);
      final c2 = await apiService.getChart(widget.match.matchedUser);
      if (mounted) setState(() { _chart1 = c1; _chart2 = c2; });

      final synastry = await apiService.getSynastry(currentUser, widget.match.matchedUser);
      if (mounted) {
        if (synastry != null) {
          setState(() => _loadedSynastry = synastry);
        } else if (widget.match.synastryData == null) {
          setState(() => _error = 'load_error');
        }
      }
    } catch (e) {
      debugPrint('[SynastryDetail] Error loading data: $e');
      if (mounted) setState(() => _error = 'load_error');
    }

    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final AppThemeData theme = ref.watch(themeProvider);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: theme.primaryTextColor),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'You & ${widget.match.matchedUser.name ?? 'them'}',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: theme.primaryTextColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: Container(
        decoration: BoxDecoration(gradient: theme.gradient),
        child: SafeArea(
          child: _loading
              ? _buildLoadingState()
              : _error == 'missing_birth_data'
                  ? _buildMissingDataState()
                  : _error != null
                      ? _buildErrorState()
                      : _buildContent(),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 60, height: 60,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(CosmicColors.cosmicPurple),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Reading the stars for you two...',
              style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 16, fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Finding how you two connect...',
              style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMissingDataState() {
    final currentUser = ref.read(currentUserProvider).value;
    final List<String> missingItems = [];
    if (currentUser?.birthDate == null) missingItems.add('Your birth date');
    if (widget.match.matchedUser.birthDate == null) missingItems.add('${widget.match.matchedUser.name ?? 'This person'}\'s birth date');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const SizedBox(height: 60),
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
                  width: 80, height: 80,
                  decoration: BoxDecoration(
                    color: CosmicColors.cosmicPurple.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.auto_awesome, color: CosmicColors.cosmicPurple, size: 40),
                ),
                const SizedBox(height: 20),
                const Text('Need Both Birthdays', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Text(
                  'We need both your birthdays to see how the stars connect you.',
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
                      children: missingItems.map((item) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text('  - $item', style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12)),
                      )).toList(),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: Colors.white.withOpacity(0.5), size: 48),
            const SizedBox(height: 16),
            Text('Something went wrong', style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 16, fontWeight: FontWeight.w500)),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: CosmicColors.cosmicPurple, foregroundColor: Colors.white),
              onPressed: () { setState(() { _loading = true; _error = null; }); _loadData(); },
              child: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    final SynastryData data = _effectiveSynastry;
    final AstrologySystem system = ref.watch(astrologySystemProvider);
    final nameA = widget.match.matchedUser.name ?? 'them';

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _buildHeroHeader(data, nameA)),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverList.list(
            children: [
              const SizedBox(height: 16),
              if (_chart1 != null && _chart2 != null) ...[
                _buildChartOverlay(_chart1!, _chart2!, system, nameA),
                const SizedBox(height: 16),
              ],
              if (data.personalityA.isNotEmpty || data.personalityB.isNotEmpty)
                _buildPersonalityProfiles(data, nameA),
              if (data.personalityA.isNotEmpty || data.personalityB.isNotEmpty)
                const SizedBox(height: 16),
              _buildOverallVerdict(data),
              const SizedBox(height: 16),
              if (data.topAspects.isNotEmpty) ...[
                TopAspectsCard(aspects: data.topAspects),
                const SizedBox(height: 16),
              ],
              _buildDimensionScores(data),
              const SizedBox(height: 16),
              _buildInterpretationCards(data),
              const SizedBox(height: 16),
              _buildStrengthsAndChallenges(data),
              const SizedBox(height: 16),
              _buildWhyWeMatched(),
              const SizedBox(height: 16),
              _buildAllAspects(),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeroHeader(SynastryData data, String nameA) {
    // Same number the discover badge and match list show.
    final double matchScore = widget.match.finalScore;
    final double score = matchScore > 0
        ? matchScore
        : data.primaryScore(fallback: widget.match.synastryScore);
    final Color scoreColor = score >= 85 ? const Color(0xFF10B981)
        : score >= 70 ? const Color(0xFF3B82F6)
        : CosmicColors.sunsetOrange;

    String verdict = 'Cosmic Connection';
    if (score >= 85) verdict = 'Exceptional Cosmic Bond';
    else if (score >= 70) verdict = 'Strong Celestial Connection';
    else if (score >= 55) verdict = 'Growing Cosmic Bond';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
      child: Column(
        children: [
          Text(
            'Your Synastry Reading',
            style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12, letterSpacing: 1.5, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: 120, height: 120,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CircularProgressIndicator(
                  value: score / 100,
                  strokeWidth: 7,
                  backgroundColor: Colors.white.withOpacity(0.08),
                  valueColor: AlwaysStoppedAnimation<Color>(scoreColor),
                ),
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('${score.toInt()}%', style: TextStyle(color: scoreColor, fontSize: 32, fontWeight: FontWeight.bold)),
                      Text('Match', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(verdict, style: TextStyle(color: scoreColor, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(
            'You & $nameA',
            style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13),
          ),
          if (widget.match.scoreParts.isNotEmpty) ...[
            const SizedBox(height: 16),
            ScorePartsRow(parts: widget.match.scoreParts),
          ],
        ],
      ),
    );
  }

  Widget _buildChartOverlay(NatalChart chart1, NatalChart chart2, AstrologySystem system, String nameA) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(Icons.wb_sunny, 'Chart Overlay', const Color(0xFFFBBF24)),
          const SizedBox(height: 12),
          Center(
            child: ZodiacWheelWidget(
              chart: chart1, chart2: chart2,
              showBothCharts: true, size: 240, system: system,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _legendDot(const Color(0xFFFBBF24), 'Your Planets'),
              const SizedBox(width: 20),
              _legendDot(const Color(0xFF60A5FA), '$nameA\'s Planets'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 11)),
      ],
    );
  }

  Widget _buildPersonalityProfiles(SynastryData data, String nameA) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(Icons.person_outline, 'Your Personalities', CosmicColors.cosmicPurple),
          const SizedBox(height: 14),
          if (data.personalityA.isNotEmpty) ...[
            _personalityCard('You', data.personalityA, const Color(0xFFFBBF24)),
            const SizedBox(height: 10),
          ],
          if (data.personalityB.isNotEmpty)
            _personalityCard(nameA, data.personalityB, const Color(0xFF60A5FA)),
        ],
      ),
    );
  }

  Widget _personalityCard(String name, String text, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8, height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Text(name, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          Text(text, style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 13, height: 1.6)),
        ],
      ),
    );
  }

  Widget _buildOverallVerdict(SynastryData data) {
    final text = data.overallVerdict.isNotEmpty ? data.overallVerdict : data.interpretation;
    if (text.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [CosmicColors.cosmicPurple.withOpacity(0.15), Colors.white.withOpacity(0.03)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: CosmicColors.cosmicPurple.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, color: CosmicColors.cosmicPurple, size: 18),
              const SizedBox(width: 8),
              Text(
                data.overallVerdict.isNotEmpty ? 'The Verdict' : 'Your Story',
                style: TextStyle(color: CosmicColors.cosmicPurple, fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(text, style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 14, height: 1.7)),
        ],
      ),
    );
  }

  Widget _buildDimensionScores(SynastryData data) {
    final dimensions = [
      _DimData('❤️', 'Romance', 'Chemistry and romantic spark', data.romanceScore, CosmicColors.cosmicPink),
      _DimData('🧠', 'Communication', 'How you understand each other', data.communicationScore, CosmicColors.cosmicBlue),
      _DimData('🌙', 'Emotional', 'Depth of emotional bonding', data.emotionalScore, CosmicColors.cosmicPurple),
      _DimData('💍', 'Long-Term', 'Standing the test of time', data.longTermScore, const Color(0xFF10B981)),
      _DimData('⚡', 'Chemistry', 'Magnetic pull between you', data.chemistryScore, CosmicColors.sunsetOrange),
      _DimData('✨', 'Spiritual', 'Soul-level resonance', data.spiritualScore, const Color(0xFF8B5CF6)),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(Icons.insights, 'Compatibility Breakdown', const Color(0xFF3B82F6)),
          const SizedBox(height: 14),
          ...dimensions.map((d) => _dimensionRow(d)),
        ],
      ),
    );
  }

  Widget _dimensionRow(_DimData d) {
    final String level = d.score >= 85 ? 'Exceptional'
        : d.score >= 70 ? 'Strong'
        : d.score >= 55 ? 'Good'
        : 'Growing';

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(d.emoji, style: const TextStyle(fontSize: 14)),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(d.label, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                    Text(d.description, style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 10)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('${d.score.toInt()}%', style: TextStyle(color: d.color, fontSize: 15, fontWeight: FontWeight.bold)),
                  Text(level, style: TextStyle(color: d.color.withOpacity(0.7), fontSize: 9)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: d.score / 100,
              backgroundColor: Colors.white.withOpacity(0.08),
              valueColor: AlwaysStoppedAnimation<Color>(d.color),
              minHeight: 5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInterpretationCards(SynastryData data) {
    final cards = <_InterpCardData>[];

    if (data.loveLanguage.isNotEmpty) {
      cards.add(_InterpCardData('Love Language', Icons.favorite_outline, CosmicColors.cosmicPink, data.loveLanguage));
    }
    if (data.communicationText.isNotEmpty) {
      cards.add(_InterpCardData('Communication Style', Icons.chat_bubble_outline, CosmicColors.cosmicBlue, data.communicationText));
    }
    if (data.emotionalDynamicText.isNotEmpty) {
      cards.add(_InterpCardData('Emotional Bond', Icons.nights_stay, CosmicColors.cosmicPurple, data.emotionalDynamicText));
    }
    if (data.trustLoyalty.isNotEmpty) {
      cards.add(_InterpCardData('Trust & Loyalty', Icons.shield_outlined, const Color(0xFF10B981), data.trustLoyalty));
    }
    if (data.intimacyText.isNotEmpty) {
      cards.add(_InterpCardData('Intimacy & Chemistry', Icons.local_fire_department_outlined, CosmicColors.sunsetOrange, data.intimacyText));
    }
    if (data.conflictStyle.isNotEmpty) {
      cards.add(_InterpCardData('How You Handle Conflict', Icons.balance, const Color(0xFFF59E0B), data.conflictStyle));
    }
    if (data.valuesText.isNotEmpty) {
      cards.add(_InterpCardData('Shared Values', Icons.diamond_outlined, const Color(0xFFEC4899), data.valuesText));
    }
    if (data.growthDynamicText.isNotEmpty) {
      cards.add(_InterpCardData('Growth Together', Icons.trending_up, const Color(0xFF06B6D4), data.growthDynamicText));
    }

    if (cards.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(Icons.auto_stories, 'Reading', CosmicColors.cosmicPurple),
          const SizedBox(height: 14),
          ...cards.map((c) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _interpCard(c),
          )),
        ],
      ),
    );
  }

  Widget _interpCard(_InterpCardData data) {
    return _ExpandableReadingCard(data: data);
  }

  Widget _buildStrengthsAndChallenges(SynastryData data) {
    if (data.strengths.isEmpty && data.challenges.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(Icons.balance, 'Strengths & Growth Areas', const Color(0xFF10B981)),
          const SizedBox(height: 14),
          if (data.strengths.isNotEmpty) ...[
            Text('Strengths', style: TextStyle(color: const Color(0xFF10B981), fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            ...data.strengths.map((s) => _bulletPoint(s, const Color(0xFF10B981))),
          ],
          if (data.challenges.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('Growth Areas', style: TextStyle(color: CosmicColors.sunsetOrange, fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            ...data.challenges.map((c) => _bulletPoint(c, CosmicColors.sunsetOrange)),
          ],
        ],
      ),
    );
  }

  Widget _bulletPoint(String text, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 5),
            width: 6, height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 13, height: 1.5)),
          ),
        ],
      ),
    );
  }

  Widget _buildWhyWeMatched() {
    final List<Aspect> topAspects = List<Aspect>.from(_effectiveSynastry.detailedAspects)
      ..sort((a, b) => b.score.compareTo(a.score));
    final List<Aspect> bestAspects = topAspects.where((a) => a.isHarmonious).take(5).toList();
    if (bestAspects.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(Icons.auto_awesome, 'Why We Matched', CosmicColors.cosmicPink),
          const SizedBox(height: 14),
          ...bestAspects.map((aspect) => _aspectCard(aspect)),
        ],
      ),
    );
  }

  Widget _aspectCard(Aspect aspect) {
    final color = _aspectColor(aspect.score);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(aspect.aspectType, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${aspect.planet1} ${aspect.aspectSymbol} ${aspect.planet2}',
                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
                Text('${aspect.score.toStringAsFixed(0)}%', style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.bold)),
              ],
            ),
            if (aspect.planet1Sign != null || aspect.planet2Sign != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  if (aspect.planet1Sign != null) ...[
                    Text(_zodiacEmoji(aspect.planet1Sign!), style: const TextStyle(fontSize: 11)),
                    const SizedBox(width: 2),
                    Text(aspect.planet1Sign!, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 10)),
                  ],
                  if (aspect.planet1Sign != null && aspect.planet2Sign != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Text(aspect.aspectSymbol, style: TextStyle(color: color.withOpacity(0.5), fontSize: 10)),
                    ),
                  if (aspect.planet2Sign != null) ...[
                    Text(_zodiacEmoji(aspect.planet2Sign!), style: const TextStyle(fontSize: 11)),
                    const SizedBox(width: 2),
                    Text(aspect.planet2Sign!, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 10)),
                  ],
                ],
              ),
            ],
            const SizedBox(height: 6),
            Text(aspect.description, style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12, height: 1.5)),
          ],
        ),
      ),
    );
  }

  Widget _buildAllAspects() {
    final aspects = _effectiveSynastry.detailedAspects;
    if (aspects.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(Icons.psychology, 'All Planetary Aspects', CosmicColors.cosmicBlue),
          const SizedBox(height: 14),
          ...aspects.map((a) {
            final color = _aspectColor(a.score);
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Container(
                    width: 4, height: 28,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${a.planet1} ${a.aspectSymbol} ${a.planet2}',
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                        if (a.planet1Sign != null)
                          Text(a.planet1Sign!, style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 10)),
                      ],
                    ),
                  ),
                  Text('${a.score.toStringAsFixed(0)}%', style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.bold)),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  BoxDecoration _cardDecoration() => BoxDecoration(
    color: Colors.white.withOpacity(0.05),
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: Colors.white.withOpacity(0.08)),
  );

  Widget _sectionHeader(IconData icon, String title, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(width: 10),
        Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Color _aspectColor(double score) {
    if (score >= 80) return CosmicColors.cosmicPurple;
    if (score >= 65) return CosmicColors.cosmicPink;
    if (score >= 50) return CosmicColors.cosmicBlue;
    return Colors.grey;
  }

  String _zodiacEmoji(String sign) {
    const emojis = {
      'Aries': '\u2648', 'Taurus': '\u2649', 'Gemini': '\u264A', 'Cancer': '\u264B',
      'Leo': '\u264C', 'Virgo': '\u264D', 'Libra': '\u264E', 'Scorpio': '\u264F',
      'Sagittarius': '\u2650', 'Capricorn': '\u2651', 'Aquarius': '\u2652', 'Pisces': '\u2653',
    };
    return emojis[sign] ?? '';
  }
}

class _DimData {
  final String emoji;
  final String label;
  final String description;
  final double score;
  final Color color;
  _DimData(this.emoji, this.label, this.description, this.score, this.color);
}

class _InterpCardData {
  final String title;
  final IconData icon;
  final Color color;
  final String text;
  _InterpCardData(this.title, this.icon, this.color, this.text);
}

class _ExpandableReadingCard extends StatefulWidget {
  final _InterpCardData data;
  const _ExpandableReadingCard({required this.data});

  @override
  State<_ExpandableReadingCard> createState() => _ExpandableReadingCardState();
}

class _ExpandableReadingCardState extends State<_ExpandableReadingCard> {
  static const int _previewMax = 160;
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final _InterpCardData data = widget.data;
    final bool longText = data.text.length > _previewMax;
    final String body = longText && !_expanded
        ? '${data.text.substring(0, _previewMax).trimRight()}…'
        : data.text;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: data.color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: data.color.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: data.color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(data.icon, color: data.color, size: 14),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  data.title,
                  style: TextStyle(color: data.color, fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            body,
            style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 13, height: 1.6),
          ),
          if (longText) ...[
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Text(
                _expanded ? 'Show less' : 'Read more',
                style: TextStyle(
                  color: data.color,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
