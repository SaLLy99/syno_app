import 'dart:math';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syno_app/presentation/providers/theme_provider.dart';
import 'package:syno_app/theme.dart';

class CompatibilityReport {
  final int matchId;
  final double overallScore;
  final double synastryScore;
  final double profileSimilarity;
  final String cosmicInsight;
  final List<String> topReasons;
  final Map<String, double> dimensions;
  final Map<String, double> synastry;
  final Map<String, List<String>> shared;
  final Map<String, dynamic> profiles;

  CompatibilityReport({
    required this.matchId,
    required this.overallScore,
    required this.synastryScore,
    required this.profileSimilarity,
    required this.cosmicInsight,
    required this.topReasons,
    required this.dimensions,
    required this.synastry,
    required this.shared,
    required this.profiles,
  });

  factory CompatibilityReport.fromJson(Map<String, dynamic> json) {
    return CompatibilityReport(
      matchId: json['match_id'] as int,
      overallScore: (json['overall_score'] as num).toDouble(),
      synastryScore: (json['synastry_score'] as num).toDouble(),
      profileSimilarity: (json['profile_similarity'] as num).toDouble(),
      cosmicInsight: json['cosmic_insight'] as String? ?? '',
      topReasons: (json['top_reasons'] as List<dynamic>?)?.map((e) => e as String).toList() ?? [],
      dimensions: (json['dimensions'] as Map<String, dynamic>?)?.map((k, v) => MapEntry(k, (v as num).toDouble())) ?? {},
      synastry: (json['synastry'] as Map<String, dynamic>?)?.map((k, v) => MapEntry(k, (v as num).toDouble())) ?? {},
      shared: (json['shared'] as Map<String, dynamic>?)?.map((k, v) => MapEntry(k, (v as List<dynamic>?)?.map((e) => e as String).toList() ?? [])) ?? {},
      profiles: json['profiles'] as Map<String, dynamic>? ?? {},
    );
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
      if (token == null || baseUrl == null) return;

      final response = await Dio().get(
        '$baseUrl/api/matches/${widget.matchId}/compatibility',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      if (response.statusCode == 200 && mounted) {
        setState(() {
          _report = CompatibilityReport.fromJson(response.data as Map<String, dynamic>);
          _isLoading = false;
        });
      }
    } catch (e) {
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
          _buildCosmicInsight(),
          const SizedBox(height: 24),
          _buildDimensionRadar(),
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
            'Overall Compatibility',
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 16,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildScoreChip('Synastry', _report!.synastryScore, Colors.purple),
              _buildScoreChip('Profile Match', _report!.profileSimilarity, Colors.teal),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildScoreChip(String label, double score, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Column(
        children: [
          Text(
            '${score.round()}%',
            style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          Text(
            label,
            style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12),
          ),
        ],
      ),
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
    final String displayName = label.replaceAll('_', ' ').toUpperCase();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                displayName,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
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
            'Planetary Synastry',
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
              _buildZodiacCard(nameA ?? 'You', zodiacA),
              Icon(Icons.favorite, color: CosmicColors.cosmicPink.withOpacity(0.6), size: 32),
              _buildZodiacCard(nameB ?? 'Them', zodiacB),
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
