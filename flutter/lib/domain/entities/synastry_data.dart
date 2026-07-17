class SynastryData {
  final double moonScore;
  final double mercuryScore;
  final double venusMarsScore;
  final double nodesScore;
  final double saturnScore;
  final List<Aspect> detailedAspects;
  final String interpretation;
  final Map<String, double> dimensionScores;

  SynastryData({
    required this.moonScore,
    required this.mercuryScore,
    required this.venusMarsScore,
    required this.nodesScore,
    required this.saturnScore,
    required this.detailedAspects,
    required this.interpretation,
    this.dimensionScores = const {},
  });

  double get overallScore => (moonScore + mercuryScore + venusMarsScore + nodesScore + saturnScore) / 5;

  double get romanceScore => dimensionScores['romance'] ?? venusMarsScore;
  double get emotionalScore => dimensionScores['emotional'] ?? moonScore;
  double get communicationScore => dimensionScores['communication'] ?? mercuryScore;
  double get longTermScore => dimensionScores['long_term'] ?? saturnScore;
  double get marriageScore => dimensionScores['marriage'] ?? (saturnScore * 0.9 + moonScore * 0.1);
  double get friendshipScore => dimensionScores['friendship'] ?? (mercuryScore * 0.7 + moonScore * 0.3);
  double get chemistryScore => dimensionScores['chemistry'] ?? venusMarsScore;
  double get spiritualScore => dimensionScores['spiritual'] ?? nodesScore;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'moonScore': moonScore,
        'mercuryScore': mercuryScore,
        'venusMarsScore': venusMarsScore,
        'nodesScore': nodesScore,
        'saturnScore': saturnScore,
        'detailedAspects': detailedAspects.map((Aspect a) => a.toJson()).toList(),
        'interpretation': interpretation,
        'dimensionScores': dimensionScores,
      };

  factory SynastryData.fromJson(Map<String, dynamic> json) => SynastryData(
        moonScore: (json['moonScore'] as num).toDouble(),
        mercuryScore: (json['mercuryScore'] as num).toDouble(),
        venusMarsScore: (json['venusMarsScore'] as num).toDouble(),
        nodesScore: (json['nodesScore'] as num).toDouble(),
        saturnScore: (json['saturnScore'] as num).toDouble(),
        detailedAspects: (json['detailedAspects'] as List).map((a) => Aspect.fromJson(a as Map<String, dynamic>)).toList(),
        interpretation: json['interpretation'] as String,
        dimensionScores: json['dimensionScores'] != null
            ? Map<String, double>.from((json['dimensionScores'] as Map).map(
                (k, v) => MapEntry(k as String, (v as num).toDouble()),
              ))
            : const {},
      );

  SynastryData copyWith({
    double? moonScore,
    double? mercuryScore,
    double? venusMarsScore,
    double? nodesScore,
    double? saturnScore,
    List<Aspect>? detailedAspects,
    String? interpretation,
    Map<String, double>? dimensionScores,
  }) =>
      SynastryData(
        moonScore: moonScore ?? this.moonScore,
        mercuryScore: mercuryScore ?? this.mercuryScore,
        venusMarsScore: venusMarsScore ?? this.venusMarsScore,
        nodesScore: nodesScore ?? this.nodesScore,
        saturnScore: saturnScore ?? this.saturnScore,
        detailedAspects: detailedAspects ?? this.detailedAspects,
        interpretation: interpretation ?? this.interpretation,
        dimensionScores: dimensionScores ?? this.dimensionScores,
      );
}

class Aspect {
  final String planet1;
  final String planet2;
  final String aspectType;
  final double score;
  final String description;
  final String? planet1Sign;
  final String? planet2Sign;
  final double? orb;
  final bool isHarmonious;

  Aspect({
    required this.planet1,
    required this.planet2,
    required this.aspectType,
    required this.score,
    required this.description,
    this.planet1Sign,
    this.planet2Sign,
    this.orb,
    this.isHarmonious = true,
  });

  Map<String, dynamic> toJson() => <String, dynamic>{
        'planet1': planet1,
        'planet2': planet2,
        'aspectType': aspectType,
        'score': score,
        'description': description,
        'planet1Sign': planet1Sign,
        'planet2Sign': planet2Sign,
        'orb': orb,
        'isHarmonious': isHarmonious,
      };

  factory Aspect.fromJson(Map<String, dynamic> json) => Aspect(
        planet1: json['planet1'] as String,
        planet2: json['planet2'] as String,
        aspectType: json['aspectType'] as String,
        score: (json['score'] as num).toDouble(),
        description: json['description'] as String,
        planet1Sign: json['planet1Sign'] as String?,
        planet2Sign: json['planet2Sign'] as String?,
        orb: (json['orb'] as num?)?.toDouble(),
        isHarmonious: json['isHarmonious'] as bool? ?? true,
      );
}
