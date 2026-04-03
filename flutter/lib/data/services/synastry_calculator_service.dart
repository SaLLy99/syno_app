import 'dart:math';
import 'package:syno_app/domain/entities/synastry_data.dart';
import 'package:syno_app/domain/entities/user.dart';

class SynastryCalculatorService {
  Future<SynastryData> calculateSynastry(User user1, User user2) async {
    await Future.delayed(const Duration(milliseconds: 100));
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
    
    final List<Aspect> aspects = <Aspect>[
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
}
