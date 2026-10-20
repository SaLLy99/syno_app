import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syno_app/presentation/widgets/score_breakdown.dart';
import 'package:syno_app/theme.dart';

class CompatibilityReport {
  final int? matchId;
  final double overallScore;
  final double chartScore;

  /// Null when we have no observed behaviour for this pair yet.
  final double? behaviorScore;

  /// Null when neither profile has comparable interests/values yet.
  final double? profileSimilarity;

  /// Chart / Behaviour / Profile breakdown behind [overallScore].
  /// `value == null` means "no data yet" (never a placeholder number).
  final List<Map<String, dynamic>> scoreParts;

  /// Ranked aspects behind the headline score.
  final List<Map<String, dynamic>> topAspects;

  /// True when the chart was computed at noon (birth time missing).
  final bool scorePartial;

  /// Weighted blend of the available parts (kept for ranking / reference).
  final double? compositeScore;
  final String cosmicInsight;
  final List<String> topReasons;
  final Map<String, double> dimensions;
  final Map<String, Map<String, dynamic>> dimensionMeta;
  final Map<String, double> synastry;
  final Map<String, List<String>> shared;
  final Map<String, dynamic> profiles;
  final Map<String, dynamic> interpretation;
  final String summary;
  final List<String> coachTips;
  final List<String> strengths;
  final List<String> challenges;
  final String communicationText;
  final String emotionalDynamicText;
  final String valuesText;
  final String growthDynamicText;
  final String personalityA;
  final String personalityB;
  final String loveLanguage;
  final String trustLoyalty;
  final String intimacyText;
  final String conflictStyle;
  final String overallVerdict;

  CompatibilityReport({
    this.matchId,
    required this.overallScore,
    required this.chartScore,
    this.behaviorScore,
    this.profileSimilarity,
    this.scoreParts = const [],
    this.topAspects = const [],
    this.scorePartial = false,
    this.compositeScore,
    required this.cosmicInsight,
    required this.topReasons,
    required this.dimensions,
    this.dimensionMeta = const {},
    required this.synastry,
    required this.shared,
    required this.profiles,
    this.interpretation = const {},
    this.summary = '',
    this.coachTips = const [],
    this.strengths = const [],
    this.challenges = const [],
    this.communicationText = '',
    this.emotionalDynamicText = '',
    this.valuesText = '',
    this.growthDynamicText = '',
    this.personalityA = '',
    this.personalityB = '',
    this.loveLanguage = '',
    this.trustLoyalty = '',
    this.intimacyText = '',
    this.conflictStyle = '',
    this.overallVerdict = '',
  });

  factory CompatibilityReport.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> scoreBreakdown =
        (json['score_breakdown'] as Map<String, dynamic>?) ?? <String, dynamic>{};

    final Map<String, double> dimensions = <String, double>{};
    final Map<String, Map<String, dynamic>> dimensionMeta =
        <String, Map<String, dynamic>>{};
    final dynamic dimsRaw = json['dimensions'];
    if (dimsRaw is Map<String, dynamic>) {
      dimsRaw.forEach((String key, dynamic value) {
        if (value is num) {
          dimensions[key] = value.toDouble();
        } else if (value is Map<String, dynamic>) {
          dimensionMeta[key] = value;
          if (value['score'] is num) {
            dimensions[key] = (value['score'] as num).toDouble();
          }
        }
      });
    }

    final Map<String, double> synastry = <String, double>{};
    final dynamic synRaw = json['synastry'];
    if (synRaw is Map<String, dynamic>) {
      synRaw.forEach((String key, dynamic value) {
        if (value is num) {
          synastry[key] = value.toDouble();
        }
      });
    }

    final Map<String, dynamic> interp =
        (json['interpretation'] as Map<String, dynamic>?) ?? <String, dynamic>{};

    double asDouble(dynamic v, [double fallback = 0]) =>
        v is num ? v.toDouble() : fallback;

    double? asNullableDouble(dynamic v) => v is num ? v.toDouble() : null;

    List<String> asStringList(dynamic v) =>
        (v as List<dynamic>?)?.map((e) => e.toString()).toList() ?? <String>[];

