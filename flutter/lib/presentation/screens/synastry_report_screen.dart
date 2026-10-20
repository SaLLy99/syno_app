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

class SynastryReportScreen extends ConsumerStatefulWidget {
  final Match match;

  const SynastryReportScreen({super.key, required this.match});

  @override
  ConsumerState<SynastryReportScreen> createState() => _SynastryReportScreenState();
}

class _SynastryReportScreenState extends ConsumerState<SynastryReportScreen> {
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

    debugPrint('[SynastryReport] _loadData: currentUser=${currentUser?.name}, matchedUser=${widget.match.matchedUser.name}');

    if (currentUser?.birthDate == null || widget.match.matchedUser.birthDate == null) {
      debugPrint('[SynastryReport] _loadData: missing birth data');
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'missing_birth_data';
        });
      }
      return;
    }

    try {
      debugPrint('[SynastryReport] _loadData: fetching charts + synastry from API...');
      final c1 = await apiService.getChart(currentUser!);
      final c2 = await apiService.getChart(widget.match.matchedUser);
      if (mounted) setState(() { _chart1 = c1; _chart2 = c2; });

      final synastry = await apiService.getSynastry(currentUser, widget.match.matchedUser);
      debugPrint('[SynastryReport] _loadData: synastry=${synastry != null ? 'loaded (overall=${synastry.overallScore}, aiUsed=${synastry.aiUsed})' : 'null'}');
      if (mounted) {
        if (synastry != null) {
          setState(() => _loadedSynastry = synastry);
        } else if (widget.match.synastryData == null) {
          setState(() => _error = 'load_error');
        }
      }
    } catch (e) {
      debugPrint('[SynastryReport] Error loading data: $e');
      if (mounted && widget.match.synastryData == null) {
        setState(() => _error = 'load_error');
      }
    }

    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final AppThemeData theme = ref.watch(themeProvider);
    final AstrologySystem system = ref.watch(astrologySystemProvider);

    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: BoxDecoration(gradient: theme.gradient),
        child: SafeArea(
          child: _loading
              ? _buildLoadingState()
              : _error == 'missing_birth_data'
                  ? _buildMissingBirthDataState()
                  : _error != null
                      ? _buildErrorState()
                      : _buildBody(context, system),
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
              'Writing your full match report...',
              style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 16, fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Analyzing planetary alignments between you two',
              style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMissingBirthDataState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cake_outlined, color: Colors.white.withOpacity(0.5), size: 48),
            const SizedBox(height: 16),
            Text('Need Both Birthdays', style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(
              'We need both your birthdays to write this report.',
              style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
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

  Widget _buildBody(BuildContext context, AstrologySystem system) {
    final AppThemeData theme = ref.watch(themeProvider);
    return CustomScrollView(
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
            'Full Match Report',
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
                _buildWhyWeMatched(context),
                const SizedBox(height: AppSpacing.xl),
                if (_effectiveSynastry.topAspects.isNotEmpty) ...[
                  TopAspectsCard(aspects: _effectiveSynastry.topAspects),
                  const SizedBox(height: AppSpacing.xl),
                ],
                if (_chart1 != null && _chart2 != null) ...[
                  _buildDualChart(context, _chart1!, _chart2!, system),
                  const SizedBox(height: AppSpacing.xl),
                ],
                _buildOverallInterpretation(context),
                const SizedBox(height: AppSpacing.xl),
                if (_chart1 != null && _chart2 != null) ...[
                  _buildPlanetComparison(context, _chart1!, _chart2!),
                  const SizedBox(height: AppSpacing.xl),
                ],
                _buildDetailedAspects(context),
                const SizedBox(height: AppSpacing.xl),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    final SynastryData data = _effectiveSynastry;
    // Canonical match score first so every screen shows the same %.
    final double matchScore = widget.match.finalScore;
    final double score = matchScore > 0
        ? matchScore
        : data.primaryScore(fallback: widget.match.synastryScore);
    final List<Map<String, dynamic>> scoreParts = widget.match.scoreParts.isNotEmpty
        ? widget.match.scoreParts
        : <Map<String, dynamic>>[
            <String, dynamic>{
              'key': 'chart',
              'value': widget.match.synastryScore.round(),
              'partial': widget.match.chartPartial,
            },
            <String, dynamic>{
              'key': 'behavior',
              'value': widget.match.behavioralScore?.round(),
              'partial': false,
            },
          ];
    return Container(
      padding: AppSpacing.paddingLg,
      decoration: BoxDecoration(
        gradient: CosmicColors.cosmicGradient,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: CosmicColors.cosmicPurple30,
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
            'You & ${widget.match.matchedUser.name}',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Colors.white.withOpacity(0.9),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            '${score.toStringAsFixed(0)}%',
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            'Overall Compatibility',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.white.withOpacity(0.7),
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          ScoreBandLabel(score: score),
          if (scoreParts.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            ScorePartsRow(parts: scoreParts),
          ],
        ],
      ),
    );
  }

  Widget _buildDualChart(BuildContext context, NatalChart chart1, NatalChart chart2, AstrologySystem system) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Natal Chart Overlay',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Center(
          child: ZodiacWheelWidget(
            chart: chart1,
            chart2: chart2,
            showBothCharts: true,
            size: 300,
            system: system,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildLegendItem('Your Planets', const Color(0xFFFBBF24)),
            const SizedBox(width: 24),
            _buildLegendItem('${widget.match.matchedUser.name}', const Color(0xFF60A5FA)),
          ],
        ),
      ],
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildWhyWeMatched(BuildContext context) {
    final List<Aspect> topAspects = List<Aspect>.from(_effectiveSynastry.detailedAspects)
      ..sort((a, b) => b.score.compareTo(a.score));
    final List<Aspect> bestAspects = topAspects.where((a) => a.isHarmonious).take(5).toList();
    if (bestAspects.isEmpty) return const SizedBox.shrink();

    return _buildReportSection(
      context,
      'Why We Matched',
      Icons.auto_awesome,
      CosmicColors.cosmicPink,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: bestAspects.map((aspect) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(
                  color: _getAspectColor(aspect.score).withOpacity(0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: _getAspectColor(aspect.score).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          aspect.aspectType,
                          style: TextStyle(
                            color: _getAspectColor(aspect.score),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${aspect.planet1} ${_getAspectSymbol(aspect.aspectType)} ${aspect.planet2}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Text(
                        '${aspect.score.toStringAsFixed(0)}%',
                        style: TextStyle(
                          color: _getAspectColor(aspect.score),
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    aspect.description,
                    style: TextStyle(color: Colors.white.withOpacity(0.75), fontSize: 13, height: 1.4),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  String _getAspectSymbol(String type) {
    switch (type.toLowerCase()) {
      case 'conjunction': return '☌';
      case 'sextile': return '⚹';
      case 'trine': return '△';
      case 'square': return '□';
      case 'opposition': return '☍';
      default: return '•';
    }
  }

  Widget _buildOverallInterpretation(BuildContext context) {
    return _buildReportSection(
      context,
      'Overall Interpretation',
      Icons.auto_stories,
      CosmicColors.cosmicPurple,
      _ExpandableText(
        text: _effectiveSynastry.interpretation,
        style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 14, height: 1.6),
        accentColor: CosmicColors.cosmicPurple,
      ),
    );
  }

  Widget _buildPlanetComparison(BuildContext context, NatalChart chart1, NatalChart chart2) {
    final List<MapEntry<String, String>> planets1 = chart1.getPlanetSigns();
    final List<MapEntry<String, String>> planets2 = chart2.getPlanetSigns();

    return _buildReportSection(
      context,
      'Planet Sign Comparison',
      Icons.compare_arrows,
      CosmicColors.cosmicBlue,
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'You',
                    style: TextStyle(
                      color: const Color(0xFFFBBF24),
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(width: 80, child: Text('Planet', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12), textAlign: TextAlign.center)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.match.matchedUser.name ?? 'Match',
                    style: TextStyle(
                      color: const Color(0xFF60A5FA),
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
            const Divider(color: Colors.white12, height: 16),
            ...List.generate(planets1.length, (index) {
              final String planet = planets1[index].key;
              final String sign1 = planets1[index].value;
              final String sign2 = planets2.length > index ? planets2[index].value : '?';
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${NatalChart.planetSymbols[planet] ?? ''} $sign1',
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 80,
                      child: Text(
                        planet,
                        style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '$sign2 ${NatalChart.planetSymbols[planet] ?? ''}',
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailedAspects(BuildContext context) {
    return _buildReportSection(
      context,
      'Detailed Planetary Aspects',
      Icons.psychology,
      CosmicColors.sunsetOrange,
      Column(
        children: _effectiveSynastry.detailedAspects.map((Aspect aspect) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(
                  color: _getAspectColor(aspect.score).withOpacity(0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: _getAspectColor(aspect.score).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          aspect.aspectType,
                          style: TextStyle(
                            color: _getAspectColor(aspect.score),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${aspect.planet1} ${_getAspectSymbol(aspect.aspectType)} ${aspect.planet2}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Text(
                        '${aspect.score.toStringAsFixed(0)}%',
                        style: TextStyle(
                          color: _getAspectColor(aspect.score),
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  if (aspect.planet1Sign != null || aspect.planet2Sign != null) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        if (aspect.planet1Sign != null)
                          Text(
                            '${NatalChart.planetSymbols[aspect.planet1] ?? ''} ${aspect.planet1Sign}',
                            style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12),
                          ),
                        if (aspect.orb != null) ...[
                          const SizedBox(width: 8),
                          Text(
                            'Orb: ${aspect.orb!.toStringAsFixed(1)}°',
                            style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11),
                          ),
                        ],
                        const Spacer(),
                        if (aspect.planet2Sign != null)
                          Text(
                            '${aspect.planet2Sign} ${NatalChart.planetSymbols[aspect.planet2] ?? ''}',
                            style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12),
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    aspect.description,
                    style: TextStyle(color: Colors.white.withOpacity(0.75), fontSize: 13, height: 1.4),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildReportSection(BuildContext context, String title, IconData icon, Color color, Widget child) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Color _getAspectColor(double score) {
    if (score >= 80) return CosmicColors.cosmicPurple;
    if (score >= 65) return CosmicColors.cosmicPink;
    if (score >= 50) return CosmicColors.cosmicBlue;
    return Colors.grey;
  }
}

class _ExpandableText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final Color accentColor;
  final int previewMax;

  const _ExpandableText({
    required this.text,
    this.style,
    this.accentColor = CosmicColors.cosmicPurple,
    this.previewMax = 220,
  });

  @override
  State<_ExpandableText> createState() => _ExpandableTextState();
}

class _ExpandableTextState extends State<_ExpandableText> {
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
          const SizedBox(height: 8),
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
