import 'package:flutter/material.dart';
import 'package:syno_app/theme.dart';

class CosmicGradientButton extends StatelessWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final double? height;
  final BorderRadius? borderRadius;
  final List<BoxShadow>? boxShadow;
  final Gradient gradient;

  const CosmicGradientButton({
    super.key,
    required this.child,
    required this.onPressed,
    this.height = 50.0,
    this.borderRadius,
    this.boxShadow,
    this.gradient = CosmicColors.cosmicGradient,
  });

  @override
  Widget build(BuildContext context) {
    final BorderRadius br = borderRadius ?? BorderRadius.circular(AppRadius.lg);
    return Container(
      height: height,
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: br,
        boxShadow: boxShadow,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: br,
          child: Center(
            child: child,
          ),
        ),
      ),
    );
  }
}