    String asString(dynamic v) => v is String ? v : '';

    return CompatibilityReport(
      matchId: json['match_id'] is int ? json['match_id'] as int : null,
      overallScore: asDouble(json['overall_score']),
      chartScore: asDouble(
        scoreBreakdown['chart'] ?? json['chart_score'],
        asDouble(json['overall_score']),
      ),
      behaviorScore: asNullableDouble(
        scoreBreakdown['behavior'] ?? json['behavior_score'],
      ),
      scoreParts: (json['score_parts'] as List<dynamic>?)
              ?.map((dynamic e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          const <Map<String, dynamic>>[],
      topAspects: (json['top_aspects'] as List<dynamic>?)
              ?.map((dynamic e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          const <Map<String, dynamic>>[],
      scorePartial: json['score_partial'] as bool? ?? false,
      compositeScore: asNullableDouble(json['composite_score']),
      profileSimilarity: asNullableDouble(
        scoreBreakdown['profile_similarity'] ??
            json['profile_similarity_score'] ??
            json['profile_similarity'],
      ),
      cosmicInsight: json['cosmic_insight'] as String? ?? '',
      topReasons: asStringList(json['top_reasons']),
      dimensions: dimensions,
      dimensionMeta: dimensionMeta,
      synastry: synastry,
      shared: (json['shared'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(
              k,
              (v as List<dynamic>?)?.map((e) => e as String).toList() ??
                  <String>[],
            ),
          ) ??
          <String, List<String>>{},
      profiles: json['profiles'] as Map<String, dynamic>? ?? <String, dynamic>{},
      interpretation: interp,
      summary: asString(interp['summary']),
      coachTips: asStringList(interp['coach_tips']),
      strengths: asStringList(interp['strengths']),
      challenges: asStringList(interp['challenges']),
      communicationText: asString(interp['communication']),
      emotionalDynamicText: asString(interp['emotional_dynamic']),
      valuesText: asString(interp['values']),
      growthDynamicText: asString(interp['growth_dynamic']),
      personalityA: asString(interp['personality_a']),
      personalityB: asString(interp['personality_b']),
      loveLanguage: asString(interp['love_language']),
      trustLoyalty: asString(interp['trust_loyalty']),
      intimacyText: asString(interp['intimacy_text']),
      conflictStyle: asString(interp['conflict_style']),
      overallVerdict: asString(interp['overall_verdict']),
    );
  }

  /// Parts that differ from [primary] by at least 1 point; null parts are skipped.
  List<MapEntry<String, double>> distinctSecondaries(double primary) {
    final Map<String, double> parts = <String, double>{
      'Chart': chartScore,
      if (behaviorScore != null) 'Behavior': behaviorScore!,
      if (profileSimilarity != null) 'Profile': profileSimilarity!,
    };
    final List<MapEntry<String, double>> out = <MapEntry<String, double>>[];
    for (final MapEntry<String, double> e in parts.entries) {
      if ((e.value - primary).abs() >= 1.0) {
        out.add(e);
      }
    }
    return out;
  }
}

class CompatibilityReportScreen extends StatefulWidget {
  final int matchId;
  final String matchedUserName;

  const CompatibilityReportScreen({
    super.key,
    required this.matchId,
    required this.matchedUserName,
  });

  @override
  State<CompatibilityReportScreen> createState() => _CompatibilityReportScreenState();
}

class _CompatibilityReportScreenState extends State<CompatibilityReportScreen> {
  CompatibilityReport? _report;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  Future<void> _loadReport() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? token = prefs.getString('auth_token');
      final String? baseUrl = prefs.getString('backend_url');
      if (token == null || baseUrl == null) {
        debugPrint('[CompatibilityReport][ERROR] Missing token or baseUrl');
        return;
      }

      debugPrint('[CompatibilityReport][REQUEST] Loading report for matchId=${widget.matchId}');
      final response = await Dio().get(
        '$baseUrl/api/matches/${widget.matchId}/compatibility',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      debugPrint('[CompatibilityReport][RESPONSE] status=${response.statusCode}');

      if (response.statusCode == 200 && mounted) {
        final report = CompatibilityReport.fromJson(response.data as Map<String, dynamic>);
        debugPrint('[CompatibilityReport][SUCCESS] overall=${report.overallScore}, chart=${report.chartScore}, behavior=${report.behaviorScore}, profile=${report.profileSimilarity}, dimensions=${report.dimensions.length}, topReasons=${report.topReasons.length}');
        setState(() {
          _report = report;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('[CompatibilityReport][EXCEPTION] Error loading report: $e');
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Compatibility with ${widget.matchedUserName}'),
        backgroundColor: const Color(0xFF1A0B2E),
      ),
      backgroundColor: const Color(0xFF0D0221),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, color: Colors.white, size: 48),
                      const SizedBox(height: 16),
                      Text('Error loading report', style: TextStyle(color: Colors.white.withOpacity(0.8))),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadReport,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _buildReport(),
    );
  }

  Widget _buildReport() {
    if (_report == null) return const SizedBox.shrink();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildOverallScore(),
          const SizedBox(height: 24),
          if (_report!.topAspects.isNotEmpty) ...[
            TopAspectsCard(aspects: _report!.topAspects),
            const SizedBox(height: 24),
          ],
          _buildCosmicInsight(),
          const SizedBox(height: 24),
          _buildPersonalitySection(),
          const SizedBox(height: 24),
          _buildDimensionRadar(),
          const SizedBox(height: 24),
          _buildFullReading(),
          const SizedBox(height: 24),
          _buildStrengthsChallenges(),
          const SizedBox(height: 24),
          _buildSynastryBreakdown(),
          const SizedBox(height: 24),
          _buildTopReasons(),
          const SizedBox(height: 24),
          _buildSharedInterests(),
          const SizedBox(height: 24),
          _buildZodiacComparison(),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildOverallScore() {
    final Color scoreColor = _getScoreColor(_report!.overallScore);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [scoreColor.withOpacity(0.3), const Color(0xFF1A0B2E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scoreColor.withOpacity(0.5), width: 2),
      ),
      child: Column(
        children: [
          Text(
            '${_report!.overallScore.round()}%',
            style: TextStyle(
              color: scoreColor,
              fontSize: 64,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'score.headline_chart'.tr(),
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 16,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          ScoreBandLabel(
            score: _report!.overallScore,
            background: Colors.white.withOpacity(0.08),
          ),
          if (_report!.scoreParts.isNotEmpty) ...[
            const SizedBox(height: 16),
            ScorePartsRow(parts: _report!.scoreParts),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required List<Widget> children,
    IconData icon = Icons.auto_awesome,
    Color iconColor = Colors.purple,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A0B2E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor.withOpacity(0.9), size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  String _profileLabel(String? name, String fallback) {
    final String value = (name ?? '').trim();
    return value.isEmpty ? fallback : value;
  }

  Widget _buildPersonalitySection() {
    final String nameA = _profileLabel(_report!.profiles['user_a']?['name'], 'You');
    final String nameB = _profileLabel(_report!.profiles['user_b']?['name'], 'Them');
    final String personalityA = _report!.personalityA.trim();
    final String personalityB = _report!.personalityB.trim();

    if (personalityA.isEmpty && personalityB.isEmpty) {
      return const SizedBox.shrink();
    }

    return _buildSectionCard(
      title: 'PERSONALITY READ',
      icon: Icons.psychology,
      iconColor: CosmicColors.cosmicPink,
      children: [
        if (personalityA.isNotEmpty) ...[
          Text(
            nameA,
            style: TextStyle(
              color: CosmicColors.cosmicPink,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            personalityA,
            style: TextStyle(color: Colors.white.withOpacity(0.88), fontSize: 14, height: 1.5),
          ),
          const SizedBox(height: 16),
        ],
        if (personalityB.isNotEmpty) ...[
          Text(
            nameB,
            style: TextStyle(
              color: Colors.purpleAccent,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            personalityB,
            style: TextStyle(color: Colors.white.withOpacity(0.88), fontSize: 14, height: 1.5),
          ),
        ],
      ],
    );
  }

  Widget _readingItem(String title, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: Colors.white.withOpacity(0.55),
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            text,
            style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 14, height: 1.55),
          ),
        ],
      ),
    );
  }

  Widget _buildFullReading() {
    final Map<String, String> blocks = <String, String>{
      'SUMMARY': _report!.summary,
      'COMMUNICATION': _report!.communicationText,
      'EMOTIONAL DYNAMIC': _report!.emotionalDynamicText,
      'SHARED VALUES': _report!.valuesText,
      'GROWTH': _report!.growthDynamicText,
      'LOVE LANGUAGE': _report!.loveLanguage,
      'TRUST & LOYALTY': _report!.trustLoyalty,
      'CHEMISTRY': _report!.intimacyText,
      'CONFLICT STYLE': _report!.conflictStyle,
      'THE VERDICT': _report!.overallVerdict,
    };

    final List<MapEntry<String, String>> filled = blocks.entries
        .where((MapEntry<String, String> e) => e.value.trim().isNotEmpty)
        .toList();

    if (filled.isEmpty) return const SizedBox.shrink();

    return _buildSectionCard(
      title: 'FULL READING',
      icon: Icons.menu_book,
      iconColor: Colors.tealAccent,
      children: filled
          .map((MapEntry<String, String> e) => _readingItem(e.key, e.value))
          .toList(),
    );
  }

  Widget _buildStrengthsChallenges() {
    final List<String> strengths = _report!.strengths;
    final List<String> challenges = _report!.challenges;
    if (strengths.isEmpty && challenges.isEmpty) return const SizedBox.shrink();

    return _buildSectionCard(
      title: 'STRENGTHS & CHALLENGES',
      icon: Icons.balance,
      iconColor: Colors.orangeAccent,
      children: [
        if (strengths.isNotEmpty) ...[
          Row(
            children: [
              Icon(Icons.add_circle, color: Colors.green.withOpacity(0.9), size: 16),
              const SizedBox(width: 6),
              Text(
                'STRENGTHS',
                style: TextStyle(
                  color: Colors.green,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...strengths.map((s) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 6),
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        s,
                        style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 13.5, height: 1.4),
                      ),
                    ),
                  ],
                ),
              )),
          const SizedBox(height: 8),
        ],
        if (challenges.isNotEmpty) ...[
          Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 16),
              const SizedBox(width: 6),
              Text(
                'CHALLENGES',
                style: TextStyle(
                  color: Colors.amber,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...challenges.map((c) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 6),
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Colors.amber,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        c,
                        style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 13.5, height: 1.4),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ],
    );
  }

  Widget _buildCosmicInsight() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A0B2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.purple.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, color: Colors.amber.withOpacity(0.8), size: 20),
              const SizedBox(width: 8),
              Text(
                'Cosmic Insight',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _report!.cosmicInsight,
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 15,
              height: 1.5,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDimensionRadar() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A0B2E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Compatibility Dimensions',
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 14,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 16),
          ..._report!.dimensions.entries.map((entry) {
            return _buildDimensionBar(entry.key, entry.value);
          }),
        ],
      ),
    );
  }

  Widget _buildDimensionBar(String label, double score) {
    final Color color = _getScoreColor(score);
    final Map<String, dynamic> meta = _report!.dimensionMeta[label] ?? const {};
    final String displayName = (meta['label'] is String &&
            (meta['label'] as String).trim().isNotEmpty)
        ? (meta['label'] as String)
        : label.replaceAll('_', ' ').toUpperCase();
    final String description =
        meta['description'] is String ? (meta['description'] as String) : '';
    final List<String> keyFactors = (meta['key_factors'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        <String>[];

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  displayName,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Text(
                '${score.round()}%',
                style: TextStyle(
                  color: color,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: score / 100,
              backgroundColor: Colors.white.withOpacity(0.1),
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 8,
            ),
          ),
          if (description.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              description,
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 11.5,
                height: 1.35,
              ),
            ),
          ],
          if (keyFactors.isNotEmpty) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: keyFactors.take(5).map((String f) {
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: color.withOpacity(0.35)),
                  ),
                  child: Text(
                    f,
                    style: TextStyle(
                      color: color,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSynastryBreakdown() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A0B2E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Planetary Connection',
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 14,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 16),
          _buildSynastryGrid(),
        ],
      ),
    );
  }

  Widget _buildSynastryGrid() {
    final Map<String, String> planetNames = {
      'moon': '🌙 Moon',
      'mercury': '💬 Mercury',
      'venus_mars': '💫 Venus-Mars',
      'nodes': '✨ Nodes',
      'saturn': '🪐 Saturn',
    };

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: _report!.synastry.entries.map((entry) {
        final String name = planetNames[entry.key] ?? entry.key;
        final double score = entry.value;
        final Color color = _getScoreColor(score);

        return Container(
          width: (MediaQuery.of(context).size.width - 56) / 2,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Column(
            children: [
              Text(
                name,
                style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12),
              ),
              const SizedBox(height: 8),
              Text(
                '${score.round()}%',
                style: TextStyle(
                  color: color,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTopReasons() {
    if (_report!.topReasons.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A0B2E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Why You Match',
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 14,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          ..._report!.topReasons.map((reason) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.check_circle, color: CosmicColors.cosmicPink, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    reason,
                    style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13),
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildSharedInterests() {
    final List<String> hobbies = _report!.shared['hobbies'] ?? [];
    final List<String> values = _report!.shared['values'] ?? [];
    final List<String> intentions = _report!.shared['intentions'] ?? [];

    if (hobbies.isEmpty && values.isEmpty && intentions.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A0B2E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'What You Share',
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 14,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          if (hobbies.isNotEmpty) ...[
            Text(
              'Interests',
              style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: hobbies.map((h) => _buildSharedChip(h, CosmicColors.cosmicPink)).toList(),
            ),
            const SizedBox(height: 12),
          ],
          if (values.isNotEmpty) ...[
            Text(
              'Core Values',
              style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: values.map((v) => _buildSharedChip(v, Colors.purple)).toList(),
            ),
            const SizedBox(height: 12),
          ],
          if (intentions.isNotEmpty) ...[
            Text(
              'Intentions',
              style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: intentions.map((i) => _buildSharedChip(i, Colors.teal)).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSharedChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        label.replaceAll('_', ' '),
        style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 12),
      ),
    );
  }

  Widget _buildZodiacComparison() {
    final String? zodiacA = _report!.profiles['user_a']?['zodiac'];
    final String? zodiacB = _report!.profiles['user_b']?['zodiac'];
    final String? nameA = _report!.profiles['user_a']?['name'];
    final String? nameB = _report!.profiles['user_b']?['name'];

    if (zodiacA == null && zodiacB == null) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A0B2E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Zodiac Signs',
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 14,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildZodiacCard(_profileLabel(nameA, 'You'), zodiacA),
              Icon(Icons.favorite, color: CosmicColors.cosmicPink.withOpacity(0.6), size: 32),
              _buildZodiacCard(_profileLabel(nameB, 'Them'), zodiacB),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildZodiacCard(String name, String? zodiac) {
    return Column(
      children: [
        Text(
          _getZodiacEmoji(zodiac),
          style: const TextStyle(fontSize: 40),
        ),
        const SizedBox(height: 8),
        Text(
          name,
          style: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          zodiac ?? 'Unknown',
          style: TextStyle(
            color: Colors.white.withOpacity(0.6),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  String _getZodiacEmoji(String? sign) {
    const emojis = {
      'Aries': '\u2648', 'Taurus': '\u2649', 'Gemini': '\u264A', 'Cancer': '\u264B',
      'Leo': '\u264C', 'Virgo': '\u264D', 'Libra': '\u264E', 'Scorpio': '\u264F',
      'Sagittarius': '\u2650', 'Capricorn': '\u2651', 'Aquarius': '\u2652', 'Pisces': '\u2653',
    };
    return emojis[sign] ?? '\u2B50';
  }

  Color _getScoreColor(double score) {
    if (score >= 80) return Colors.green;
    if (score >= 65) return Colors.blue;
    if (score >= 50) return Colors.orange;
    return Colors.red;
  }
}
