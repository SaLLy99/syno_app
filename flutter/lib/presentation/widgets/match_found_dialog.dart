import 'dart:math';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syno_app/domain/entities/astrology_system.dart';
import 'package:syno_app/domain/entities/match.dart';
import 'package:syno_app/domain/entities/user.dart';
import 'package:syno_app/theme.dart';

class MatchFoundDialog extends StatefulWidget {
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
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'match_found',
      barrierColor: Colors.black87,
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation) {
        return MatchFoundDialog(matchedUser: matchedUser, match: match, baseUrl: baseUrl);
      },
      transitionBuilder: (BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation, Widget child) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: animation, curve: Curves.elasticOut),
          child: FadeTransition(opacity: animation, child: child),
        );
      },
    );
  }

  @override
  State<MatchFoundDialog> createState() => _MatchFoundDialogState();
}

class _MatchFoundDialogState extends State<MatchFoundDialog> with SingleTickerProviderStateMixin {
  late AnimationController _sparkleController;
  AstrologySystem _system = AstrologySystem.western;

  @override
  void initState() {
    super.initState();
    _sparkleController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();
    _loadSystem();
  }

  Future<void> _loadSystem() async {
    final prefs = await SharedPreferences.getInstance();
    final String? stored = prefs.getString('astrology_system');
    if (stored != null && mounted) {
      try {
        setState(() => _system = AstrologySystem.values.firstWhere((e) => e.name == stored));
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _sparkleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double screenHeight = MediaQuery.of(context).size.height;
    final double screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GestureDetector(
        onTap: () {},
        child: Container(
          width: screenWidth,
          height: screenHeight,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                const Color(0xFF1A0B2E).withOpacity(0.95),
                const Color(0xFF0D0221).withOpacity(0.98),
              ],
            ),
          ),
          child: Stack(
            children: <Widget>[
              ..._buildSparkles(),
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      _buildHeartAnimation(),
                      const SizedBox(height: 24),
                      Text(
                        'match_found.title'.tr(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'match_found.subtitle'.tr(),
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 15,
                          letterSpacing: 0.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32),
                      _buildUserPhoto(),
                      const SizedBox(height: 16),
                      Text(
                        widget.matchedUser.name ?? 'Unknown',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (widget.matchedUser.getZodiacSign(_system) != null) ...<Widget>[
                        const SizedBox(height: 4),
                        Text(
                          widget.matchedUser.getZodiacSign(_system)!,
                          style: TextStyle(color: CosmicColors.cosmicPink.withOpacity(0.8), fontSize: 14),
                        ),
                      ],
                      const SizedBox(height: 36),
                      _buildActionButtons(),
                    ],
                  ),
                ),
              ),
              Positioned(
                top: MediaQuery.of(context).padding.top + 16,
                right: 16,
                child: IconButton(
                  icon: Icon(Icons.close, color: Colors.white.withOpacity(0.6), size: 28),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeartAnimation() {
    return AnimatedBuilder(
      animation: _sparkleController,
      builder: (BuildContext context, Widget? child) {
        final double scale = 1.0 + sin(_sparkleController.value * pi * 2) * 0.08;
        return Transform.scale(
          scale: scale,
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [CosmicColors.cosmicPink, CosmicColors.cosmicPurple],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: CosmicColors.cosmicPink.withOpacity(0.4 + sin(_sparkleController.value * pi * 2) * 0.2),
                  blurRadius: 30,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: const Icon(
              Icons.favorite,
              color: Colors.white,
              size: 40,
            ),
          ),
        );
      },
    );
  }

  Widget _buildUserPhoto() {
    return Container(
      width: 140,
      height: 140,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: CosmicColors.cosmicPink, width: 3),
        boxShadow: [
          BoxShadow(
            color: CosmicColors.cosmicPink.withOpacity(0.3),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: ClipOval(
        child: widget.matchedUser.photos.isNotEmpty
            ? Image.network(
                widget.matchedUser.photos.first.getFullUrl(widget.baseUrl),
                fit: BoxFit.cover,
                errorBuilder: (BuildContext context, Object error, StackTrace? stackTrace) =>
                    const Icon(Icons.person, size: 60, color: Colors.white54),
              )
            : Container(
                color: Colors.white.withOpacity(0.1),
                child: const Icon(Icons.person, size: 60, color: Colors.white54),
              ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: <Widget>[
        Expanded(
          child: OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.white38),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: Text(
              'match_found.keep_swiping'.tr(),
              style: const TextStyle(color: Colors.white70, fontSize: 15),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              context.push('/chat', extra: widget.match);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: CosmicColors.cosmicPink,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 4,
              shadowColor: CosmicColors.cosmicPink.withOpacity(0.5),
            ),
            child: Text(
              'match_found.send_message'.tr(),
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildSparkles() {
    final Random random = Random(42);
    return List<Widget>.generate(12, (int index) {
      final double x = random.nextDouble();
      final double y = random.nextDouble();
      final double size = 2 + random.nextDouble() * 4;
      return Positioned(
        left: MediaQuery.of(context).size.width * x,
        top: MediaQuery.of(context).size.height * y,
        child: AnimatedBuilder(
          animation: _sparkleController,
          builder: (BuildContext context, Widget? child) {
            final double opacity = (sin(_sparkleController.value * pi * 2 + index) + 1) / 2;
            return Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(opacity * 0.6),
              ),
            );
          },
        ),
      );
    });
  }
}
