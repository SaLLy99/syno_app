import 'package:syno_app/domain/entities/synastry_data.dart';
import 'package:syno_app/domain/entities/user.dart';

enum MatchStatus { pending, accepted, declined, saved, hidden }

class Match {
  final String id;
  final String userId;
  final String matchedUserId;
  final User matchedUser;
  final double finalScore;
  final double synastryScore;

  /// Observed behaviour compatibility — null when we have no real signals yet.
  final double? behavioralScore;
  final List<String> topReasons;
  final String cosmicInsight;
  final SynastryData? synastryData;
  final MatchStatus status;
  final DateTime createdAt;
  final double? weightedScore;
  final int? backendMatchId;

  /// Transparent breakdown behind [finalScore]:
  /// [{key: chart|behavior|profile, label, value: int?, partial: bool}, ...]
  /// value == null means "no data yet" (never a placeholder number).
  final List<Map<String, dynamic>> scoreParts;

  /// Birth time was missing; chart computed at noon (Ascendant/houses approximate).
  final bool chartPartial;

  Match({
    required this.id,
    required this.userId,
    required this.matchedUserId,
    required this.matchedUser,
    required this.finalScore,
    required this.synastryScore,
    this.behavioralScore,
    required this.topReasons,
    required this.cosmicInsight,
    this.synastryData,
    required this.status,
    required this.createdAt,
    this.weightedScore,
    this.backendMatchId,
    this.scoreParts = const [],
    this.chartPartial = false,
  });

  SynastryData get synastryDataOrEmpty => synastryData ?? SynastryData(
    moonScore: 50, mercuryScore: 50, venusMarsScore: 50,
    nodesScore: 50, saturnScore: 50,
    detailedAspects: const <Aspect>[],
    interpretation: '',
  );

  double get averageScore {
    final syn = synastryData;
    if (syn == null) return finalScore;
    final List<double> dims = [
      syn.romanceScore,
      syn.emotionalScore,
      syn.chemistryScore,
    ];
    if (dims.isEmpty) return finalScore;
    return dims.reduce((a, b) => a + b) / dims.length;
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'userId': userId,
        'matchedUserId': matchedUserId,
        'matchedUser': matchedUser.toJson(),
        'finalScore': finalScore,
        'synastryScore': synastryScore,
        'behavioralScore': behavioralScore,
        'topReasons': topReasons,
        'cosmicInsight': cosmicInsight,
        'synastryData': synastryData?.toJson(),
        'status': status.name,
        'createdAt': createdAt.toIso8601String(),
        'weightedScore': weightedScore,
        'backendMatchId': backendMatchId,
        'scoreParts': scoreParts,
        'chartPartial': chartPartial,
      };

  factory Match.fromJson(Map<String, dynamic> json) => Match(
        id: json['id'] as String,
        userId: json['userId'] as String,
        matchedUserId: json['matchedUserId'] as String,
        matchedUser: User.fromJson(json['matchedUser'] as Map<String, dynamic>),
        finalScore: (json['finalScore'] as num).toDouble(),
        synastryScore: (json['synastryScore'] as num).toDouble(),
        behavioralScore: (json['behavioralScore'] as num?)?.toDouble(),
        topReasons: List<String>.from(json['topReasons'] as List),
        cosmicInsight: json['cosmicInsight'] as String,
        synastryData: json['synastryData'] != null
            ? SynastryData.fromJson(json['synastryData'] as Map<String, dynamic>)
            : null,
        status: MatchStatus.values.firstWhere((MatchStatus e) => e.name == json['status']),
        createdAt: DateTime.parse(json['createdAt'] as String),
        weightedScore: (json['weightedScore'] as num?)?.toDouble(),
        backendMatchId: json['backendMatchId'] as int?,
        scoreParts: (json['scoreParts'] as List<dynamic>?)
                ?.map((e) => Map<String, dynamic>.from(e as Map))
                .toList() ??
            const [],
        chartPartial: json['chartPartial'] as bool? ?? false,
      );

  Match copyWith({
    String? id,
    String? userId,
    String? matchedUserId,
    User? matchedUser,
    double? finalScore,
    double? synastryScore,
    double? behavioralScore,
    bool clearBehavioralScore = false,
    List<String>? topReasons,
    String? cosmicInsight,
    SynastryData? synastryData,
    MatchStatus? status,
    DateTime? createdAt,
    double? weightedScore,
    int? backendMatchId,
    List<Map<String, dynamic>>? scoreParts,
    bool? chartPartial,
  }) =>
      Match(
        id: id ?? this.id,
        userId: userId ?? this.userId,
        matchedUserId: matchedUserId ?? this.matchedUserId,
        matchedUser: matchedUser ?? this.matchedUser,
        finalScore: finalScore ?? this.finalScore,
        synastryScore: synastryScore ?? this.synastryScore,
        behavioralScore: clearBehavioralScore ? null : (behavioralScore ?? this.behavioralScore),
        topReasons: topReasons ?? this.topReasons,
        cosmicInsight: cosmicInsight ?? this.cosmicInsight,
        synastryData: synastryData ?? this.synastryData,
        status: status ?? this.status,
        createdAt: createdAt ?? this.createdAt,
        weightedScore: weightedScore ?? this.weightedScore,
        backendMatchId: backendMatchId ?? this.backendMatchId,
        scoreParts: scoreParts ?? this.scoreParts,
        chartPartial: chartPartial ?? this.chartPartial,
      );
}
