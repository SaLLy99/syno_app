import 'package:syno_app/domain/entities/user.dart';

class BehavioralAIService {
  Future<double> calculateBehavioralScore(User user1, User user2) async {
    await Future.delayed(const Duration(milliseconds: 50));
    
    double score = 50.0;
    
    final Map<String, dynamic> traits1 = user1.personalityTraits;
    final Map<String, dynamic> traits2 = user2.personalityTraits;
    
    if (traits1.isNotEmpty && traits2.isNotEmpty) {
      score += _compareTraits(traits1, traits2, 'openness') * 5;
      score += _compareTraits(traits1, traits2, 'conscientiousness') * 4;
      score += _compareTraits(traits1, traits2, 'extraversion') * 3;
      score += _compareTraits(traits1, traits2, 'agreeableness') * 6;
      score += _compareTraits(traits1, traits2, 'emotionalStability') * 5;
      score += _compareTraits(traits1, traits2, 'adventurous') * 4;
      score += _compareTraits(traits1, traits2, 'romantic') * 5;
      score += _compareTraits(traits1, traits2, 'intellectual') * 3;
    } else {
      final int seed = user1.id.hashCode ^ user2.id.hashCode;
      score = 45.0 + ((seed.abs() % 400) / 10.0);
    }
    
    score = score.clamp(40.0, 95.0);
    
    return score;
  }
  
  double _compareTraits(Map<String, dynamic> traits1, Map<String, dynamic> traits2, String traitKey) {
    if (!traits1.containsKey(traitKey) || !traits2.containsKey(traitKey)) {
      return 0.0;
    }
    
    final double value1 = (traits1[traitKey] as num).toDouble();
    final double value2 = (traits2[traitKey] as num).toDouble();
    
    final double difference = (value1 - value2).abs();
    
    if (traitKey == 'extraversion') {
      return difference < 20 ? 2.0 : (difference < 40 ? 0.0 : -1.0);
    }
    
    if (traitKey == 'agreeableness' || traitKey == 'emotionalStability') {
      return difference < 15 ? 2.5 : (difference < 30 ? 1.0 : 0.0);
    }
    
    return difference < 20 ? 2.0 : (difference < 40 ? 1.0 : 0.0);
  }
  
  List<String> generateBehavioralReasons(User user1, User user2, double score) {
    final List<String> reasons = <String>[];
    final Map<String, dynamic> traits1 = user1.personalityTraits;
    final Map<String, dynamic> traits2 = user2.personalityTraits;
    
    if (_areTraitsSimilar(traits1, traits2, 'adventurous')) {
      reasons.add('🌟 Both love adventure and trying new experiences');
    }
    
    if (_areTraitsSimilar(traits1, traits2, 'romantic')) {
      reasons.add('💕 Shared romantic nature and expression of affection');
    }
    
    if (_areTraitsSimilar(traits1, traits2, 'intellectual')) {
      reasons.add('🧠 Strong intellectual connection and curiosity');
    }
    
    if (_areTraitsSimilar(traits1, traits2, 'agreeableness')) {
      reasons.add('🤝 Compatible communication styles and conflict resolution');
    }
    
    if (_areTraitsSimilar(traits1, traits2, 'emotionalStability')) {
      reasons.add('🌈 Balanced emotional maturity and stability');
    }
    
    if (_areTraitsSimilar(traits1, traits2, 'openness')) {
      reasons.add('🎨 Shared appreciation for creativity and new ideas');
    }
    
    if (_areTraitsComplementary(traits1, traits2, 'extraversion')) {
      reasons.add('⚖️ Complementary social energy levels');
    }
    
    if (_areTraitsSimilar(traits1, traits2, 'conscientiousness')) {
      reasons.add('📋 Similar approaches to organization and responsibility');
    }
    
    return reasons.take(3).toList();
  }
  
  bool _areTraitsSimilar(Map<String, dynamic> traits1, Map<String, dynamic> traits2, String key) {
    if (!traits1.containsKey(key) || !traits2.containsKey(key)) return false;
    final num diff = ((traits1[key] as num) - (traits2[key] as num)).abs();
    return diff < 20;
  }
  
  bool _areTraitsComplementary(Map<String, dynamic> traits1, Map<String, dynamic> traits2, String key) {
    if (!traits1.containsKey(key) || !traits2.containsKey(key)) return false;
    final num diff = ((traits1[key] as num) - (traits2[key] as num)).abs();
    return diff >= 20 && diff <= 40;
  }
}
