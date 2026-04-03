import 'dart:math';
import 'package:easy_localization/easy_localization.dart';
import 'package:syno_app/domain/entities/synastry_data.dart';

class ExplanationGeneratorService {
  List<String> generateTopReasons(SynastryData synastryData, List<String> behavioralReasons) {
    final List<String> synastryReasons = <String>[];
    
    if (synastryData.moonScore >= 75) {
      synastryReasons.add('explanation.top_reasons.moon_high'.tr());
    } else if (synastryData.moonScore >= 60) {
      synastryReasons.add('explanation.top_reasons.moon_good'.tr());
    }
    
    if (synastryData.mercuryScore >= 75) {
      synastryReasons.add('explanation.top_reasons.mercury_high'.tr());
    } else if (synastryData.mercuryScore >= 60) {
      synastryReasons.add('explanation.top_reasons.mercury_good'.tr());
    }
    
    if (synastryData.venusMarsScore >= 75) {
      synastryReasons.add('explanation.top_reasons.venus_mars_high'.tr());
    } else if (synastryData.venusMarsScore >= 60) {
      synastryReasons.add('explanation.top_reasons.venus_mars_good'.tr());
    }
    
    if (synastryData.nodesScore >= 75) {
      synastryReasons.add('explanation.top_reasons.nodes_high'.tr());
    } else if (synastryData.nodesScore >= 60) {
      synastryReasons.add('explanation.top_reasons.nodes_good'.tr());
    }
    
    if (synastryData.saturnScore >= 75) {
      synastryReasons.add('explanation.top_reasons.saturn_high'.tr());
    } else if (synastryData.saturnScore >= 60) {
      synastryReasons.add('explanation.top_reasons.saturn_good'.tr());
    }
    
    final List<String> allReasons = <String>[...synastryReasons, ...behavioralReasons];
    return allReasons.take(5).toList();
  }
  
  String generateCosmicInsight(double finalScore, SynastryData synastryData) {
    List<String> insights;
    String insightCategoryKey;
    
    if (finalScore >= 85) {
      insightCategoryKey = 'explanation.cosmic_insight.high';
    } else if (finalScore >= 70) {
      insightCategoryKey = 'explanation.cosmic_insight.good';
    } else if (finalScore >= 55) {
      insightCategoryKey = 'explanation.cosmic_insight.medium';
    } else {
      insightCategoryKey = 'explanation.cosmic_insight.low';
    }

    // easy_localization returns a List<dynamic>, so we cast it.
    insights = List<String>.from(tr(insightCategoryKey) as Iterable);
    
    final double highestScore = <double>[
      synastryData.moonScore,
      synastryData.mercuryScore,
      synastryData.venusMarsScore,
      synastryData.nodesScore,
      synastryData.saturnScore,
    ].reduce(max);
    
    if (highestScore == synastryData.nodesScore && synastryData.nodesScore >= 75) {
      insights.add('explanation.cosmic_insight.nodes_special'.tr());
    } else if (highestScore == synastryData.venusMarsScore && synastryData.venusMarsScore >= 80) {
      insights.add('explanation.cosmic_insight.venus_mars_special'.tr());
    }
    
    final Random random = Random(finalScore.toInt());
    return insights[random.nextInt(insights.length)];
  }
  
  List<String> generateSynastryHighlights(SynastryData synastryData) {
    final List<String> highlights = <String>[];
    
    final Map<String, dynamic> scores = <String, dynamic>{
      'explanation.highlights.emotional_connection'.tr(): synastryData.moonScore,
      'explanation.highlights.communication'.tr(): synastryData.mercuryScore,
      'explanation.highlights.romantic_chemistry'.tr(): synastryData.venusMarsScore,
      'explanation.highlights.soul_bond'.tr(): synastryData.nodesScore,
      'explanation.highlights.long_term_potential'.tr(): synastryData.saturnScore,
    };
    
    final List<MapEntry<String, dynamic>> sortedScores = scores.entries.toList()..sort((MapEntry<String, dynamic> a, MapEntry<String, dynamic> b) => b.value.compareTo(a.value));
    
    for (final MapEntry<String, dynamic> entry in sortedScores.take(3)) {
      highlights.add('${entry.key}: ${entry.value.toStringAsFixed(0)}%');
    }
    
    return highlights;
  }
}
