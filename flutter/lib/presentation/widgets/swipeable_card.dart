import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:syno_app/domain/entities/astrology_system.dart';
import 'package:syno_app/domain/entities/match.dart';
import 'package:syno_app/domain/entities/user.dart';
import 'package:syno_app/presentation/providers/auth_providers.dart';
import 'package:syno_app/theme.dart';

class SwipeableCard extends ConsumerStatefulWidget {
  final Match match;
  final bool isTopCard;
  final bool likedByUser;
  final VoidCallback? onLike;
  final VoidCallback? onPass;
  final VoidCallback? onSuperLike;
  final VoidCallback? onViewProfile;

  const SwipeableCard({
    super.key,
    required this.match,
    this.isTopCard = false,
    this.likedByUser = false,
    this.onLike,
    this.onPass,
    this.onSuperLike,
    this.onViewProfile,
  });

  @override
  ConsumerState<SwipeableCard> createState() => _SwipeableCardState();
}

class _SwipeableCardState extends ConsumerState<SwipeableCard>
    with SingleTickerProviderStateMixin {
  double _dragX = 0;
  double _dragY = 0;
  bool _isDragging = false;
  Offset? _pointerDownPos;
  late AnimationController _animCtrl;
  late Animation<Offset> _slideAnim;
  late Animation<double> _rotateAnim;

  int _photoIdx = 0;
  late PageController _photoPageController;
  DateTime? _pointerDownTime;
  Offset? _lastPointerPos;
  DateTime? _lastPointerTime;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 450));
    _photoPageController = PageController();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _photoPageController.dispose();
    super.dispose();
  }

  bool get _swiping => _dragX.abs() > 10 || _dragY.abs() > 10;

  void _onPointerDown(PointerDownEvent e) {
    if (!widget.isTopCard) return;
    _pointerDownPos = e.localPosition;
    _pointerDownTime = DateTime.now();
    _lastPointerPos = e.localPosition;
    _lastPointerTime = DateTime.now();
    setState(() { _isDragging = true; _dragX = 0; _dragY = 0; });
  }

  void _onPointerMove(PointerMoveEvent e) {
    if (!widget.isTopCard || _pointerDownPos == null) return;
    setState(() {
      _dragX = e.localPosition.dx - _pointerDownPos!.dx;
      _dragY = e.localPosition.dy - _pointerDownPos!.dy;
    });
    _lastPointerPos = e.localPosition;
    _lastPointerTime = DateTime.now();
  }

  void _onPointerUp(PointerUpEvent e) {
    if (!widget.isTopCard || _pointerDownPos == null) return;
    _pointerDownPos = null;
    if (!_swiping) { _resetDrag(); return; }
    final double vx = _calcVelocityX();
    final double vy = _calcVelocityY();
    if (_dragY < -80 || vy < -400) {
      _flyOut(const Offset(0, -3)); _after(widget.onSuperLike);
    } else if (_dragX > 80 || vx > 400) {
      _flyOut(const Offset(3, -0.4)); _after(widget.onLike);
    } else if (_dragX < -80 || vx < -400) {
      _flyOut(const Offset(-3, -0.4)); _after(widget.onPass);
    } else {
      _snapBack();
    }
  }

  double _calcVelocityX() {
    if (_lastPointerPos == null || _lastPointerTime == null || _pointerDownPos == null) return 0;
    final dt = DateTime.now().difference(_lastPointerTime!).inMilliseconds / 1000.0;
    if (dt <= 0 || dt > 0.3) return 0;
    return (_lastPointerPos!.dx - _pointerDownPos!.dx) / dt;
  }

  double _calcVelocityY() {
    if (_lastPointerPos == null || _lastPointerTime == null || _pointerDownPos == null) return 0;
    final dt = DateTime.now().difference(_lastPointerTime!).inMilliseconds / 1000.0;
    if (dt <= 0 || dt > 0.3) return 0;
    return (_lastPointerPos!.dy - _pointerDownPos!.dy) / dt;
  }

  void _resetDrag() {
    setState(() { _dragX = 0; _dragY = 0; _isDragging = false; });
  }

  void _snapBack() {
    final c = CurvedAnimation(parent: _animCtrl, curve: Curves.elasticOut);
    _slideAnim = Tween(begin: Offset(_dragX / 120, _dragY / 120), end: Offset.zero).animate(c);
    _rotateAnim = Tween(begin: _dragX / 300, end: 0.0).animate(c);
    _animCtrl.forward(from: 0).then((_) { if (mounted) _resetDrag(); });
  }

  void _flyOut(Offset dir) {
    final c = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideAnim = Tween(begin: Offset(_dragX / 120, _dragY / 120), end: dir * 2.5).animate(c);
    _rotateAnim = Tween(begin: _dragX / 300, end: dir.dx * 0.2).animate(c);
    _animCtrl.forward(from: 0);
  }

  void _after(VoidCallback? cb) {
    Future.delayed(const Duration(milliseconds: 350), () => cb?.call());
  }

  @override
  Widget build(BuildContext context) {
    final Match m = widget.match;
    final User u = m.matchedUser;
    final List<Photo> photos = u.photos;

    if (!widget.isTopCard) {
      return Transform.rotate(
        angle: 0.04,
        child: Transform.scale(scale: 0.95, child: _buildCard(m, u, photos)),
      );
    }

    return AnimatedBuilder(
      animation: _animCtrl,
      builder: (ctx, _) {
        final Offset off = _isDragging
            ? Offset(_dragX / 120, _dragY / 120)
            : (_animCtrl.isAnimating ? _slideAnim.value : Offset.zero);
        final double rot = _isDragging
            ? _dragX / 300
            : (_animCtrl.isAnimating ? _rotateAnim.value : 0);

        return Transform.translate(
          offset: Offset(off.dx * 60, off.dy * 60),
          child: Transform.rotate(
            angle: rot,
            child: Listener(
              onPointerDown: _onPointerDown,
              onPointerMove: _onPointerMove,
              onPointerUp: _onPointerUp,
              child: Stack(
                children: [
                  _buildCard(m, u, photos),
                  if (_isDragging && _swiping) _swipeOverlay(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCard(Match m, User u, List<Photo> photos) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          fit: StackFit.expand,
          children: [
            _buildPhoto(photos),
            _buildGradient(),
            if (photos.length > 1) _buildStoryBars(photos.length),
            _buildTopRow(m, u),
            _buildBottomSection(m, u),
          ],
        ),
      ),
    );
  }

  Widget _buildPhoto(List<Photo> photos) {
    if (photos.isEmpty) {
      return Container(
        color: CosmicColors.deepSpaceBackgroundStart,
        child: const Center(child: Icon(Icons.person, size: 80, color: Colors.white24)),
      );
    }
    if (photos.length == 1) {
      return Image.network(
        photos[0].getFullUrl(ref.read(backendUrlProvider)),
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, __, ___) => Container(
          color: CosmicColors.deepSpaceBackgroundStart,
          child: const Center(child: Icon(Icons.broken_image, size: 60, color: Colors.white24)),
        ),
      );
    }
    return GestureDetector(
      onTapUp: (TapUpDetails details) {
        final double x = details.localPosition.dx;
        final double w = MediaQuery.of(context).size.width;
        if (x < w * 0.35) {
          if (_photoIdx > 0) {
            _photoPageController.animateToPage(
              _photoIdx - 1,
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
            );
          }
        } else if (x > w * 0.65) {
          if (_photoIdx < photos.length - 1) {
            _photoPageController.animateToPage(
              _photoIdx + 1,
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
            );
          }
        }
      },
      child: Stack(
        children: [
          PageView.builder(
            controller: _photoPageController,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: photos.length,
            onPageChanged: (idx) => setState(() => _photoIdx = idx),
            itemBuilder: (ctx, idx) {
              return Image.network(
                photos[idx].getFullUrl(ref.read(backendUrlProvider)),
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                errorBuilder: (_, __, ___) => Container(
                  color: CosmicColors.deepSpaceBackgroundStart,
                  child: const Center(child: Icon(Icons.broken_image, size: 60, color: Colors.white24)),
                ),
              );
            },
          ),
          if (_photoIdx > 0)
            Positioned(
              left: 8,
              top: 40,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.3),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.chevron_left, color: Colors.white70, size: 20),
              ),
            ),
          if (_photoIdx < photos.length - 1)
            Positioned(
              right: 8,
              top: 40,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.3),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.chevron_right, color: Colors.white70, size: 20),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildGradient() {
    return Positioned.fill(
      child: IgnorePointer(
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withOpacity(0.3),
                Colors.transparent,
                Colors.transparent,
                Colors.black.withOpacity(0.92),
              ],
              stops: const [0.0, 0.2, 0.45, 1.0],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStoryBars(int count) {
    return Positioned(
      top: 8,
      left: 10,
      right: 10,
      child: IgnorePointer(
        child: Row(
          children: List.generate(count, (i) {
            return Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 2),
                height: 3,
                decoration: BoxDecoration(
                  color: i <= _photoIdx ? Colors.white : Colors.white38,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildTopRow(Match m, User u) {
    final int score = m.synastryScore.round();
    return Positioned(
      top: 20,
      left: 14,
      right: 14,
      child: Row(
        children: [
          if (widget.likedByUser)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.favorite, color: Colors.white, size: 12),
                  SizedBox(width: 4),
                  Text('Liked you', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600)),
                ],
              ),
            )
          else
            const SizedBox.shrink(),
          const Spacer(),
          _scoreChip(score),
        ],
      ),
    );
  }

  Widget _scoreChip(int score) {
    Color c = score >= 80 ? Colors.green : score >= 60 ? Colors.blue : Colors.orange;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: c,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.auto_awesome, color: Colors.white, size: 14),
          const SizedBox(width: 4),
          Text('$score%', style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildBottomSection(Match m, User u) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${u.name ?? ''}, ${u.age ?? ''}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      shadows: [Shadow(blurRadius: 6, color: Colors.black54)],
                    ),
                  ),
                ),
                Builder(
                  builder: (ctx) {
                    final String? zodiac = u.getZodiacSign(ref.read(astrologySystemProvider));
                    if (zodiac == null) return const SizedBox.shrink();
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${_zodiac(zodiac)} $zodiac',
                        style: const TextStyle(color: Colors.white, fontSize: 11),
                      ),
                    );
                  },
                ),
              ],
            ),
            if (u.location != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Row(
                  children: [
                    Icon(Icons.location_on, color: Colors.white70, size: 13),
                    const SizedBox(width: 3),
                    Text(u.location!.name, style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13)),
                  ],
                ),
              ),
            if (m.topReasons.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: m.topReasons.take(2).map((r) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(r, style: const TextStyle(color: Colors.white, fontSize: 10)),
                )).toList(),
              ),
            ],
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () => widget.onViewProfile?.call(),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 11),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.person_outline, color: Colors.white.withOpacity(0.9), size: 16),
                    const SizedBox(width: 6),
                    Text(
                      'View Full Profile',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 13,
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
    );
  }

  Widget _swipeOverlay() {
    final double likeOp = (_dragX / 100).clamp(0.0, 1.0);
    final double nopeOp = (-_dragX / 100).clamp(0.0, 1.0);
    final double superOp = (-_dragY / 100).clamp(0.0, 1.0);

    return IgnorePointer(
      child: Stack(
        children: [
          if (likeOp > 0)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: Colors.green.withOpacity(likeOp * 0.15),
                ),
                child: Align(
                  alignment: const Alignment(-0.6, -0.25),
                  child: Transform.rotate(
                    angle: -0.25,
                    child: _label('LIKE', Colors.green, likeOp),
                  ),
                ),
              ),
            ),
          if (nopeOp > 0)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: Colors.red.withOpacity(nopeOp * 0.15),
                ),
                child: Align(
                  alignment: const Alignment(0.6, -0.25),
                  child: Transform.rotate(
                    angle: 0.25,
                    child: _label('NOPE', Colors.red, nopeOp),
                  ),
                ),
              ),
            ),
          if (superOp > 0)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: Colors.blue.withOpacity(superOp * 0.15),
                ),
                child: Center(child: _label('SUPER', Colors.blue, superOp)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _label(String text, Color color, double op) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        border: Border.all(color: color.withOpacity(op), width: 3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color.withOpacity(op),
          fontSize: 36,
          fontWeight: FontWeight.bold,
          letterSpacing: 2,
        ),
      ),
    );
  }

  String _zodiac(String s) {
    const e = {
      'Aries': '\u2648', 'Taurus': '\u2649', 'Gemini': '\u264A', 'Cancer': '\u264B',
      'Leo': '\u264C', 'Virgo': '\u264D', 'Libra': '\u264E', 'Scorpio': '\u264F',
      'Sagittarius': '\u2650', 'Capricorn': '\u2651', 'Aquarius': '\u2652', 'Pisces': '\u2653',
    };
    return e[s] ?? '\u2B50';
  }
}
