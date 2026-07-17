import 'package:flutter/material.dart';
import 'package:syno_app/theme.dart';

enum MatchBadgeType {
  bestMatch,
  marriagePotential,
  soulConnection,
  greatCommunication,
  strongChemistry,
  growthPartner,
  greatFriendship,
  rareMatch,
}

class MatchBadge extends StatelessWidget {
  final MatchBadgeType type;
  final double size;

  const MatchBadge({
    super.key,
    required this.type,
    this.size = 28,
  });

  @override
  Widget build(BuildContext context) {
    final config = _getConfig();
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: size * 0.35,
        vertical: size * 0.15,
      ),
      decoration: BoxDecoration(
        gradient: config.gradient,
        borderRadius: BorderRadius.circular(size * 0.4),
        boxShadow: [
          BoxShadow(
            color: config.shadowColor.withOpacity(0.4),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            config.emoji,
            style: TextStyle(fontSize: size * 0.5),
          ),
          SizedBox(width: size * 0.15),
          Text(
            config.label,
            style: TextStyle(
              color: Colors.white,
              fontSize: size * 0.35,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  _BadgeConfig _getConfig() {
    switch (type) {
      case MatchBadgeType.bestMatch:
        return _BadgeConfig(
          emoji: '🌟',
          label: 'Best Match',
          gradient: const LinearGradient(
            colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
          ),
          shadowColor: const Color(0xFFFFD700),
        );
      case MatchBadgeType.marriagePotential:
        return _BadgeConfig(
          emoji: '💍',
          label: 'Marriage Potential',
          gradient: const LinearGradient(
            colors: [CosmicColors.cosmicPurple, CosmicColors.nebulaPurple],
          ),
          shadowColor: CosmicColors.cosmicPurple,
        );
      case MatchBadgeType.soulConnection:
        return _BadgeConfig(
          emoji: '❤️',
          label: 'Soul Connection',
          gradient: const LinearGradient(
            colors: [CosmicColors.cosmicPink, Color(0xFFFF6B9D)],
          ),
          shadowColor: CosmicColors.cosmicPink,
        );
      case MatchBadgeType.greatCommunication:
        return _BadgeConfig(
          emoji: '🧠',
          label: 'Great Communication',
          gradient: const LinearGradient(
            colors: [CosmicColors.cosmicBlue, Color(0xFF60A5FA)],
          ),
          shadowColor: CosmicColors.cosmicBlue,
        );
      case MatchBadgeType.strongChemistry:
        return _BadgeConfig(
          emoji: '🔥',
          label: 'Strong Chemistry',
          gradient: const LinearGradient(
            colors: [Color(0xFFEF4444), CosmicColors.sunsetOrange],
          ),
          shadowColor: const Color(0xFFEF4444),
        );
      case MatchBadgeType.growthPartner:
        return _BadgeConfig(
          emoji: '🌱',
          label: 'Growth Partner',
          gradient: const LinearGradient(
            colors: [Color(0xFF10B981), Color(0xFF34D399)],
          ),
          shadowColor: const Color(0xFF10B981),
        );
      case MatchBadgeType.greatFriendship:
        return _BadgeConfig(
          emoji: '🤝',
          label: 'Great Friendship',
          gradient: const LinearGradient(
            colors: [Color(0xFF14B8A6), Color(0xFF5EEAD4)],
          ),
          shadowColor: const Color(0xFF14B8A6),
        );
      case MatchBadgeType.rareMatch:
        return _BadgeConfig(
          emoji: '✨',
          label: 'Rare Match',
          gradient: const LinearGradient(
            colors: [Color(0xFF8B5CF6), Color(0xFFEC4899), Color(0xFF3B82F6)],
          ),
          shadowColor: const Color(0xFF8B5CF6),
        );
    }
  }

  static List<MatchBadgeType> getBadgesForScore(double score, Map<String, double> dimensions) {
    final List<MatchBadgeType> badges = [];

    if (score >= 95) {
      badges.add(MatchBadgeType.bestMatch);
      badges.add(MatchBadgeType.rareMatch);
    } else if (score >= 85) {
      badges.add(MatchBadgeType.bestMatch);
    }

    if ((dimensions['long_term'] ?? 0) >= 85 && (dimensions['marriage'] ?? 0) >= 75) {
      badges.add(MatchBadgeType.marriagePotential);
    }

    if ((dimensions['emotional'] ?? 0) >= 80) {
      badges.add(MatchBadgeType.soulConnection);
    }

    if ((dimensions['communication'] ?? 0) >= 80) {
      badges.add(MatchBadgeType.greatCommunication);
    }

    if ((dimensions['chemistry'] ?? 0) >= 80) {
      badges.add(MatchBadgeType.strongChemistry);
    }

    if ((dimensions['spiritual'] ?? 0) >= 75 && (dimensions['emotional'] ?? 0) >= 70) {
      badges.add(MatchBadgeType.growthPartner);
    }

    if ((dimensions['friendship'] ?? 0) >= 80) {
      badges.add(MatchBadgeType.greatFriendship);
    }

    return badges.take(3).toList();
  }
}

class _BadgeConfig {
  final String emoji;
  final String label;
  final Gradient gradient;
  final Color shadowColor;

  _BadgeConfig({
    required this.emoji,
    required this.label,
    required this.gradient,
    required this.shadowColor,
  });
}
