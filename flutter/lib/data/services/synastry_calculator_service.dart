import 'dart:math';
import 'package:syno_app/domain/entities/natal_chart.dart';
import 'package:syno_app/domain/entities/synastry_data.dart';
import 'package:syno_app/domain/entities/user.dart';
import 'package:syno_app/data/services/natal_chart_calculator.dart';

class SynastryCalculatorService {
  final NatalChartCalculator _chartCalculator = NatalChartCalculator();

  static const Map<String, double> _aspectWeights = {
    'Sun-Sun': 1.0,
    'Sun-Moon': 1.2,
    'Moon-Moon': 1.3,
    'Mercury-Mercury': 1.1,
    'Venus-Venus': 1.2,
    'Mars-Mars': 1.0,
    'Sun-Venus': 0.9,
    'Moon-Venus': 1.1,
    'Venus-Mars': 1.3,
    'Moon-Mercury': 1.0,
    'Sun-Mars': 0.8,
    'Jupiter-Jupiter': 0.7,
    'Saturn-Saturn': 0.9,
    'Neptune-Neptune': 0.6,
    'Uranus-Uranus': 0.5,
  };

  static const List<List<String>> _synastryPairs = [
    ['Sun', 'Sun'],
    ['Sun', 'Moon'],
    ['Sun', 'Venus'],
    ['Sun', 'Mars'],
    ['Moon', 'Moon'],
    ['Moon', 'Mercury'],
    ['Moon', 'Venus'],
    ['Mercury', 'Mercury'],
    ['Venus', 'Venus'],
    ['Venus', 'Mars'],
    ['Mars', 'Mars'],
    ['Jupiter', 'Jupiter'],
    ['Saturn', 'Saturn'],
  ];

  Future<SynastryData> calculateSynastry(User user1, User user2) async {
    if (user1.birthDate == null || user2.birthDate == null) {
      return _fallbackSynastry(user1, user2);
    }

    final NatalChart chart1 = _chartCalculator.calculate(
      user1.birthDate!,
      user1.birthTime,
    );
    final NatalChart chart2 = _chartCalculator.calculate(
      user2.birthDate!,
      user2.birthTime,
    );

    final List<Aspect> aspects = _calculateAllAspects(chart1, chart2);

    final double moonScore = _calculateCategoryScore(aspects, ['Moon-Moon', 'Moon-Venus', 'Moon-Mercury']);
    final double mercuryScore = _calculateCategoryScore(aspects, ['Mercury-Mercury', 'Moon-Mercury']);
    final double venusMarsScore = _calculateCategoryScore(aspects, ['Venus-Venus', 'Venus-Mars', 'Sun-Venus']);
    final double nodesScore = _calculateKarmicScore(chart1, chart2);
    final double saturnScore = _calculateCategoryScore(aspects, ['Saturn-Saturn', 'Sun-Sun']);

    final Map<String, double> dimensionScores = _calculateDimensionScores(aspects, chart1, chart2);

    final String interpretation = _generateInterpretation(moonScore, mercuryScore, venusMarsScore, nodesScore, saturnScore);

    return SynastryData(
      moonScore: moonScore,
      mercuryScore: mercuryScore,
      venusMarsScore: venusMarsScore,
      nodesScore: nodesScore,
      saturnScore: saturnScore,
      detailedAspects: aspects,
      interpretation: interpretation,
      dimensionScores: dimensionScores,
    );
  }

  List<Aspect> _calculateAllAspects(NatalChart chart1, NatalChart chart2) {
    final List<Aspect> aspects = [];

    for (final pair in _synastryPairs) {
      final double? pos1 = chart1.planetPositions[pair[0]];
      final double? pos2 = chart2.planetPositions[pair[1]];

      if (pos1 == null || pos2 == null) continue;

      final Aspect? aspect = _calculateAspect(pair[0], pair[1], pos1, pos2);
      if (aspect != null) {
        aspects.add(aspect);
      }
    }

    aspects.sort((a, b) => b.score.compareTo(a.score));
    return aspects;
  }

