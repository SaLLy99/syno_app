import 'package:flutter/material.dart';
import 'package:syno_app/theme.dart';

class CompatibilityMeter extends StatelessWidget {
  final String label;
  final double score;
  final String? emoji;
  final double height;
  final Color? barColor;

  const CompatibilityMeter({
    super.key,
    required this.label,
    required this.score,
    this.emoji,
    this.height = 8,
    this.barColor,
  });

  @override
  Widget build(BuildContext context) {
    final Color effectiveBarColor = barColor ?? _getBarColor();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  if (emoji != null) ...[
                    Text(emoji!, style: const TextStyle(fontSize: 14)),
                    const SizedBox(width: 6),
                  ],
                  Text(
                    label,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withOpacity(0.85),
                    ),
                  ),
                ],
              ),
              Text(
                '${score.toInt()}%',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: effectiveBarColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            child: TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeOutCubic,
              tween: Tween(begin: 0, end: score / 100),
              builder: (context, value, _) => LinearProgressIndicator(
                value: value,
                backgroundColor: Colors.white.withOpacity(0.12),
                valueColor: AlwaysStoppedAnimation<Color>(effectiveBarColor),
                minHeight: height,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getBarColor() {
    if (score >= 85) return const Color(0xFF60A5FA);
    if (score >= 70) return const Color(0xFF3B82F6);
    if (score >= 55) return const Color(0xFF2563EB);
    return const Color(0xFF1D4ED8);
  }
}
