class WeightingEngineService {
  final double synastryWeight;
  final double behavioralWeight;

  WeightingEngineService({
    this.synastryWeight = 0.6,
    this.behavioralWeight = 0.4,
  }) : assert(synastryWeight + behavioralWeight == 1.0, 'Weights must sum to 1.0');

  double calculateFinalScore(double synastryScore, double behavioralScore) {
    final double weighted = (synastryScore * synastryWeight) + (behavioralScore * behavioralWeight);
    return weighted.clamp(0.0, 100.0);
  }

  String getScoreCategory(double score) {
    if (score >= 85) return 'weighting.category.exceptional';
    if (score >= 75) return 'weighting.category.great';
    if (score >= 65) return 'weighting.category.strong';
    if (score >= 55) return 'weighting.category.good';
    if (score >= 45) return 'weighting.category.moderate';
    return 'weighting.category.challenging';
  }

  String getScoreCategoryDescription(double score) {
    if (score >= 85) return 'weighting.description.exceptional';
    if (score >= 75) return 'weighting.description.great';
    if (score >= 65) return 'weighting.description.strong';
    if (score >= 55) return 'weighting.description.good';
    if (score >= 45) return 'weighting.description.moderate';
    return 'weighting.description.challenging';
  }
}
