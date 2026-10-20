import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// Shared language for how SYNO presents a match score.
///
/// Rules:
///  * one headline number everywhere (the natal-chart score);
///  * the number is always shown with its parts (Chart / Behaviour / Profile)
///    and a "no data yet" state instead of a placeholder;
///  * a band label tells the user what the number means;
///  * the aspects driving the score are always listed.
String scoreBandLabelKey(double score) {
  if (score >= 85) return 'match_details.match_info.exceptional_match'.tr();
  if (score >= 70) return 'match_details.match_info.strong_connection'.tr();
  if (score >= 55) return 'match_details.match_info.good_potential'.tr();
  return 'match_details.match_info.growing_together'.tr();
}

Color scoreBandColor(double score) {
  if (score >= 85) return const Color(0xFF10B981);
  if (score >= 70) return const Color(0xFF3B82F6);
  if (score >= 55) return const Color(0xFFF59E0B);
  return const Color(0xFFEF4444);
}

const Map<String, String> _partLabelKeys = <String, String>{
  'chart': 'score.part.chart',
  'behavior': 'score.part.behavior',
  'profile': 'score.part.profile',
};

const Map<String, String> _aspectKeys = <String, String>{
  'conjunction': 'score.aspect.conjunction',
  'opposition': 'score.aspect.opposition',
  'trine': 'score.aspect.trine',
  'square': 'score.aspect.square',
  'sextile': 'score.aspect.sextile',
  'quincunx': 'score.aspect.quincunx',
};

String partLabel(Map<String, dynamic> part) {
  final String key = part['key'] as String? ?? '';
  final String? trKey = _partLabelKeys[key];
  if (trKey != null) return trKey.tr();
  final String label = part['label'] as String? ?? '';
  return label;
}

String aspectLabel(String aspect) {
  final String? trKey = _aspectKeys[aspect.toLowerCase()];
  return trKey != null ? trKey.tr() : aspect;
}

/// Small pill with the band word ("Strong connection", ...).
class ScoreBandLabel extends StatelessWidget {
  final double score;
  final Color? background;

  const ScoreBandLabel({super.key, required this.score, this.background});

  @override
  Widget build(BuildContext context) {
    final Color color = scoreBandColor(score);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: background ?? color.withOpacity(0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        scoreBandLabelKey(score),
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

/// Transparent breakdown: Chart 73% · Behaviour no data yet · Profile 75%.
class ScorePartsRow extends StatelessWidget {
  final List<Map<String, dynamic>> parts;

  /// true -> chips are meant for dark surfaces (default), false -> light.
  final bool dark;
  final bool showPartialNote;

  const ScorePartsRow({
    super.key,
    required this.parts,
    this.dark = true,
    this.showPartialNote = true,
  });

  @override
  Widget build(BuildContext context) {
    if (parts.isEmpty) return const SizedBox.shrink();
    final Color textColor = dark ? Colors.white : const Color(0xFF1A0B2E);
    final Color muted = dark ? Colors.white60 : Colors.black45;
    final Color surface = dark ? Colors.white.withOpacity(0.10) : Colors.black.withOpacity(0.05);

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: parts.map((Map<String, dynamic> part) {
        final num? value = part['value'] as num?;
        final bool partial = part['partial'] as bool? ?? false;
        final String label = partLabel(part);
        final bool noData = value == null;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: value == null
                  ? muted.withOpacity(0.35)
                  : scoreBandColor(value.toDouble()).withOpacity(0.45),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                label,
                style: TextStyle(
                  color: muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                noData ? 'score.no_data'.tr() : '${value.round()}%',
                style: TextStyle(
                  color: noData ? muted : textColor,
                  fontSize: noData ? 12 : 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (partial && showPartialNote && !noData)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    'score.partial_chart'.tr(),
                    style: TextStyle(color: muted, fontSize: 9),
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

/// "What's driving this score" — ranked aspects behind the headline %.
class TopAspectsCard extends StatelessWidget {
  final List<Map<String, dynamic>> aspects;
  final bool dark;
  final int maxItems;

  const TopAspectsCard({
    super.key,
    required this.aspects,
    this.dark = true,
    this.maxItems = 5,
  });

  @override
  Widget build(BuildContext context) {
    if (aspects.isEmpty) return const SizedBox.shrink();
    final List<Map<String, dynamic>> items = aspects.take(maxItems).toList();
    final Color titleColor = dark ? Colors.white : const Color(0xFF1A0B2E);
    final Color muted = dark ? Colors.white70 : Colors.black54;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: dark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: dark ? Colors.white.withOpacity(0.12) : Colors.black12,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'score.driving_title'.tr(),
            style: TextStyle(
              color: titleColor,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'score.driving_subtitle'.tr(),
            style: TextStyle(color: muted, fontSize: 12),
          ),
          const SizedBox(height: 12),
          ...items.map((Map<String, dynamic> aspect) {
            final String planetA = aspect['planet_a'] as String? ?? '';
            final String planetB = aspect['planet_b'] as String? ?? '';
            final String type = aspect['aspect'] as String? ?? '';
            final num? orb = aspect['orb'] as num?;
            final num? score = aspect['score'] as num?;
            final Color scoreColor =
                score != null ? scoreBandColor(score.toDouble()) : muted;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: <Widget>[
                  Icon(Icons.auto_awesome, size: 16, color: scoreColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        style: TextStyle(
                          color: titleColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                        children: <TextSpan>[
                          TextSpan(text: '$planetA '),
                          TextSpan(
                            text: aspectLabel(type),
                            style: TextStyle(color: scoreColor),
                          ),
                          TextSpan(text: ' $planetB'),
                          if (orb != null)
                            TextSpan(
                              text: '  ·  ${'score.orb'.tr()} ${orb.toStringAsFixed(1)}°',
                              style: TextStyle(
                                color: muted,
                                fontSize: 11,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  if (score != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: scoreColor.withOpacity(0.16),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${score.round()}',
                        style: TextStyle(
                          color: scoreColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