  Aspect? _calculateAspect(String planet1, String planet2, double pos1, double pos2) {
    final double diff = (pos1 - pos2).abs();
    final double angle = diff > 180 ? 360 - diff : diff;

    String? aspectType;
    bool isHarmonious = true;
    double orb = 0;

    if (angle < 8) {
      aspectType = 'Conjunction';
      isHarmonious = true;
      orb = angle;
    } else if (angle >= 52 && angle <= 68) {
      aspectType = 'Sextile';
      isHarmonious = true;
      orb = (angle - 60).abs();
    } else if (angle >= 112 && angle <= 128) {
      aspectType = 'Square';
      isHarmonious = false;
      orb = (angle - 120).abs();
    } else if (angle >= 172 && angle <= 188) {
      aspectType = 'Trine';
      isHarmonious = true;
      orb = (angle - 180).abs();
    } else if (angle >= 160 && angle <= 190) {
      aspectType = 'Opposition';
      isHarmonious = false;
      orb = (angle - 180).abs();
    }

    if (aspectType == null) return null;

    final double weight = _aspectWeights['$planet1-$planet2'] ??
        _aspectWeights['$planet2-$planet1'] ??
        0.8;

    final double score = _aspectScore(aspectType, orb, weight);

    final String sign1 = NatalChart.signFromDegree(pos1);
    final String sign2 = NatalChart.signFromDegree(pos2);

    return Aspect(
      planet1: planet1,
      planet2: planet2,
      aspectType: aspectType,
      score: score,
      description: _getAspectDescription(planet1, planet2, aspectType, isHarmonious),
      planet1Sign: sign1,
      planet2Sign: sign2,
      orb: orb,
      isHarmonious: isHarmonious,
    );
  }

  double _aspectScore(String aspectType, double orb, double weight) {
    double baseScore;
    switch (aspectType) {
      case 'Conjunction':
        baseScore = 90 - orb * 2;
        break;
      case 'Trine':
        baseScore = 85 - orb * 2;
        break;
      case 'Sextile':
        baseScore = 75 - orb * 1.5;
        break;
      case 'Square':
        baseScore = 45 - orb * 2;
        break;
      case 'Opposition':
        baseScore = 40 - orb * 1.5;
        break;
      default:
        baseScore = 50;
    }

    return (baseScore * weight).clamp(20.0, 98.0);
  }

  double _calculateCategoryScore(List<Aspect> aspects, List<String> pairs) {
    double total = 0;
    int count = 0;

    for (final aspect in aspects) {
      final String key = '${aspect.planet1}-${aspect.planet2}';
      final String reverseKey = '${aspect.planet2}-${aspect.planet1}';

      if (pairs.contains(key) || pairs.contains(reverseKey)) {
        total += aspect.score;
        count++;
      }
    }

    if (count == 0) return 50.0;
    return (total / count).clamp(20.0, 98.0);
  }

  double _calculateKarmicScore(NatalChart chart1, NatalChart chart2) {
    double score = 50.0;

    final double sunDiff = (chart1.sun! - chart2.sun!).abs();
    final double normalizedSunDiff = sunDiff > 180 ? 360 - sunDiff : sunDiff;

    if (normalizedSunDiff < 15) {
      score += 15;
    } else if (normalizedSunDiff > 150 && normalizedSunDiff < 180) {
      score += 10;
    } else if (normalizedSunDiff > 60 && normalizedSunDiff < 90) {
      score += 5;
    }

    final double moonDiff = (chart1.moon! - chart2.moon!).abs();
    final double normalizedMoonDiff = moonDiff > 180 ? 360 - moonDiff : moonDiff;

    if (normalizedMoonDiff < 20) {
      score += 15;
    } else if (normalizedMoonDiff > 100 && normalizedMoonDiff < 140) {
      score += 8;
    }

    final double venusDiff = (chart1.venus! - chart2.venus!).abs();
    final double normalizedVenusDiff = venusDiff > 180 ? 360 - venusDiff : venusDiff;

    if (normalizedVenusDiff < 15) {
      score += 10;
    } else if (normalizedVenusDiff > 50 && normalizedVenusDiff < 70) {
      score += 8;
    }

    return score.clamp(20.0, 98.0);
  }

