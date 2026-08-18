import 'dart:math';
import 'package:flutter/material.dart';
import 'package:syno_app/domain/entities/astrology_system.dart';
import 'package:syno_app/domain/entities/natal_chart.dart';

class ZodiacWheelWidget extends StatelessWidget {
  final NatalChart chart;
  final double size;
  final bool showBothCharts;
  final NatalChart? chart2;
  final AstrologySystem? system;

  const ZodiacWheelWidget({
    super.key,
    required this.chart,
    this.size = 280,
    this.showBothCharts = false,
    this.chart2,
    this.system,
  });

  static const List<String> _signs = [
    'Aries', 'Taurus', 'Gemini', 'Cancer', 'Leo', 'Virgo',
    'Libra', 'Scorpio', 'Sagittarius', 'Capricorn', 'Aquarius', 'Pisces'
  ];

  static const Map<String, Color> _elementColors = {
    'Fire': Color(0xFFEF4444),
    'Earth': Color(0xFF10B981),
    'Air': Color(0xFF60A5FA),
    'Water': Color(0xFF8B5CF6),
  };

  static const Map<String, String> _signSymbols = {
    'Aries': '♈', 'Taurus': '♉', 'Gemini': '♊', 'Cancer': '♋',
    'Leo': '♌', 'Virgo': '♍', 'Libra': '♎', 'Scorpio': '♏',
    'Sagittarius': '♐', 'Capricorn': '♑', 'Aquarius': '♒', 'Pisces': '♓',
  };

  static const Map<String, String> _planetSymbols = {
    'Sun': '☉', 'Moon': '☽', 'Mercury': '☿', 'Venus': '♀',
    'Mars': '♂', 'Jupiter': '♃', 'Saturn': '♄', 'Uranus': '♅',
    'Neptune': '♆', 'Pluto': '♇', 'Ascendant': 'ASC',
  };

  static const Map<String, Color> _planetColors = {
    'Sun': Color(0xFFFBBF24),
    'Moon': Color(0xFFE5E7EB),
    'Mercury': Color(0xFF9CA3AF),
    'Venus': Color(0xFFF472B6),
    'Mars': Color(0xFFEF4444),
    'Jupiter': Color(0xFFF97316),
    'Saturn': Color(0xFFA78BFA),
    'Uranus': Color(0xFF67E8F9),
    'Neptune': Color(0xFF60A5FA),
    'Pluto': Color(0xFF6B7280),
    'Ascendant': Color(0xFF34D399),
  };

  @override
  Widget build(BuildContext context) {
    final AstrologySystem displaySystem = system ?? chart.system;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: size,
          height: size,
          child: CustomPaint(
            painter: _ZodiacWheelPainter(
              chart: chart,
              chart2: chart2,
              showBothCharts: showBothCharts,
              signs: _signs,
              elementColors: _elementColors,
              signSymbols: _signSymbols,
              planetSymbols: _planetSymbols,
              planetColors: _planetColors,
            ),
          ),
        ),
        if (system != null) ...[
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${displaySystem.label} - ${displaySystem.description}',
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 10,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _ZodiacWheelPainter extends CustomPainter {
  final NatalChart chart;
  final NatalChart? chart2;
  final bool showBothCharts;
  final List<String> signs;
  final Map<String, Color> elementColors;
  final Map<String, String> signSymbols;
  final Map<String, String> planetSymbols;
  final Map<String, Color> planetColors;

  _ZodiacWheelPainter({
    required this.chart,
    this.chart2,
    required this.showBothCharts,
    required this.signs,
    required this.elementColors,
    required this.signSymbols,
    required this.planetColors,
    required this.planetSymbols,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width / 2, size.height / 2);
    final double radius = size.width / 2 - 10;

    _drawBackground(canvas, center, radius);
    _drawSignSegments(canvas, center, radius);
    _drawSignSymbols(canvas, center, radius);
    _drawPlanetPositions(canvas, center, radius, chart, planetColors, false);
    if (showBothCharts && chart2 != null) {
      _drawPlanetPositions(canvas, center, radius, chart2!, planetColors, true);
    }
  }

  void _drawBackground(Canvas canvas, Offset center, double radius) {
    final Paint bgPaint = Paint()..color = const Color(0xFF1A1035);
    canvas.drawCircle(center, radius, bgPaint);

    final Paint borderPaint = Paint()
      ..color = const Color(0xFF6D28D9).withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(center, radius, borderPaint);
  }

  void _drawSignSegments(Canvas canvas, Offset center, double radius) {
    final double segmentRadius = radius * 0.85;

    for (int i = 0; i < 12; i++) {
      final double startAngle = (i * 30 - 90) * pi / 180;
      final double sweepAngle = 30 * pi / 180;
      final String sign = signs[i];
      final String element = NatalChart.elementForSign(sign);
      final Color color = elementColors[element] ?? Colors.grey;

      final Paint segmentPaint = Paint()
        ..color = color.withOpacity(0.12)
        ..style = PaintingStyle.fill;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: segmentRadius),
        startAngle,
        sweepAngle,
        true,
        segmentPaint,
      );

      final Paint linePaint = Paint()
        ..color = color.withOpacity(0.25)
        ..strokeWidth = 1;

      final double innerR = radius * 0.55;
      final double outerR = radius * 0.85;
      final Offset p1 = Offset(
        center.dx + innerR * cos(startAngle),
        center.dy + innerR * sin(startAngle),
      );
      final Offset p2 = Offset(
        center.dx + outerR * cos(startAngle),
        center.dy + outerR * sin(startAngle),
      );
      canvas.drawLine(p1, p2, linePaint);
    }

    final Paint innerCirclePaint = Paint()
      ..color = const Color(0xFF0F0A25)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius * 0.52, innerCirclePaint);

