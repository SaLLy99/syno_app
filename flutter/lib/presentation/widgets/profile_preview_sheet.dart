import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:syno_app/domain/entities/match.dart';
import 'package:syno_app/domain/entities/user.dart';
import 'package:syno_app/presentation/providers/auth_providers.dart';
import 'package:syno_app/presentation/widgets/match_score_badge.dart';
import 'package:syno_app/theme.dart';

class ProfilePreviewSheet extends ConsumerWidget {
  final Match match;

  ProfilePreviewSheet({super.key, required this.match});

  static void show(BuildContext context, Match match) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ProfilePreviewSheet(match: match),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final User user = match.matchedUser;
    final double screenHeight = MediaQuery.of(context).size.height;

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Container(
          height: screenHeight * 0.75,
          decoration: const BoxDecoration(
            color: Color(0xFF1A0B2E),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  children: [
                    _buildPhotoCarousel(user, ref),
                    const SizedBox(height: 16),
                    _buildBasicInfo(user),
                    const SizedBox(height: 16),
                    if (user.bio != null && user.bio!.isNotEmpty) _buildBio(user),
                    if (user.bio != null && user.bio!.isNotEmpty)
                      const SizedBox(height: 16),
                    _buildInterests(user),
                    const SizedBox(height: 16),
                    _buildBirthChartSummary(user),
                    const SizedBox(height: 16),
                    _buildCompatibility(),
                    const SizedBox(height: 24),
                    _buildViewFullProfileButton(context),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPhotoCarousel(User user, WidgetRef ref) {
    return SizedBox(
      height: 200,
      child: user.photos.isNotEmpty
          ? ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: user.photos.length.clamp(0, 6),
              itemBuilder: (context, index) {
                return Container(
                  width: 150,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    image: DecorationImage(
                      image: NetworkImage(user.photos[index].getFullUrl(ref.read(backendUrlProvider))),
                      fit: BoxFit.cover,
                    ),
                  ),
                );
              },
            )
          : Container(
              decoration: BoxDecoration(
                color: CosmicColors.cosmicPurple.withOpacity(0.3),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: const Center(
                child: Icon(Icons.person, size: 64, color: Colors.white38),
              ),
            ),
    );
  }

  Widget _buildBasicInfo(User user) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${user.name}, ${user.age}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (user.location != null)
                Text(
                  user.location!.localizedDisplayName,
                  style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 14),
                ),
              if (user.professions.isNotEmpty)
                Text(
                  user.professions.first.name,
                  style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13),
                ),
            ],
          ),
        ),
        MatchScoreBadge(score: match.finalScore, size: 64),
      ],
    );
  }

  Widget _buildBio(User user) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Text(
        user.bio!,
        style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 14, height: 1.5),
      ),
    );
  }

  Widget _buildInterests(User user) {
    if (user.hobbies.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: user.hobbies.map((h) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: CosmicColors.cosmicPurple.withOpacity(0.2),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: CosmicColors.cosmicPurple.withOpacity(0.3)),
          ),
          child: Text(
            h.name,
            style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 13),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildBirthChartSummary(User user) {
    final String? zodiac = user.zodiacSign;
    if (zodiac == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            CosmicColors.cosmicPurple.withOpacity(0.2),
            CosmicColors.cosmicPink.withOpacity(0.2),
          ],
        ),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: CosmicColors.cosmicPurple.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            _getZodiacEmoji(zodiac),
            style: const TextStyle(fontSize: 28),
          ),
          const SizedBox(width: 12),
          Text(
            zodiac,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompatibility() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _compatColumn('Emotional', match.synastryData.emotionalScore, '🌙'),
          _compatColumn('Communication', match.synastryData.communicationScore, '🧠'),
          _compatColumn('Romance', match.synastryData.romanceScore, '❤️'),
        ],
      ),
    );
  }

  Widget _compatColumn(String label, double score, String emoji) {
    return Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 20)),
        const SizedBox(height: 4),
        Text(
          '${score.toInt()}%',
          style: TextStyle(
            color: score >= 80
                ? CosmicColors.cosmicPurple
                : score >= 60
                    ? CosmicColors.cosmicPink
                    : Colors.white70,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        Text(
          label,
          style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 10),
        ),
      ],
    );
  }

  Widget _buildViewFullProfileButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: CosmicColors.cosmicPurple,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onPressed: () {
          Navigator.pop(context);
          context.push('/match-details', extra: match);
        },
        child: const Text(
          'View Full Profile',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  String _getZodiacEmoji(String sign) {
    const emojis = {
      'Aries': '♈', 'Taurus': '♉', 'Gemini': '♊', 'Cancer': '♋',
      'Leo': '♌', 'Virgo': '♍', 'Libra': '♎', 'Scorpio': '♏',
      'Sagittarius': '♐', 'Capricorn': '♑', 'Aquarius': '♒', 'Pisces': '♓',
    };
    return emojis[sign] ?? '⭐';
  }
}
