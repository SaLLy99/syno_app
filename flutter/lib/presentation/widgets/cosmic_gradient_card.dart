import 'package:flutter/material.dart';
import 'package:syno_app/theme.dart';

class CosmicGradientCard extends StatelessWidget {
  final Widget child;
  final double? height;
  final double? width;
  final EdgeInsetsGeometry? padding;
  final BorderRadius? borderRadius;

  const CosmicGradientCard({
    super.key,
    required this.child,
    this.height,
    this.width,
    this.padding,
    this.borderRadius,
  });

 @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: width,
      padding: padding ?? AppSpacing.paddingMd,
      decoration: BoxDecoration(
        gradient: CosmicColors.cosmicGradient,
        borderRadius: borderRadius ?? BorderRadius.circular(AppRadius.lg),
        // Corrected Box shadow instantiation
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: CosmicColors.cosmicPurple30, // Use const color
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}
