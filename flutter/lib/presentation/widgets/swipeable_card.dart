import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:syno_app/domain/entities/match.dart';
import 'package:syno_app/presentation/providers/auth_providers.dart';
import 'package:syno_app/presentation/widgets/match_score_badge.dart';
import 'package:syno_app/theme.dart';

class SwipeableCard extends ConsumerStatefulWidget {
  final Match match;
  final bool isTopCard;
  final bool likedByUser;
  final VoidCallback? onLike;
  final VoidCallback? onPass;
  final VoidCallback? onViewProfile;

  const SwipeableCard({
    super.key,
    required this.match,
    this.isTopCard = false,
    this.likedByUser = false,
    this.onLike,
    this.onPass,
    this.onViewProfile,
  });

  @override
  ConsumerState<SwipeableCard> createState() => _SwipeableCardState();
}

class _SwipeableCardState extends ConsumerState<SwipeableCard>
    with SingleTickerProviderStateMixin {
  double _dragExtent = 0;
  bool _isDragging = false;
  late AnimationController _animController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _rotationAnimation = Tween<double>(begin: 0, end: 0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _onDragStart(DragStartDetails details) {
    setState(() => _isDragging = true);
  }

  void _onDragUpdate(DragUpdateDetails details) {
    setState(() {
      _dragExtent += details.delta.dx;
    });
  }

  void _onDragEnd(DragEndDetails details) {
    final double velocity = details.velocity.pixelsPerSecond.dx;
    final double threshold = 100;

    if (_dragExtent > threshold || velocity > 500) {
      _animateOut(Offset(1, -0.3));
      Future.delayed(const Duration(milliseconds: 300), () {
        widget.onLike?.call();
      });
    } else if (_dragExtent < -threshold || velocity < -500) {
      _animateOut(Offset(-1, -0.3));
      Future.delayed(const Duration(milliseconds: 300), () {
        widget.onPass?.call();
      });
    } else {
      setState(() {
        _dragExtent = 0;
        _isDragging = false;
      });
    }
  }

  void _animateOut(Offset direction) {
    _slideAnimation = Tween<Offset>(
      begin: Offset(_dragExtent / 200, 0),
      end: direction * 3,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _rotationAnimation = Tween<double>(
      begin: _dragExtent / 300,
      end: direction.dx * 0.3,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _animController.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final Match match = widget.match;
    final double rotation = _isDragging ? _dragExtent / 1000 : 0;

    return AnimatedBuilder(
      animation: _animController,
      builder: (context, child) {
        final Offset slideOffset = _isDragging
            ? Offset(_dragExtent / 200, 0)
            : _slideAnimation.value;
        final double rot = _isDragging ? rotation : _rotationAnimation.value;

        return Transform.translate(
          offset: Offset(slideOffset.dx * 50, slideOffset.dy * 50),
          child: Transform.rotate(
            angle: rot,
            child: GestureDetector(
              onHorizontalDragStart: widget.isTopCard ? _onDragStart : null,
              onHorizontalDragUpdate: widget.isTopCard ? _onDragUpdate : null,
              onHorizontalDragEnd: widget.isTopCard ? _onDragEnd : null,
              child: Stack(
                children: [
                  _buildCard(match),
                  if (widget.isTopCard && _isDragging) _buildSwipeOverlays(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCard(Match match) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        child: Column(
          children: [
            Expanded(
              flex: 6,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    match.matchedUser.photos.isNotEmpty
                        ? match.matchedUser.photos.first.getFullUrl(ref.read(backendUrlProvider))
                        : '',
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: CosmicColors.cosmicPurple,
                      child: const Icon(Icons.person, size: 100, color: Colors.white),
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.85),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    top: 12,
                    right: 12,
                    child: MatchScoreBadge(score: match.averageScore, size: 56),
                  ),
                  if (widget.likedByUser)
                    Positioned(
                      top: 12,
                      left: 12,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                          boxShadow: [BoxShadow(color: Colors.red.withOpacity(0.4), blurRadius: 8)],
                        ),
                        child: const Icon(Icons.favorite, color: Colors.white, size: 20),
                      ),
                    ),
                  Positioned(
                    bottom: 16,
                    left: 16,
                    right: 16,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${match.matchedUser.name}, ${match.matchedUser.age}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            if (match.matchedUser.location != null) ...[
                              Icon(Icons.location_on, color: Colors.white70, size: 14),
                              const SizedBox(width: 4),
                              Text(
                                match.matchedUser.location!.name,
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.8),
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(width: 12),
                            ],
                            if (match.matchedUser.zodiacSign != null) ...[
                              Text(
                                _getZodiacEmoji(match.matchedUser.zodiacSign!) + ' ' + match.matchedUser.zodiacSign!,
                                style: const TextStyle(color: Colors.white, fontSize: 14),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 4,
              child: Container(
                color: const Color(0xFF1A0B2E),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(
                  children: [
                    const Spacer(),
                    Text(
                      '${match.averageScore.round()}%',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Compatibility',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 13,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => widget.onViewProfile?.call(),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.person_outline, color: Colors.white.withOpacity(0.9), size: 18),
                            const SizedBox(width: 8),
                            Text(
                              'View Profile',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
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

  Widget _buildSwipeOverlays() {
    final double likeOpacity = (_dragExtent / 150).clamp(0.0, 1.0);
    final double passOpacity = (-_dragExtent / 150).clamp(0.0, 1.0);

    return Stack(
      children: [
        if (likeOpacity > 0)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.xl),
                border: Border.all(color: Colors.green.withOpacity(likeOpacity), width: 4),
                color: Colors.green.withOpacity(likeOpacity * 0.15),
              ),
              child: Center(
                child: Transform.rotate(
                  angle: -0.3,
                  child: Text(
                    'LIKE',
                    style: TextStyle(
                      color: Colors.green.withOpacity(likeOpacity),
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ),
        if (passOpacity > 0)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.xl),
                border: Border.all(color: Colors.red.withOpacity(passOpacity), width: 4),
                color: Colors.red.withOpacity(passOpacity * 0.15),
              ),
              child: Center(
                child: Transform.rotate(
                  angle: 0.3,
                  child: Text(
                    'PASS',
                    style: TextStyle(
                      color: Colors.red.withOpacity(passOpacity),
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
