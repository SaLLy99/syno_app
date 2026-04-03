class SynastryData {
  final double moonScore;
  final double mercuryScore;
  final double venusMarsScore;
  final double nodesScore;
  final double saturnScore;
  final List<Aspect> detailedAspects;
  final String interpretation;

  SynastryData({
    required this.moonScore,
    required this.mercuryScore,
    required this.venusMarsScore,
    required this.nodesScore,
    required this.saturnScore,
    required this.detailedAspects,
    required this.interpretation,
  });

  double get overallScore => (moonScore + mercuryScore + venusMarsScore + nodesScore + saturnScore) / 5;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'moonScore': moonScore,
        'mercuryScore': mercuryScore,
        'venusMarsScore': venusMarsScore,
        'nodesScore': nodesScore,
        'saturnScore': saturnScore,
        'detailedAspects': detailedAspects.map((Aspect a) => a.toJson()).toList(),
        'interpretation': interpretation,
      };

  factory SynastryData.fromJson(Map<String, dynamic> json) => SynastryData(
        moonScore: (json['moonScore'] as num).toDouble(),
        mercuryScore: (json['mercuryScore'] as num).toDouble(),
        venusMarsScore: (json['venusMarsScore'] as num).toDouble(),
        nodesScore: (json['nodesScore'] as num).toDouble(),
        saturnScore: (json['saturnScore'] as num).toDouble(),
        detailedAspects: (json['detailedAspects'] as List).map((a) => Aspect.fromJson(a as Map<String, dynamic>)).toList(),
        interpretation: json['interpretation'] as String,
      );

  SynastryData copyWith({
    double? moonScore,
    double? mercuryScore,
    double? venusMarsScore,
    double? nodesScore,
    double? saturnScore,
    List<Aspect>? detailedAspects,
    String? interpretation,
  }) =>
      SynastryData(
        moonScore: moonScore ?? this.moonScore,
        mercuryScore: mercuryScore ?? this.mercuryScore,
        venusMarsScore: venusMarsScore ?? this.venusMarsScore,
        nodesScore: nodesScore ?? this.nodesScore,
        saturnScore: saturnScore ?? this.saturnScore,
        detailedAspects: detailedAspects ?? this.detailedAspects,
        interpretation: interpretation ?? this.interpretation,
      );
}

class Aspect {
  final String planet1;
  final String planet2;
  final String aspectType;
  final double score;
  final String description;

  Aspect({
    required this.planet1,
    required this.planet2,
    required this.aspectType,
    required this.score,
    required this.description,
  });

  Map<String, dynamic> toJson() => <String, dynamic>{
        'planet1': planet1,
        'planet2': planet2,
        'aspectType': aspectType,
        'score': score,
        'description': description,
      };

  factory Aspect.fromJson(Map<String, dynamic> json) => Aspect(
        planet1: json['planet1'] as String,
        planet2: json['planet2'] as String,
        aspectType: json['aspectType'] as String,
        score: (json['score'] as num).toDouble(),
        description: json['description'] as String,
      );
}
