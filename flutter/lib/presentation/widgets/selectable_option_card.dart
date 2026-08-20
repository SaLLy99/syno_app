import 'package:flutter/material.dart';
import 'package:syno_app/theme.dart';

class SelectableOptionCard extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final String? subtitle;
  final String? emoji;

  const SelectableOptionCard({
    super.key,
    required this.label,
    this.selected = false,
    this.onTap,
    this.subtitle,
    this.emoji,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: selected ? 1.03 : 1.0,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: selected ? CosmicColors.cosmicPink20 : const Color(0xFF11121A),
          border: Border.all(
            color: selected ? CosmicColors.cosmicPink : const Color(0x33FFFFFF),
            width: selected ? 2 : 1,
          ),
          boxShadow: selected
              ? <BoxShadow>[
                  BoxShadow(
                      color: CosmicColors.cosmicPink.withOpacity(0.22),
                      blurRadius: 12,
                      offset: const Offset(0, 4))
                ]
              : <BoxShadow>[],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: Padding(
              padding: emoji != null
                  ? const EdgeInsets.symmetric(horizontal: 12, vertical: 14)
                  : const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              child: emoji != null
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(emoji!, style: const TextStyle(fontSize: 20)),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            label,
                            style: TextStyle(
                              color: selected ? Colors.white : Colors.white70,
                              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                              fontSize: 14,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          label,
                          style: TextStyle(
                            color: selected ? Colors.white : Colors.white70,
                            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                            fontSize: 15,
                          ),
                        ),
                        if (subtitle != null) ...<Widget>[
                          const SizedBox(height: 8),
                          Text(
                            subtitle!,
                            style: TextStyle(
                              color: selected ? Colors.white70 : Colors.white54,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
