import 'package:flutter/material.dart';
import 'package:syno_app/theme.dart';

class MatchScoreBadge extends StatelessWidget {
  final double score;
  final double size;

  const MatchScoreBadge({
    super.key,
    required this.score,
    this.size = 60,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: _getGradient(),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: _getColor().withOpacity(0.4), // Cannot be const as _getColor() is dynamic
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Text(
          score.toStringAsFixed(0),
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Color _getColor() {
    if (score >= 80) return CosmicColors.cosmicPurple;
    if (score >= 65) return CosmicColors.cosmicPink;
    if (score >= 50) return CosmicColors.cosmicBlue;
    return Colors.grey;
  }

  LinearGradient _getGradient() {
    if (score >= 80) {
      return const LinearGradient(
        colors: [CosmicColors.cosmicPurple, CosmicColors.nebulaPurple],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    } else if (score >= 65) {
      return const LinearGradient(
        colors: [CosmicColors.cosmicPink, CosmicColors.sunsetOrange],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    } else if (score >= 50) {
      return const LinearGradient(
        colors: [CosmicColors.cosmicBlue, CosmicColors.cosmicPurple],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    }
    return const LinearGradient(
      colors: [Colors.grey, Colors.blueGrey],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }
}
