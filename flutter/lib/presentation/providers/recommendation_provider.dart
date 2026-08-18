import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syno_app/domain/entities/user.dart';
import 'package:syno_app/presentation/providers/auth_providers.dart';

class RecommendationItem {
  final int id;
  final int recommendedUserId;
  final int score;
  final List<String> reasons;
  final String cosmicInsight;
  final String recommendationDate;
  final User? profile;

  RecommendationItem({
    required this.id,
    required this.recommendedUserId,
    required this.score,
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
    if (baseUrl == null || baseUrl.isEmpty) return <RecommendationItem>[];

    final response = await Dio().get(
      '$baseUrl/api/recommendations/daily',
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
