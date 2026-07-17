import 'package:flutter/material.dart';
import 'package:syno_app/theme.dart';

class CosmicButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isOutlined;
  final IconData? icon;

  const CosmicButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isOutlined = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    if (isOutlined) {
      return OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: CosmicColors.cosmicPurple, width: 2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
          padding: AppSpacing.paddingMd,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (icon != null) ...<Widget>[
              Icon(icon, color: CosmicColors.cosmicPurple),
              const SizedBox(width: AppSpacing.sm),
            ],
            Text(
              text,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: CosmicColors.cosmicPurple,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

  return Container(
      decoration: BoxDecoration(
        gradient: CosmicColors.cosmicGradient,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: const [
          BoxShadow(
            color: CosmicColors.cosmicPurple30,
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          padding: AppSpacing.paddingMd,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, color: Colors.white),
              const SizedBox(width: AppSpacing.sm),
            ],
            Text(
              text,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}