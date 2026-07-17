import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:go_router/go_router.dart';
import 'package:syno_app/domain/entities/match.dart';
import 'package:syno_app/domain/entities/user.dart';
import 'package:syno_app/theme.dart';

class MatchFoundDialog extends StatelessWidget {
  final User matchedUser;
  final Match match;
  final String baseUrl;

  const MatchFoundDialog({
    super.key,
    required this.matchedUser,
    required this.match,
    this.baseUrl = '',
  });

  static void show(BuildContext context, {required User matchedUser, required Match match, String baseUrl = ''}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) => MatchFoundDialog(matchedUser: matchedUser, match: match, baseUrl: baseUrl),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1A0B2E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const SizedBox(height: 16),
            Text(
              'match_found.title'.tr(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'match_found.subtitle'.tr(),
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Stack(
              alignment: Alignment.center,
              children: <Widget>[
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: CosmicColors.cosmicGradient,
                    boxShadow: [BoxShadow(color: CosmicColors.cosmicPurple.withOpacity(0.5), blurRadius: 20)],
                  ),
                ),
                ClipOval(
                  child: SizedBox(
                    width: 100,
                    height: 100,
                    child: matchedUser.photos.isNotEmpty
                        ? Image.network(
                            matchedUser.photos.first.getFullUrl(baseUrl),
                            fit: BoxFit.cover,
                            errorBuilder: (BuildContext context, Object error, StackTrace? stackTrace) =>
                                const Icon(Icons.person, size: 50, color: Colors.white),
                          )
                        : const Icon(Icons.person, size: 50, color: Colors.white),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              matchedUser.name ?? 'Unknown',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (matchedUser.zodiacSign != null) ...<Widget>[
              const SizedBox(height: 4),
              Text(
                matchedUser.zodiacSign!,
                style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 14),
              ),
            ],
            const SizedBox(height: 24),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.white38),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      'match_found.keep_swiping'.tr(),
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      context.push('/chat', extra: match);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: CosmicColors.cosmicPink,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      'match_found.send_message'.tr(),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
