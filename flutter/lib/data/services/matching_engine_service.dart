import 'package:syno_app/data/services/behavioral_ai_service.dart';
import 'package:syno_app/data/services/explanation_generator_service.dart';
import 'package:syno_app/data/services/synastry_calculator_service.dart';
import 'package:syno_app/data/services/weighting_engine_service.dart';
import 'package:syno_app/domain/entities/match.dart';
import 'package:syno_app/domain/entities/synastry_data.dart';
import 'package:syno_app/domain/entities/user.dart';
import 'package:uuid/uuid.dart';

class MatchingEngineService {
  final SynastryCalculatorService _synastryCalculator;
  final BehavioralAIService _behavioralAI;
  final WeightingEngineService _weightingEngine;
  final ExplanationGeneratorService _explanationGenerator;
  final Uuid _uuid = const Uuid();

  MatchingEngineService({
    SynastryCalculatorService? synastryCalculator,
    BehavioralAIService? behavioralAI,
    WeightingEngineService? weightingEngine,
    ExplanationGeneratorService? explanationGenerator,
  })  : _synastryCalculator = synastryCalculator ?? SynastryCalculatorService(),
        _behavioralAI = behavioralAI ?? BehavioralAIService(),
        _weightingEngine = weightingEngine ?? WeightingEngineService(),
        _explanationGenerator = explanationGenerator ?? ExplanationGeneratorService();

  Future<Match> calculateMatch(User currentUser, User potentialMatch) async {
    final SynastryData synastryData = await _synastryCalculator.calculateSynastry(currentUser, potentialMatch);
    final double synastryScore = synastryData.overallScore;
    
    final double behavioralScore = await _behavioralAI.calculateBehavioralScore(currentUser, potentialMatch);
    
    final double finalScore = _weightingEngine.calculateFinalScore(synastryScore, behavioralScore);
    
    final List<String> behavioralReasons = _behavioralAI.generateBehavioralReasons(currentUser, potentialMatch, behavioralScore);
    final List<String> topReasons = _explanationGenerator.generateTopReasons(synastryData, behavioralReasons);
    
    final String cosmicInsight = _explanationGenerator.generateCosmicInsight(finalScore, synastryData);
    
    return Match(
      id: _uuid.v4(),
      userId: currentUser.id.toString(),
      matchedUserId: potentialMatch.id.toString(),
      matchedUser: potentialMatch,
      finalScore: finalScore,
      synastryScore: synastryScore,
      behavioralScore: behavioralScore,
      topReasons: topReasons,
      cosmicInsight: cosmicInsight,
      synastryData: synastryData,
      status: MatchStatus.pending,
      createdAt: DateTime.now(),
    );
  }

  Future<List<Match>> findPotentialMatches(User currentUser, List<User> allUsers) async {
    final List<Match> matches = <Match>[];
    
    for (final User user in allUsers) {
      if (user.id == currentUser.id) continue;
      if (!_meetsPreferences(currentUser, user)) continue;
      
      final Match match = await calculateMatch(currentUser, user);
      matches.add(match);
    }
    
    matches.sort((Match a, Match b) => b.finalScore.compareTo(a.finalScore));
    
    return matches;
  }

  bool _meetsPreferences(User currentUser, User potentialMatch) {
    // final UserPreferences prefs = currentUser.preferences;
    
    // if (potentialMatch.age < prefs.minAge || potentialMatch.age > prefs.maxAge) {
    //   return false;
    // }
    
    return true;
  }
}