  Map<String, double> _calculateDimensionScores(List<Aspect> aspects, NatalChart chart1, NatalChart chart2) {
    final Map<String, double> scores = {};

    scores['romance'] = _calculateCategoryScore(aspects, ['Venus-Venus', 'Venus-Mars', 'Sun-Venus', 'Moon-Venus']);
    scores['emotional'] = _calculateCategoryScore(aspects, ['Moon-Moon', 'Moon-Venus', 'Sun-Moon']);
    scores['communication'] = _calculateCategoryScore(aspects, ['Mercury-Mercury', 'Moon-Mercury']);
    scores['long_term'] = _calculateCategoryScore(aspects, ['Saturn-Saturn', 'Sun-Sun', 'Jupiter-Jupiter']);
    scores['marriage'] = _calculateCategoryScore(aspects, ['Saturn-Saturn', 'Sun-Sun', 'Moon-Moon', 'Venus-Venus']);
    scores['friendship'] = _calculateCategoryScore(aspects, ['Mercury-Mercury', 'Moon-Mercury', 'Jupiter-Jupiter']);
    scores['chemistry'] = _calculateCategoryScore(aspects, ['Venus-Mars', 'Mars-Mars', 'Sun-Mars']);
    scores['spiritual'] = _calculateKarmicScore(chart1, chart2);

    return scores;
  }

  String _getAspectDescription(String planet1, String planet2, String aspectType, bool isHarmonious) {
    final String pair = '$planet1-$planet2';

    final Map<String, Map<String, String>> descriptions = {
      'Sun-Sun': {
        'Conjunction': 'Core identities align naturally',
        'Trine': 'Easy understanding of each other\'s essence',
        'Sextile': 'Supportive and encouraging dynamic',
        'Square': 'Creative tension that sparks growth',
        'Opposition': 'Magnetic attraction through contrast',
      },
      'Sun-Moon': {
        'Conjunction': 'Deep emotional and ego alignment',
        'Trine': 'Natural flow between emotions and identity',
        'Sextile': 'Harmonious support of each other\'s needs',
        'Square': 'Dynamic energy that challenges and excites',
        'Opposition': 'Complementary energies that complete each other',
      },
      'Moon-Moon': {
        'Conjunction': 'Exceptional emotional understanding',
        'Trine': 'Natural emotional harmony and comfort',
        'Sextile': 'Supportive emotional connection',
        'Square': 'Emotional challenges that deepen understanding',
        'Opposition': 'Opposite emotional needs create balance',
      },
      'Mercury-Mercury': {
        'Conjunction': 'Conversations flow naturally and effortlessly',
        'Trine': 'Easy mental rapport and understanding',
        'Sextile': 'Supportive communication style',
        'Square': 'Stimulating debates and intellectual growth',
        'Opposition': 'Different perspectives enrich discussions',
      },
      'Venus-Venus': {
        'Conjunction': 'Similar love languages and values',
        'Trine': 'Natural romantic harmony',
        'Sextile': 'Easy affection and appreciation',
        'Square': 'Passionate but challenging romantic dynamic',
        'Opposition': 'Magnetic attraction through differences',
      },
      'Venus-Mars': {
        'Conjunction': 'Strong romantic and physical chemistry',
        'Trine': 'Natural passion and attraction flow',
        'Sextile': 'Playful and exciting romantic energy',
        'Square': 'Intense but sometimes turbulent passion',
        'Opposition': 'Powerful magnetic attraction',
      },
      'Mars-Mars': {
        'Conjunction': 'Similar drive and ambition',
        'Trine': 'Cooperative and supportive energy',
        'Sextile': 'Encouraging and motivating dynamic',
        'Square': 'Competitive but energizing relationship',
        'Opposition': 'Complementary approaches to action',
      },
      'Jupiter-Jupiter': {
        'Conjunction': 'Shared optimism and growth values',
        'Trine': 'Mutual expansion and good fortune',
        'Sextile': 'Supportive philosophical alignment',
        'Square': 'Challenging each other to grow',
        'Opposition': 'Balanced perspectives on life',
      },
      'Saturn-Saturn': {
        'Conjunction': 'Shared values of responsibility and structure',
        'Trine': 'Stable and supportive long-term potential',
        'Sextile': 'Mutual respect for commitment',
        'Square': 'Challenging but building lasting foundations',
        'Opposition': 'Balancing structure with freedom',
      },
    };

    final Map<String, String> pairDescriptions = descriptions[pair] ?? {};
    final String key = isHarmonious ? aspectType : aspectType;
    return pairDescriptions[key] ?? '${aspectType} between $planet1 and $planet2';
  }

