import 'package:flutter/foundation.dart';
import 'package:syno_app/data/services/behavioral_ai_service.dart';
import 'package:syno_app/data/services/explanation_generator_service.dart';
import 'package:syno_app/data/services/synastry_calculator_service.dart';
import 'package:syno_app/data/services/weighting_engine_service.dart';
import 'package:syno_app/domain/entities/match.dart';
import 'package:syno_app/domain/entities/synastry_data.dart';
import 'package:syno_app/domain/entities/user.dart';
import 'package:syno_app/domain/entities/user_preferences.dart';
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

  Future<Match> calculateMatch(
    User currentUser,
    User potentialMatch, [
    DiscoverPreferences? preferences,
  ]) async {
    final SynastryData synastryData = await _synastryCalculator.calculateSynastry(currentUser, potentialMatch);
    final double synastryScore = synastryData.overallScore;
    
    final double behavioralScore = await _behavioralAI.calculateBehavioralScore(currentUser, potentialMatch);
    
    final double finalScore = _weightingEngine.calculateFinalScore(synastryScore, behavioralScore);
    
    final double weightedScore = _calculateWeightedScore(synastryData, preferences);
    
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
      weightedScore: weightedScore,
    );
  }

  double _calculateWeightedScore(SynastryData synastryData, DiscoverPreferences? preferences) {
    final Map<String, double> weights = preferences != null
        ? Map<String, double>.from(preferences.weights)
        : const {
            'romance': 50,
            'emotional': 50,
            'communication': 50,
            'long_term': 50,
            'marriage': 50,
            'friendship': 50,
            'chemistry': 50,
            'spiritual': 50,
          };

    double totalWeight = 0;
    double weightedSum = 0;

    weights.forEach((String key, double weight) {
      if (weight > 0) {
        double dimensionScore;
        switch (key) {
          case 'romance':
            dimensionScore = synastryData.romanceScore;
            break;
          case 'emotional':
            dimensionScore = synastryData.emotionalScore;
            break;
          case 'communication':
            dimensionScore = synastryData.communicationScore;
            break;
          case 'long_term':
            dimensionScore = synastryData.longTermScore;
            break;
          case 'marriage':
            dimensionScore = synastryData.marriageScore;
            break;
          case 'friendship':
            dimensionScore = synastryData.friendshipScore;
            break;
          case 'chemistry':
            dimensionScore = synastryData.chemistryScore;
            break;
          case 'spiritual':
            dimensionScore = synastryData.spiritualScore;
            break;
          default:
            dimensionScore = synastryData.overallScore;
        }
        weightedSum += dimensionScore * weight;
        totalWeight += weight;
      }
    });

    if (totalWeight == 0) return synastryData.overallScore;
    return (weightedSum / totalWeight).clamp(0.0, 100.0);
  }

  Future<List<Match>> findPotentialMatches(
    User currentUser,
    List<User> allUsers, [
    DiscoverPreferences? preferences,
  ]) async {
    final List<Match> matches = <Match>[];
    int skippedSelf = 0;
    int skippedPrefs = 0;
    int skippedMinCompat = 0;
    
    if (preferences != null) {
      debugPrint('[MatchingEngine] Prefs: age=${preferences.minAge}-${preferences.maxAge}, genders=${preferences.genders}, orientations=${preferences.orientations}, photosOnly=${preferences.photosOnly}, completeOnly=${preferences.completeProfilesOnly}, minHeight=${preferences.minHeight}, maxHeight=${preferences.maxHeight}');
    } else {
      debugPrint('[MatchingEngine] Prefs is NULL');
    }
    
    for (final User user in allUsers) {
      if (user.id == currentUser.id) { skippedSelf++; continue; }
      if (!_meetsPreferences(currentUser, user, preferences)) { skippedPrefs++; continue; }
      
      if (preferences != null && preferences.minCompatibility > 0) {
        final SynastryData tempSynastry = await _synastryCalculator.calculateSynastry(currentUser, user);
        if (tempSynastry.overallScore < preferences.minCompatibility) { skippedMinCompat++; continue; }
      }
      
      final Match match = await calculateMatch(currentUser, user, preferences);
      matches.add(match);
    }
    
    debugPrint('[MatchingEngine] ${allUsers.length} total, skipped self=$skippedSelf, prefs=$skippedPrefs, minCompat=$skippedMinCompat, matched=${matches.length}');
    
    matches.sort((Match a, Match b) => b.finalScore.compareTo(a.finalScore));
    
    return matches;
  }

  bool _meetsPreferences(User currentUser, User potentialMatch, DiscoverPreferences? preferences) {
    if (preferences == null) return true;

    if (potentialMatch.age != null) {
      if (potentialMatch.age! < preferences.minAge || potentialMatch.age! > preferences.maxAge) {
        debugPrint('[Prefs] ${potentialMatch.name} FAIL age=${potentialMatch.age} not in [${preferences.minAge}-${preferences.maxAge}]');
        return false;
      }
    }

    if (potentialMatch.sex != null && preferences.genders.isNotEmpty) {
      final bool genderMatch = preferences.genders.any(
        (String g) => g.toLowerCase() == potentialMatch.sex!.name.toLowerCase(),
      );
      if (!genderMatch) {
        debugPrint('[Prefs] ${potentialMatch.name} FAIL gender=${potentialMatch.sex!.name} not in $preferences.genders');
        return false;
      }
    }

    if (potentialMatch.orientation != null && preferences.orientations.isNotEmpty) {
      final bool orientationMatch = preferences.orientations.any(
        (String o) => o.toLowerCase() == potentialMatch.orientation!.name.toLowerCase(),
      );
      if (!orientationMatch) {
        debugPrint('[Prefs] ${potentialMatch.name} FAIL orientation=${potentialMatch.orientation!.name} not in $preferences.orientations');
        return false;
      }
    }

    if (preferences.photosOnly) {
      if (potentialMatch.photos.isEmpty) {
        debugPrint('[Prefs] ${potentialMatch.name} FAIL photosOnly but no photos');
        return false;
      }
    }

    if (preferences.completeProfilesOnly) {
      if (potentialMatch.photos.isEmpty || potentialMatch.bio == null || potentialMatch.bio!.isEmpty) {
        debugPrint('[Prefs] ${potentialMatch.name} FAIL completeProfilesOnly');
        return false;
      }
    }

    if (preferences.minHeight != null && potentialMatch.height != null) {
      if (potentialMatch.height! < preferences.minHeight!) {
        debugPrint('[Prefs] ${potentialMatch.name} FAIL height=${potentialMatch.height} < min=${preferences.minHeight}');
        return false;
      }
    }
    if (preferences.maxHeight != null && potentialMatch.height != null) {
      if (potentialMatch.height! > preferences.maxHeight!) {
        debugPrint('[Prefs] ${potentialMatch.name} FAIL height=${potentialMatch.height} > max=${preferences.maxHeight}');
        return false;
      }
    }

    return true;
  }

}
