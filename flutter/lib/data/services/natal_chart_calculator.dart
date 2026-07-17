import 'dart:math';
import 'package:syno_app/domain/entities/natal_chart.dart';

class NatalChartCalculator {
  static const Map<String, double> _signDegrees = {
    'Aries': 0,
    'Taurus': 30,
    'Gemini': 60,
    'Cancer': 90,
    'Leo': 120,
    'Virgo': 150,
    'Libra': 180,
    'Scorpio': 210,
    'Sagittarius': 240,
    'Capricorn': 270,
    'Aquarius': 300,
    'Pisces': 330,
  };

  NatalChart calculate(DateTime birthDate, String? birthTime) {
    final double julianDay = _toJulianDay(birthDate);
    final double centuries = (julianDay - 2451545.0) / 36525.0;

    final Map<String, double> positions = {};

    positions['Sun'] = _calculateSun(centuries);
    positions['Moon'] = _calculateMoon(centuries, birthDate);
    positions['Mercury'] = _calculateMercury(centuries);
    positions['Venus'] = _calculateVenus(centuries);
    positions['Mars'] = _calculateMars(centuries);
    positions['Jupiter'] = _calculateJupiter(centuries);
    positions['Saturn'] = _calculateSaturn(centuries);
    positions['Uranus'] = _calculateUranus(centuries);
    positions['Neptune'] = _calculateNeptune(centuries);

    if (birthTime != null && birthTime.isNotEmpty) {
      final double houseOffset = _calculateHouseOffset(birthTime);
      final String ascendantSign = _calculateAscendant(centuries, houseOffset);
      positions['Ascendant'] = _signDegrees[ascendantSign] ?? 0;
    }

    return NatalChart(
      planetPositions: positions,
      birthTime: birthTime,
    );
  }

  double _toJulianDay(DateTime date) {
    final int y = date.month <= 2 ? date.year - 1 : date.year;
    final int m = date.month <= 2 ? date.month + 12 : date.month;
    final int d = date.day;
    final int a = (y / 100).floor();
    final int b = 2 - a + (a / 4).floor();
    return (365.25 * (y + 4716)).floor() +
        (30.6001 * (m + 1)).floor() +
        d +
        b -
        1524.5;
  }

  double _calculateSun(double T) {
    double L0 = 280.46646 + 36000.76983 * T + 0.0003032 * T * T;
    double M = 357.52911 + 35999.05029 * T - 0.0001537 * T * T;
    M = _toRadians(M % 360);

    final double C =
        (1.9146 - 0.004817 * T - 0.000014 * T * T) * sin(M) +
            (0.019993 - 0.000101 * T) * sin(2 * M) +
            0.00029 * sin(3 * M);

    double longitude = L0 + C;
    longitude = longitude % 360;
    if (longitude < 0) longitude += 360;

    return longitude;
  }

  double _calculateMoon(double T, DateTime birthDate) {
    final double dayFraction = (birthDate.hour + birthDate.minute / 60.0) / 24.0;
    final double D = 297.8501921 + 445267.1114034 * T - 0.0018819 * T * T;
    final double M = 134.9633964 + 477198.8675055 * T + 0.0087414 * T * T;
    final double Mp = 357.5291092 + 35999.0502909 * T - 0.0001536 * T * T;

    double longitude = 218.3164477 +
        481267.88123421 * T -
        0.0015786 * T * T +
        6.289 * sin(_toRadians(M % 360)) +
        1.274 * sin(_toRadians((2 * D - M) % 360)) +
        0.658 * sin(_toRadians(2 * D % 360)) +
        0.214 * sin(_toRadians(2 * M % 360)) -
        0.186 * sin(_toRadians(Mp % 360)) -
        0.114 * sin(_toRadians(2 * _toRadians(Mp) % 360));

    longitude += dayFraction * 13.2; // approximate daily motion
    longitude = longitude % 360;
    if (longitude < 0) longitude += 360;

    return longitude;
  }

  double _calculateMercury(double T) {
    final double L = 252.2509 + 149472.6746 * T;
    final double M = 174.796 + 149474.689 * T;
    final double C = 23.44 * sin(_toRadians(M % 360)) + 2.98 * sin(_toRadians(2 * M % 360));
    double longitude = L + C;
    longitude = longitude % 360;
    if (longitude < 0) longitude += 360;
    return longitude;
  }

  double _calculateVenus(double T) {
    final double L = 181.9798 + 58517.8157 * T;
    final double M = 50.416 + 58519.213 * T;
    final double C = 0.77 * sin(_toRadians(M % 360));
    double longitude = L + C;
    longitude = longitude % 360;
    if (longitude < 0) longitude += 360;
    return longitude;
  }

  double _calculateMars(double T) {
    final double L = 355.433 + 19140.2993 * T;
    final double M = 19.373 + 19140.3027 * T;
    final double C = 10.69 * sin(_toRadians(M % 360)) + 0.62 * sin(_toRadians(2 * M % 360));
    double longitude = L + C;
    longitude = longitude % 360;
    if (longitude < 0) longitude += 360;
    return longitude;
  }

  double _calculateJupiter(double T) {
    final double L = 34.3515 + 3034.9057 * T;
    final double M = 20.020 + 3034.687 * T;
    final double C = 5.56 * sin(_toRadians(M % 360)) + 0.17 * sin(_toRadians(2 * M % 360));
    double longitude = L + C;
    longitude = longitude % 360;
    if (longitude < 0) longitude += 360;
    return longitude;
  }

  double _calculateSaturn(double T) {
    final double L = 50.0774 + 1222.1138 * T;
    final double M = 317.020 + 1222.634 * T;
    final double C = 6.36 * sin(_toRadians(M % 360)) + 0.22 * sin(_toRadians(2 * M % 360));
    double longitude = L + C;
    longitude = longitude % 360;
    if (longitude < 0) longitude += 360;
    return longitude;
  }

  double _calculateUranus(double T) {
    final double L = 313.2381 + 428.4824 * T;
    final double M = 142.238 + 428.466 * T;
    final double C = 0.26 * sin(_toRadians(M % 360));
    double longitude = L + C;
    longitude = longitude % 360;
    if (longitude < 0) longitude += 360;
    return longitude;
  }

  double _calculateNeptune(double T) {
    final double L = 304.8799 + 218.4586 * T;
    final double M = 256.228 + 218.486 * T;
    final double C = 0.26 * sin(_toRadians(M % 360));
    double longitude = L + C;
    longitude = longitude % 360;
    if (longitude < 0) longitude += 360;
    return longitude;
  }

  double _calculateHouseOffset(String birthTime) {
    final parts = birthTime.split(':');
    if (parts.length != 2) return 0;
    final hour = int.tryParse(parts[0]) ?? 12;
    final minute = int.tryParse(parts[1]) ?? 0;
    return (hour + minute / 60.0) * 15.0; // 15 degrees per hour
  }

  String _calculateAscendant(double T, double houseOffset) {
    final double obliquity = 23.4393 - 0.013 * T;
    final double lst = (100.46 + 360.9856235 * (houseOffset / 15.0)) % 360;
    final double y = cos(_toRadians(obliquity)) * sin(_toRadians(lst));
    final double x = cos(_toRadians(lst));
    final double asc = atan2(y, x) * 180 / pi;
    final normalizedAsc = (asc + 360) % 360;

    for (final entry in _signDegrees.entries) {
      if (normalizedAsc >= entry.value && normalizedAsc < entry.value + 30) {
        return entry.key;
      }
    }
    return 'Aries';
  }

  double _toRadians(double degrees) => degrees * pi / 180.0;
}
