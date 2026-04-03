import 'package:syno_app/domain/entities/synastry_data.dart';
import 'package:syno_app/domain/entities/user.dart';

enum MatchStatus { pending, accepted, declined }

class Match {
  final String id;
  final String userId;
  final String matchedUserId;
  final User matchedUser;
  final double finalScore;
  final double synastryScore;
  final double behavioralScore;
  final List<String> topReasons;
  final String cosmicInsight;
  final SynastryData synastryData;
  final MatchStatus status;
  final DateTime createdAt;

  Match({
    required this.id,
    required this.userId,
    required this.matchedUserId,
    required this.matchedUser,
    required this.finalScore,
    required this.synastryScore,
    required this.behavioralScore,
    required this.topReasons,
    required this.cosmicInsight,
    required this.synastryData,
    required this.status,
    required this.createdAt,
  });

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
        'synastryData': synastryData.toJson(),
        'status': status.name,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Match.fromJson(Map<String, dynamic> json) => Match(
        id: json['id'] as String,
        userId: json['userId'] as String,
        matchedUserId: json['matchedUserId'] as String,
        matchedUser: User.fromJson(json['matchedUser'] as Map<String, dynamic>),
        finalScore: (json['finalScore'] as num).toDouble(),
        synastryScore: (json['synastryScore'] as num).toDouble(),
        behavioralScore: (json['behavioralScore'] as num).toDouble(),
        topReasons: List<String>.from(json['topReasons'] as List),
        cosmicInsight: json['cosmicInsight'] as String,
        synastryData: SynastryData.fromJson(json['synastryData'] as Map<String, dynamic>),
        status: MatchStatus.values.firstWhere((MatchStatus e) => e.name == json['status']),
        createdAt: DateTime.parse(json['createdAt'] as String),
      );

  Match copyWith({
    String? id,
    String? userId,
    String? matchedUserId,
    User? matchedUser,
    double? finalScore,
    double? synastryScore,
    double? behavioralScore,
    List<String>? topReasons,
    String? cosmicInsight,
    SynastryData? synastryData,
    MatchStatus? status,
    DateTime? createdAt,
  }) =>
      Match(
        id: id ?? this.id,
        userId: userId ?? this.userId,
        matchedUserId: matchedUserId ?? this.matchedUserId,
        matchedUser: matchedUser ?? this.matchedUser,
        finalScore: finalScore ?? this.finalScore,
        synastryScore: synastryScore ?? this.synastryScore,
        behavioralScore: behavioralScore ?? this.behavioralScore,
        topReasons: topReasons ?? this.topReasons,
        cosmicInsight: cosmicInsight ?? this.cosmicInsight,
        synastryData: synastryData ?? this.synastryData,
        status: status ?? this.status,
        createdAt: createdAt ?? this.createdAt,
      );
}
