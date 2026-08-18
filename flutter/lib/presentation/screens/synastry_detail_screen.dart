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
import 'package:syno_app/presentation/widgets/compatibility_meter.dart';
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
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadCharts();
  }

  Future<void> _loadCharts() async {
    final currentUser = ref.read(currentUserProvider).value;
    if (currentUser?.birthDate == null || widget.match.matchedUser.birthDate == null) {
      setState(() => _loading = false);
      return;
    }

    final backendUrl = ref.read(backendUrlProvider);
    final apiService = AstrologyApiService(backendUrl);
    final c1 = await apiService.getChart(currentUser!);
    final c2 = await apiService.getChart(widget.match.matchedUser);

    if (mounted) {
      setState(() {
        _chart1 = c1;
        _chart2 = c2;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppThemeData theme = ref.watch(themeProvider);
    final SynastryData data = widget.match.synastryData;
    final AstrologySystem system = ref.watch(astrologySystemProvider);

    final Map<String, double> dimensions = {
      'Romance': data.romanceScore,
      'Communication': data.communicationScore,
      'Emotional': data.emotionalScore,
      'Long-term': data.longTermScore,
      'Chemistry': data.chemistryScore,
      'Spiritual': data.spiritualScore,
    };

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
          'Synastry Report',
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
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildOverallScore(context),
                const SizedBox(height: 24),
                if (_chart1 != null && _chart2 != null) ...[
                  Center(
                    child: ZodiacWheelWidget(
                      chart: _chart1!,
                      chart2: _chart2!,
                      showBothCharts: true,
                      size: 280,
                      system: system,
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
                if (widget.match.synastryData.interpretation.isNotEmpty) ...[
                  _buildSection(
                    context,
                    'Overall Reading',
                    Icons.auto_awesome,
                    CosmicColors.cosmicBlue,
                    Text(
                      widget.match.synastryData.interpretation,
                      style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 14, height: 1.5),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
                _buildStrengths(context, dimensions),
                const SizedBox(height: 20),
                _buildChallenges(context),
                const SizedBox(height: 20),
                if (widget.match.synastryData.communicationText.isNotEmpty) ...[
                  _buildSection(
                    context,
                    'Communication Style',
                    Icons.psychology,
                    CosmicColors.cosmicPurple,
                    Text(
                      widget.match.synastryData.communicationText,
                      style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 14, height: 1.5),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
                if (widget.match.synastryData.emotionalDynamicText.isNotEmpty) ...[
                  _buildSection(
                    context,
                    'Emotional Dynamic',
                    Icons.favorite,
                    CosmicColors.cosmicPink,
                    Text(
                      widget.match.synastryData.emotionalDynamicText,
                      style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 14, height: 1.5),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
                if (widget.match.synastryData.growthDynamicText.isNotEmpty) ...[
                  _buildSection(
                    context,
                    'Growth Potential',
                    Icons.trending_up,
                    CosmicColors.sunsetOrange,
                    Text(
                      widget.match.synastryData.growthDynamicText,
                      style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 14, height: 1.5),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
                _buildWhyWeMatched(context),
                const SizedBox(height: 20),
                _buildDetailedAspects(context),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOverallScore(BuildContext context) {
    final double score = widget.match.synastryScore;
    return Center(
      child: Column(
        children: [
          Text(
            'Overall Compatibility',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.white.withOpacity(0.8),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: 120,
            height: 120,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CircularProgressIndicator(
                  value: score / 100,
                  strokeWidth: 8,
                  backgroundColor: Colors.white.withOpacity(0.12),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    score >= 85
                        ? CosmicColors.cosmicPurple
                        : score >= 70
                            ? CosmicColors.cosmicPink
                            : CosmicColors.cosmicBlue,
                  ),
                ),
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${score.toInt()}%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Cosmic Match',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStrengths(BuildContext context, Map<String, double> dimensions) {
    final sortedDims = dimensions.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final List<String> backendStrengths = widget.match.synastryData.strengths;

    return _buildSection(
      context,
      'Strengths',
      Icons.star,
      CosmicColors.cosmicPurple,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (backendStrengths.isNotEmpty) ...[
            ...backendStrengths.map((s) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('✨ ', style: TextStyle(fontSize: 14)),
                  Expanded(
                    child: Text(
                      s,
                      style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 14, height: 1.4),
                    ),
                  ),
                ],
              ),
            )),
            const SizedBox(height: 8),
          ],
          ...sortedDims.take(5).map((entry) {
            final int stars = entry.value >= 90 ? 5 : entry.value >= 80 ? 4 : entry.value >= 70 ? 3 : 2;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      entry.key,
                      style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 15),
                    ),
                  ),
                  Row(
                    children: List.generate(5, (i) {
                      return Icon(
                        i < stars ? Icons.star : Icons.star_border,
                        color: i < stars ? CosmicColors.cosmicPink : Colors.white30,
                        size: 18,
                      );
                    }),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildChallenges(BuildContext context) {
    final List<String> challenges = _generateChallenges();

    return _buildSection(
      context,
      'Challenges',
      Icons.warning_amber_rounded,
      CosmicColors.sunsetOrange,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: challenges.map((c) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('• ', style: TextStyle(color: CosmicColors.sunsetOrange, fontSize: 16)),
                Expanded(
                  child: Text(
                    c,
                    style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 14, height: 1.4),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  List<String> _generateChallenges() {
    final SynastryData data = widget.match.synastryData;

    if (data.challenges.isNotEmpty) {
      return data.challenges;
    }

    final List<String> challenges = [];

    if (data.moonScore < 65) {
      challenges.add('Different emotional processing styles may cause misunderstandings');
    }
    if (data.saturnScore < 60) {
      challenges.add('Long-term commitment requires extra effort and patience');
    }
    if (data.mercuryScore < 70) {
      challenges.add('Communication styles may differ; active listening is key');
    }
    if (data.venusMarsScore < 60) {
      challenges.add('Physical chemistry may take time to develop');
    }
    if (data.nodesScore < 55) {
      challenges.add('Life paths may occasionally diverge; flexibility needed');
    }
    if (challenges.isEmpty) {
      challenges.add('This is an exceptionally harmonious pairing');
      challenges.add('Minor differences in emotional expression');
    }
    return challenges;
  }

  Widget _buildWhyWeMatched(BuildContext context) {
    final List<Aspect> topAspects = List<Aspect>.from(widget.match.synastryData.detailedAspects)
      ..sort((a, b) => b.score.compareTo(a.score));
    final List<Aspect> bestAspects = topAspects.where((a) => a.isHarmonious).take(5).toList();
    if (bestAspects.isEmpty) return const SizedBox.shrink();

    return _buildSection(
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

  Widget _buildDetailedAspects(BuildContext context) {
    if (widget.match.synastryData.detailedAspects.isEmpty) return const SizedBox.shrink();

    return _buildSection(
      context,
      'All Aspects',
      Icons.psychology,
      CosmicColors.cosmicBlue,
      Column(
        children: widget.match.synastryData.detailedAspects.map((aspect) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: CompatibilityMeter(
              label: '${aspect.planet1} ${_getAspectSymbol(aspect.aspectType)} ${aspect.planet2}',
              score: aspect.score,
              emoji: '⭐',
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSection(BuildContext context, String title, IconData icon, Color color, Widget child) {
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
                style: TextStyle(
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
