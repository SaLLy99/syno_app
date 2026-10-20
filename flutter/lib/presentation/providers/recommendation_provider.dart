import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syno_app/domain/entities/user.dart';
import 'package:syno_app/presentation/providers/app_mode_provider.dart';
import 'package:syno_app/domain/entities/app_mode.dart';

class RecommendationItem {
  final int id;
  final int recommendedUserId;

  /// Daily-pick ranking score (chart + profile quality + activity mix).
  final int score;

  /// Headline % shown to the user: the natal chart score, identical to
  /// every other screen. Null when the chart could not be computed.
  final int? compatibilityScore;
  final List<String> reasons;
  final String cosmicInsight;
  final String recommendationDate;
  final User? profile;

  RecommendationItem({
    required this.id,
    required this.recommendedUserId,
    required this.score,
    this.compatibilityScore,
    required this.reasons,
    required this.cosmicInsight,
    required this.recommendationDate,
    this.profile,
  });

  factory RecommendationItem.fromJson(Map<String, dynamic> json) {
    return RecommendationItem(
      id: json['id'] as int? ?? 0,
      recommendedUserId: json['recommended_user_id'] as int? ?? 0,
      score: json['score'] as int? ?? 0,
      compatibilityScore: json['compatibility_score'] as int?,
      reasons: (json['reasons'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ?? <String>[],
      cosmicInsight: json['cosmic_insight'] as String? ?? '',
      recommendationDate: json['recommendation_date'] as String? ?? '',
      profile: json['profile'] != null
          ? User.fromJson(json['profile'] as Map<String, dynamic>)
          : null,
    );
  }
}

final FutureProvider<List<RecommendationItem>> dailyRecommendationsProvider =
  FutureProvider<List<RecommendationItem>>((Ref ref) async {
  try {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? token = prefs.getString('auth_token');
    if (token == null) return <RecommendationItem>[];

    final String? baseUrl = prefs.getString('backend_url');
    // Watch appModeProvider to re-fetch when mode changes
    final currentMode = ref.watch(appModeProvider);
    final String mode = currentMode.value;
    if (baseUrl == null || baseUrl.isEmpty) return <RecommendationItem>[];

    final response = await Dio().get(
      '$baseUrl/api/recommendations/daily',
      queryParameters: {'mode': mode},
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = response.data as List<dynamic>;
      final List<RecommendationItem> recommendations = data
          .map((json) => RecommendationItem.fromJson(json as Map<String, dynamic>))
          .toList();
      debugPrint('[dailyRecommendations] Loaded ${recommendations.length} recommendations');
      return recommendations;
    }
  } catch (e) {
    debugPrint('[dailyRecommendations] Error: $e');
    rethrow;
  }
  return <RecommendationItem>[];
});
