import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syno_app/presentation/providers/theme_provider.dart';
import 'package:syno_app/theme.dart';

class AnalyticsData {
  final Map<String, dynamic> stats;
  final Map<String, dynamic> profileStrength;
  final List<Map<String, dynamic>> tips;

  AnalyticsData({
    required this.stats,
    required this.profileStrength,
    required this.tips,
  });

  factory AnalyticsData.fromJson(Map<String, dynamic> json) {
    return AnalyticsData(
      stats: json['stats'] as Map<String, dynamic>? ?? {},
      profileStrength: json['profile_strength'] as Map<String, dynamic>? ?? {},
      tips: (json['tips'] as List<dynamic>?)?.map((e) => e as Map<String, dynamic>).toList() ?? [],
    );
  }
}

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  AnalyticsData? _data;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  Future<void> _loadAnalytics() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? token = prefs.getString('auth_token');
      final String? baseUrl = prefs.getString('backend_url');
      if (token == null || baseUrl == null) return;

      final response = await Dio().get(
        '$baseUrl/api/analytics/dashboard',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      if (response.statusCode == 200 && mounted) {
        setState(() {
          _data = AnalyticsData.fromJson(response.data as Map<String, dynamic>);
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
        title: const Text('Analytics'),
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
                      Text('Error loading analytics', style: TextStyle(color: Colors.white.withOpacity(0.8))),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadAnalytics,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _buildDashboard(),
    );
  }

  Widget _buildDashboard() {
    if (_data == null) return const SizedBox.shrink();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildProfileStrength(),
          const SizedBox(height: 24),
          _buildStatsGrid(),
          const SizedBox(height: 24),
          _buildMatchRateChart(),
          const SizedBox(height: 24),
          _buildTips(),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildProfileStrength() {
    final int score = _data!.profileStrength['score'] as int? ?? 0;
    final List<dynamic> items = _data!.profileStrength['items'] as List<dynamic>? ?? [];

    Color scoreColor;
    String label;
    if (score >= 80) {
      scoreColor = Colors.green;
      label = 'Excellent';
    } else if (score >= 60) {
      scoreColor = Colors.blue;
      label = 'Good';
    } else if (score >= 40) {
      scoreColor = Colors.orange;
      label = 'Needs Work';
    } else {
      scoreColor = Colors.red;
      label = 'Incomplete';
    }

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
            '$score%',
            style: TextStyle(
              color: scoreColor,
              fontSize: 56,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Profile Strength - $label',
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 16,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 20),
          ...items.map((item) {
            final String status = item['status'] as String? ?? 'needs_work';
            final Color itemColor = status == 'good' ? Colors.green : status == 'needs_work' ? Colors.orange : Colors.red;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Icon(
                    status == 'good' ? Icons.check_circle : Icons.warning,
                    color: itemColor,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item['label'] as String? ?? '',
                      style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13),
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

  Widget _buildStatsGrid() {
    final Map<String, dynamic> stats = _data!.stats;

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: [
        _buildStatCard('Likes Given', '${stats['likes_given'] ?? 0}', Icons.favorite, Colors.pink),
        _buildStatCard('Likes Received', '${stats['likes_received'] ?? 0}', Icons.favorite_border, Colors.red),
        _buildStatCard('Mutual Matches', '${stats['mutual_matches'] ?? 0}', Icons.people, Colors.green),
        _buildStatCard('Match Rate', '${stats['match_rate'] ?? 0}%', Icons.trending_up, Colors.blue),
        _buildStatCard('Messages', '${stats['total_messages'] ?? 0}', Icons.chat, Colors.purple),
        _buildStatCard('Unread', '${stats['unread_messages'] ?? 0}', Icons.mark_chat_unread, Colors.orange),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 11,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildMatchRateChart() {
    final Map<String, dynamic> stats = _data!.stats;
    final double matchRate = (stats['match_rate'] ?? 0).toDouble();
    final double responseRate = (stats['response_rate'] ?? 0).toDouble();

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
            'Performance',
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 14,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 20),
          _buildRateBar('Match Rate', matchRate, Colors.green),
          const SizedBox(height: 16),
          _buildRateBar('Response Rate', responseRate, Colors.blue),
        ],
      ),
    );
  }

  Widget _buildRateBar(String label, double rate, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12),
            ),
            Text(
              '${rate.round()}%',
              style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: rate / 100,
            backgroundColor: Colors.white.withOpacity(0.1),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 8,
          ),
        ),
      ],
    );
  }

  Widget _buildTips() {
    if (_data!.tips.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tips to Improve',
          style: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        ..._data!.tips.map((tip) {
          final String priority = tip['priority'] as String? ?? 'low';
          final Color tipColor = priority == 'high' ? Colors.red : priority == 'medium' ? Colors.orange : Colors.green;
          final IconData icon = _getTipIcon(tip['icon'] as String? ?? 'lightbulb');

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: tipColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: tipColor.withOpacity(0.3)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: tipColor, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tip['title'] as String? ?? '',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        tip['description'] as String? ?? '',
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
          );
        }),
      ],
    );
  }

  IconData _getTipIcon(String iconName) {
    switch (iconName) {
      case 'photo_camera':
        return Icons.photo_camera;
      case 'edit_note':
        return Icons.edit_note;
      case 'interests':
        return Icons.interests;
      case 'favorite':
        return Icons.favorite;
      case 'tune':
        return Icons.tune;
      case 'schedule':
        return Icons.schedule;
      case 'celebration':
        return Icons.celebration;
      default:
        return Icons.lightbulb;
    }
  }
}
