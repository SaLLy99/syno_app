import 'package:flutter/material.dart';
import 'package:syno_app/theme.dart';

class PulsingLogo extends StatefulWidget {
  final double size;
  final String imagePath;

  const PulsingLogo({
    super.key,
    this.size = 120,
    this.imagePath = 'assets/icons/dreamflow_icon.jpg',
  });

  @override
  State<PulsingLogo> createState() => _PulsingLogoState();
}

class _PulsingLogoState extends State<PulsingLogo> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _blurAnimation;
  late final Animation<double> _spreadAnimation;
  late final Animation<Offset> _floatAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 6), // Longer duration for float
      vsync: this,
    )..repeat(reverse: true);

    _blurAnimation = Tween<double>(begin: 20.0, end: 40.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.5, curve: Curves.easeInOut)),
    );
    _spreadAnimation = Tween<double>(begin: 4.0, end: 8.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.5, curve: Curves.easeInOut)),
    );
    _floatAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(0, -10), // Corresponds to translateY(-10px)
    ).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.translate(
          offset: _floatAnimation.value,
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: CosmicColors.cosmicPurple.withOpacity(0.5),
                  blurRadius: _blurAnimation.value,
                  spreadRadius: _spreadAnimation.value,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(widget.size / 2),
              child: Image.asset(
                widget.imagePath,
                fit: BoxFit.cover,
              ),
            ),
          ),
        );
      },
    );
  }
}