    final Paint innerBorderPaint = Paint()
      ..color = const Color(0xFF6D28D9).withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawCircle(center, radius * 0.52, innerBorderPaint);
  }

  void _drawSignSymbols(Canvas canvas, Offset center, double radius) {
    final double symbolRadius = radius * 0.72;

    for (int i = 0; i < 12; i++) {
      final double angle = (i * 30 + 15 - 90) * pi / 180;
      final String sign = signs[i];
      final String symbol = signSymbols[sign] ?? '';
      final String element = NatalChart.elementForSign(sign);
      final Color color = elementColors[element] ?? Colors.grey;

      final TextPainter textPainter = TextPainter(
        text: TextSpan(
          text: symbol,
          style: TextStyle(
            color: color,
            fontSize: 16,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();

      final Offset pos = Offset(
        center.dx + symbolRadius * cos(angle) - textPainter.width / 2,
        center.dy + symbolRadius * sin(angle) - textPainter.height / 2,
      );

      textPainter.paint(canvas, pos);
    }
  }

  void _drawPlanetPositions(Canvas canvas, Offset center, double radius, NatalChart natalChart, Map<String, Color> colors, bool isSecond) {
    final double planetRadius = radius * 0.35;
    final List<String> corePlanets = ['Sun', 'Moon', 'Mercury', 'Venus', 'Mars', 'Jupiter', 'Saturn'];

    final Map<double, List<String>> occupiedSlots = {};

    for (final planet in corePlanets) {
      final double? degree = natalChart.planetPositions[planet];
      if (degree == null) continue;

      double adjustedDegree = degree;
      for (final entry in occupiedSlots.entries) {
        if ((degree - entry.key).abs() < 5) {
          adjustedDegree = entry.key + 5;
          break;
        }
      }
      occupiedSlots.putIfAbsent(adjustedDegree, () => []).add(planet);

      final double angle = (adjustedDegree - 90) * pi / 180;
      final Color planetColor = colors[planet] ?? Colors.white;
      final String symbol = planetSymbols[planet] ?? planet[0];

      final Offset planetPos = Offset(
        center.dx + planetRadius * cos(angle),
        center.dy + planetRadius * sin(angle),
      );

      final Paint dotPaint = Paint()
        ..color = isSecond ? planetColor.withOpacity(0.6) : planetColor
        ..style = PaintingStyle.fill;
      canvas.drawCircle(planetPos, isSecond ? 6 : 8, dotPaint);

      final Paint glowPaint = Paint()
        ..color = (isSecond ? planetColor.withOpacity(0.3) : planetColor.withOpacity(0.5))
        ..style = PaintingStyle.fill
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
      canvas.drawCircle(planetPos, isSecond ? 10 : 12, glowPaint);

      final TextPainter textPainter = TextPainter(
        text: TextSpan(
          text: symbol,
          style: TextStyle(
            color: isSecond ? Colors.white70 : Colors.white,
            fontSize: isSecond ? 10 : 12,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();

      textPainter.paint(
        canvas,
        Offset(
          planetPos.dx - textPainter.width / 2,
          planetPos.dy - textPainter.height / 2,
        ),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
