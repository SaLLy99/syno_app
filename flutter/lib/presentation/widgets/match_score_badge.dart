import 'package:flutter/material.dart';

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
        gradient: LinearGradient(
          colors: <Color>[
            _getColor().withOpacity(0.9),
            _getColor(),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        shape: BoxShape.circle,
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: _getColor().withOpacity(0.4),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${score.toStringAsFixed(0)}%',
              style: TextStyle(
                color: Colors.white,
                fontSize: size * 0.3,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (size > 50)
              Text(
                'Match',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: size * 0.12,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Color _getColor() {
    if (score >= 80) return const Color(0xFF60A5FA);
    if (score >= 65) return const Color(0xFF3B82F6);
    if (score >= 50) return const Color(0xFF2563EB);
    return const Color(0xFF1D4ED8);
  }
}
