class SynastryData {
  final double moonScore;
  final double mercuryScore;
  final double venusMarsScore;
  final double nodesScore;
  final double saturnScore;
  final List<Aspect> detailedAspects;
  final String interpretation;
  final Map<String, double> dimensionScores;
  final List<String> strengths;
  final List<String> challenges;
  final String communicationText;
  final String emotionalDynamicText;
  final String valuesText;
  final String growthDynamicText;
  final List<Map<String, dynamic>> importantAspects;

  SynastryData({
    required this.moonScore,
    required this.mercuryScore,
    required this.venusMarsScore,
    required this.nodesScore,
    required this.saturnScore,
    required this.detailedAspects,
    required this.interpretation,
    this.dimensionScores = const {},
    this.strengths = const [],
    this.challenges = const [],
    this.communicationText = '',
    this.emotionalDynamicText = '',
    this.valuesText = '',
    this.growthDynamicText = '',
    this.importantAspects = const [],
  });

  double get overallScore => (moonScore + mercuryScore + venusMarsScore + nodesScore + saturnScore) / 5;

  double get romanceScore => dimensionScores['romance'] ?? dimensionScores['attraction'] ?? venusMarsScore;
  double get emotionalScore => dimensionScores['emotional'] ?? moonScore;
  double get communicationScore => dimensionScores['communication'] ?? mercuryScore;
  double get longTermScore => dimensionScores['long_term'] ?? dimensionScores['stability'] ?? saturnScore;
  double get marriageScore => dimensionScores['marriage'] ?? (saturnScore * 0.9 + moonScore * 0.1);
  double get friendshipScore => dimensionScores['friendship'] ?? (mercuryScore * 0.7 + moonScore * 0.3);
  double get chemistryScore => dimensionScores['chemistry'] ?? dimensionScores['attraction'] ?? venusMarsScore;
  double get spiritualScore => dimensionScores['spiritual'] ?? dimensionScores['growth'] ?? nodesScore;
  double get valuesScore => dimensionScores['values'] ?? 50.0;
  double get conflictScore => dimensionScores['conflict'] ?? 50.0;
  double get stabilityScore => dimensionScores['stability'] ?? saturnScore;
  double get overallDimensionScore => dimensionScores['overall'] ?? overallScore;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'moonScore': moonScore,
        'mercuryScore': mercuryScore,
        'venusMarsScore': venusMarsScore,
        'nodesScore': nodesScore,
        'saturnScore': saturnScore,
        'detailedAspects': detailedAspects.map((Aspect a) => a.toJson()).toList(),
        'interpretation': interpretation,
        'dimensionScores': dimensionScores,
        'strengths': strengths,
        'challenges': challenges,
        'communicationText': communicationText,
        'emotionalDynamicText': emotionalDynamicText,
        'valuesText': valuesText,
        'growthDynamicText': growthDynamicText,
      };

  factory SynastryData.fromJson(Map<String, dynamic> json) => SynastryData(
        moonScore: (json['moonScore'] as double),
        mercuryScore: (json['mercuryScore'] as double),
        venusMarsScore: (json['venusMarsScore'] as double),
        nodesScore: (json['nodesScore'] as double),
        saturnScore: (json['saturnScore'] as double),
        detailedAspects: (json['detailedAspects'] as List).map((a) => Aspect.fromJson(a as Map<String, dynamic>)).toList(),
        interpretation: json['interpretation'] as String,
        dimensionScores: json['dimensionScores'] != null
            ? Map<String, double>.from((json['dimensionScores'] as Map).map(
                (k, v) => MapEntry(k as String, (v as num).toDouble()),
              ))
            : const {},
        strengths: (json['strengths'] as List<dynamic>?)?.map((e) => e as String).toList() ?? [],
        challenges: (json['challenges'] as List<dynamic>?)?.map((e) => e as String).toList() ?? [],
        communicationText: json['communicationText'] as String? ?? '',
        emotionalDynamicText: json['emotionalDynamicText'] as String? ?? '',
        valuesText: json['valuesText'] as String? ?? '',
        growthDynamicText: json['growthDynamicText'] as String? ?? '',
      );

  factory SynastryData.fromCompatibilityResponse(Map<String, dynamic> json) {
    final dims = json['dimensions'] as Map<String, dynamic>? ?? {};
    final interp = json['interpretation'] as Map<String, dynamic>? ?? {};
    final synastry = json['western_synastry'] as Map<String, dynamic>? ?? {};

    final List<Aspect> aspects = [];
    final planetAspects = synastry['planet_aspects'] as List<dynamic>? ?? [];
    for (final a in planetAspects) {
      final String aspectType = a['aspect'] as String? ?? '';
      final String planetA = a['planet_a'] as String? ?? '';
      final String planetB = a['planet_b'] as String? ?? '';
      final double orb = (a['orb'] as num?)?.toDouble() ?? 0;
      final String signA = a['sign_a'] as String? ?? '';
      final String signB = a['sign_b'] as String? ?? '';

      final String description = _buildAspectDescription(aspectType, planetA, planetB, signA, signB, orb);

      aspects.add(Aspect(
        planet1: planetA,
        planet2: planetB,
        aspectType: _mapAspectType(aspectType),
        score: _aspectScore(aspectType, orb),
        description: description,
        planet1Sign: signA,
        planet2Sign: signB,
        orb: orb,
        isHarmonious: _isHarmonious(aspectType),
      ));
    }

    aspects.sort((a, b) => b.score.compareTo(a.score));

    final summary = interp['summary'] as String? ?? '';
    final communication = interp['communication'] as String? ?? '';
    final emotionalDynamic = interp['emotional_dynamic'] as String? ?? '';
    final valuesText = interp['values'] as String? ?? '';
    final growthDynamic = interp['growth_dynamic'] as String? ?? '';
    final strengths = (interp['strengths'] as List<dynamic>?)?.map((e) => e as String).toList() ?? [];
    final challenges = (interp['challenges'] as List<dynamic>?)?.map((e) => e as String).toList() ?? [];
    final importantAspects = (interp['important_aspects'] as List<dynamic>?)?.map((e) => e as Map<String, dynamic>).toList() ?? [];

    final Map<String, double> dimensionScores = {};
    dims.forEach((key, value) {
      dimensionScores[key] = (value as num).toDouble();
    });

    final double moonScore = dimensionScores['emotional'] ?? 50.0;
    final double mercuryScore = dimensionScores['communication'] ?? 50.0;
    final double venusMarsScore = dimensionScores['attraction'] ?? 50.0;
    final double nodesScore = dimensionScores['growth'] ?? 50.0;
    final double saturnScore = dimensionScores['stability'] ?? 50.0;

    return SynastryData(
      moonScore: moonScore,
      mercuryScore: mercuryScore,
      venusMarsScore: venusMarsScore,
      nodesScore: nodesScore,
      saturnScore: saturnScore,
      detailedAspects: aspects,
      interpretation: summary,
      dimensionScores: dimensionScores,
      strengths: strengths,
      challenges: challenges,
      communicationText: communication,
      emotionalDynamicText: emotionalDynamic,
      valuesText: valuesText,
      growthDynamicText: growthDynamic,
      importantAspects: importantAspects,
    );
  }

  static String _buildAspectDescription(String type, String planetA, String planetB, String signA, String signB, double orb) {
    final String orbText = orb > 0 ? ' (orb ${orb.toStringAsFixed(1)}°)' : '';
    final String signInfoA = signA.isNotEmpty ? ' in $signA' : '';
    final String signInfoB = signB.isNotEmpty ? ' in $signB' : '';
    return '$planetA$signInfoA ${_mapAspectType(type)} $planetB$signInfoB$orbText';
  }

  static String _mapAspectType(String backendType) {
    switch (backendType.toLowerCase()) {
      case 'conjunction': return 'Conjunction';
      case 'opposition': return 'Opposition';
      case 'trine': return 'Trine';
      case 'square': return 'Square';
      case 'sextile': return 'Sextile';
      default: return backendType;
    }
  }

  static bool _isHarmonious(String type) {
    switch (type.toLowerCase()) {
      case 'conjunction':
      case 'trine':
      case 'sextile':
        return true;
      case 'opposition':
      case 'square':
        return false;
      default:
        return true;
    }
  }

  static double _aspectScore(String type, double orb) {
    double base;
    switch (type.toLowerCase()) {
      case 'conjunction': base = 85; break;
      case 'trine': base = 80; break;
      case 'sextile': base = 70; break;
      case 'square': base = 45; break;
      case 'opposition': base = 40; break;
      default: base = 50;
    }
    return (base - orb * 2).clamp(20.0, 98.0);
  }

  SynastryData copyWith({
    double? moonScore,
    double? mercuryScore,
    double? venusMarsScore,
    double? nodesScore,
    double? saturnScore,
    List<Aspect>? detailedAspects,
    String? interpretation,
    Map<String, double>? dimensionScores,
    List<String>? strengths,
    List<String>? challenges,
    String? communicationText,
    String? emotionalDynamicText,
    String? valuesText,
    String? growthDynamicText,
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
        strengths: strengths ?? this.strengths,
        challenges: challenges ?? this.challenges,
        communicationText: communicationText ?? this.communicationText,
        emotionalDynamicText: emotionalDynamicText ?? this.emotionalDynamicText,
        valuesText: valuesText ?? this.valuesText,
        growthDynamicText: growthDynamicText ?? this.growthDynamicText,
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