  String _generateInterpretation(double moon, double mercury, double venus, double nodes, double saturn) {
    final double avg = (moon + mercury + venus + nodes + saturn) / 5;

    if (avg >= 80) {
      return 'synastry.interpretation.high';
    } else if (avg >= 65) {
      return 'synastry.interpretation.good';
    } else if (avg >= 50) {
      return 'synastry.interpretation.medium';
    } else {
      return 'synastry.interpretation.low';
    }
  }

  SynastryData _fallbackSynastry(User user1, User user2) {
    final int seed = (user1.birthDate?.day ?? 0) +
        (user2.birthDate?.day ?? 0) +
        (user1.birthDate?.month ?? 0) * 10 +
        (user2.birthDate?.month ?? 0) * 10;
    final Random random = Random(seed);

    final double moonScore = 60 + random.nextDouble() * 35;
    final double mercuryScore = 55 + random.nextDouble() * 40;
    final double venusMarsScore = 65 + random.nextDouble() * 30;
    final double nodesScore = 50 + random.nextDouble() * 45;
    final double saturnScore = 55 + random.nextDouble() * 35;

    final List<Aspect> aspects = [
      Aspect(
        planet1: 'Moon',
        planet2: 'Moon',
        aspectType: _getAspectType(moonScore),
        score: moonScore,
        description: _getMoonDescription(moonScore),
      ),
      Aspect(
        planet1: 'Mercury',
        planet2: 'Mercury',
        aspectType: _getAspectType(mercuryScore),
        score: mercuryScore,
        description: _getMercuryDescription(mercuryScore),
      ),
      Aspect(
        planet1: 'Venus',
        planet2: 'Mars',
        aspectType: _getAspectType(venusMarsScore),
        score: venusMarsScore,
        description: _getVenusMarsDescription(venusMarsScore),
      ),
      Aspect(
        planet1: 'North Node',
        planet2: 'South Node',
        aspectType: _getAspectType(nodesScore),
        score: nodesScore,
        description: _getNodesDescription(nodesScore),
      ),
      Aspect(
        planet1: 'Saturn',
        planet2: 'Saturn',
        aspectType: _getAspectType(saturnScore),
        score: saturnScore,
        description: _getSaturnDescription(saturnScore),
      ),
    ];

    final String interpretation = _generateInterpretation(moonScore, mercuryScore, venusMarsScore, nodesScore, saturnScore);

    return SynastryData(
      moonScore: moonScore,
      mercuryScore: mercuryScore,
      venusMarsScore: venusMarsScore,
      nodesScore: nodesScore,
      saturnScore: saturnScore,
      detailedAspects: aspects,
      interpretation: interpretation,
    );
  }

  String _getAspectType(double score) {
    if (score >= 85) return 'Trine';
    if (score >= 70) return 'Sextile';
    if (score >= 55) return 'Conjunction';
    if (score >= 40) return 'Square';
    return 'Opposition';
  }

  String _getMoonDescription(double score) {
    if (score >= 80) return 'synastry.moon.high';
    if (score >= 65) return 'synastry.moon.good';
    if (score >= 50) return 'synastry.moon.medium';
    return 'synastry.moon.low';
  }

  String _getMercuryDescription(double score) {
    if (score >= 80) return 'synastry.mercury.high';
    if (score >= 65) return 'synastry.mercury.good';
    if (score >= 50) return 'synastry.mercury.medium';
    return 'synastry.mercury.low';
  }

  String _getVenusMarsDescription(double score) {
    if (score >= 80) return 'synastry.venus_mars.high';
    if (score >= 65) return 'synastry.venus_mars.good';
    if (score >= 50) return 'synastry.venus_mars.medium';
    return 'synastry.venus_mars.low';
  }

  String _getNodesDescription(double score) {
    if (score >= 80) return 'synastry.nodes.high';
    if (score >= 65) return 'synastry.nodes.good';
    if (score >= 50) return 'synastry.nodes.medium';
    return 'synastry.nodes.low';
  }

  String _getSaturnDescription(double score) {
    if (score >= 80) return 'synastry.saturn.high';
    if (score >= 65) return 'synastry.saturn.good';
    if (score >= 50) return 'synastry.saturn.medium';
    return 'synastry.saturn.low';
  }
}
