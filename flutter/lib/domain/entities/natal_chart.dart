import 'package:syno_app/domain/entities/astrology_system.dart';

class PlanetData {
  final String name;
  final String sign;
  final double degree;
  final double absoluteDegree;
  final int? house;
  final bool retrograde;
  final String signDegree;

  const PlanetData({
    required this.name,
    required this.sign,
    required this.degree,
    required this.absoluteDegree,
    this.house,
    this.retrograde = false,
    this.signDegree = '',
  });

  String get displayDegree {
    final deg = degree.floor();
    final min = ((degree - deg) * 60).floor();
    return "$deg°$min'";
  }

  String get displayWithRetrograde => retrograde ? '$displayDegree R' : displayDegree;
}

class NatalChart {
  final Map<String, double> planetPositions;
  final Map<String, PlanetData> planetDataMap;
  final String? birthTime;
  final Map<String, double>? houses;
  final AstrologySystem system;

  NatalChart({
    required this.planetPositions,
    this.planetDataMap = const {},
    this.birthTime,
    this.houses,
    this.system = AstrologySystem.western,
  });

  double? get sun => planetPositions['Sun'];
  double? get moon => planetPositions['Moon'];
  double? get mercury => planetPositions['Mercury'];
  double? get venus => planetPositions['Venus'];
  double? get mars => planetPositions['Mars'];
  double? get jupiter => planetPositions['Jupiter'];
  double? get saturn => planetPositions['Saturn'];
  double? get uranus => planetPositions['Uranus'];
  double? get neptune => planetPositions['Neptune'];
  double? get pluto => planetPositions['Pluto'];
  double? get ascendant => planetPositions['Ascendant'];
  double? get midheaven => planetPositions['Midheaven'];

  String getSunSign() => signFromDegree(sun ?? 0);
  String getMoonSign() => signFromDegree(moon ?? 0);
  String getMercurySign() => signFromDegree(mercury ?? 0);
  String getVenusSign() => signFromDegree(venus ?? 0);
  String getMarsSign() => signFromDegree(mars ?? 0);
  String getJupiterSign() => signFromDegree(jupiter ?? 0);
  String getSaturnSign() => signFromDegree(saturn ?? 0);
  String getUranusSign() => signFromDegree(uranus ?? 0);
  String getNeptuneSign() => signFromDegree(neptune ?? 0);
  String getPlutoSign() => signFromDegree(pluto ?? 0);
  String getAscendantSign() => signFromDegree(ascendant ?? 0);

  static String signFromDegree(double degree) {
    final normalized = degree % 360;
    if (normalized < 0) return signFromDegree(degree + 360);
    if (normalized < 30) return 'Aries';
    if (normalized < 60) return 'Taurus';
    if (normalized < 90) return 'Gemini';
    if (normalized < 120) return 'Cancer';
    if (normalized < 150) return 'Leo';
    if (normalized < 180) return 'Virgo';
    if (normalized < 210) return 'Libra';
    if (normalized < 240) return 'Scorpio';
    if (normalized < 270) return 'Sagittarius';
    if (normalized < 300) return 'Capricorn';
    if (normalized < 330) return 'Aquarius';
    return 'Pisces';
  }

  static int signIndex(String sign) {
    const signs = ['Aries','Taurus','Gemini','Cancer','Leo','Virgo','Libra','Scorpio','Sagittarius','Capricorn','Aquarius','Pisces'];
    return signs.indexOf(sign);
  }

  static String elementForSign(String sign) {
    const map = {
      'Aries': 'Fire', 'Leo': 'Fire', 'Sagittarius': 'Fire',
      'Taurus': 'Earth', 'Virgo': 'Earth', 'Capricorn': 'Earth',
      'Gemini': 'Air', 'Libra': 'Air', 'Aquarius': 'Air',
      'Cancer': 'Water', 'Scorpio': 'Water', 'Pisces': 'Water',
    };
    return map[sign] ?? 'Unknown';
  }

  static String modalityForSign(String sign) {
    const map = {
      'Aries': 'Cardinal', 'Cancer': 'Cardinal', 'Libra': 'Cardinal', 'Capricorn': 'Cardinal',
      'Taurus': 'Fixed', 'Leo': 'Fixed', 'Scorpio': 'Fixed', 'Aquarius': 'Fixed',
      'Gemini': 'Mutable', 'Virgo': 'Mutable', 'Sagittarius': 'Mutable', 'Pisces': 'Mutable',
    };
    return map[sign] ?? 'Unknown';
  }

  Map<String, double> getElementDistribution() {
    const corePlanets = ['Sun', 'Moon', 'Mercury', 'Venus', 'Mars', 'Jupiter', 'Saturn'];
    int total = 0;
    final Map<String, int> counts = {'Fire': 0, 'Earth': 0, 'Air': 0, 'Water': 0};

    for (final planet in corePlanets) {
      final double? pos = planetPositions[planet];
      if (pos == null) continue;
      final String sign = signFromDegree(pos);
      final String element = elementForSign(sign);
      if (counts.containsKey(element)) {
        counts[element] = counts[element]! + 1;
        total++;
      }
    }

    if (total == 0) return {'Fire': 0, 'Earth': 0, 'Air': 0, 'Water': 0};

    return counts.map((key, value) => MapEntry(key, value / total));
  }

  Map<String, double> getModalityDistribution() {
    const corePlanets = ['Sun', 'Moon', 'Mercury', 'Venus', 'Mars', 'Jupiter', 'Saturn'];
    int total = 0;
    final Map<String, int> counts = {'Cardinal': 0, 'Fixed': 0, 'Mutable': 0};

    for (final planet in corePlanets) {
      final double? pos = planetPositions[planet];
      if (pos == null) continue;
      final String sign = signFromDegree(pos);
      final String modality = modalityForSign(sign);
      if (counts.containsKey(modality)) {
        counts[modality] = counts[modality]! + 1;
        total++;
      }
    }

    if (total == 0) return {'Cardinal': 0, 'Fixed': 0, 'Mutable': 0};

    return counts.map((key, value) => MapEntry(key, value / total));
  }

  List<MapEntry<String, String>> getPlanetSigns() {
    const planetNames = ['Sun', 'Moon', 'Mercury', 'Venus', 'Mars', 'Jupiter', 'Saturn', 'Uranus', 'Neptune', 'Pluto'];
    final List<MapEntry<String, String>> result = [];
    for (final planet in planetNames) {
      final double? pos = planetPositions[planet];
      if (pos != null) {
        result.add(MapEntry(planet, signFromDegree(pos)));
      }
    }
    if (planetPositions.containsKey('Ascendant')) {
      result.add(MapEntry('Ascendant', signFromDegree(planetPositions['Ascendant']!)));
    }
    return result;
  }

  static const Map<String, String> planetSymbols = {
    'Sun': '☉',
    'Moon': '☽',
    'Mercury': '☿',
    'Venus': '♀',
    'Mars': '♂',
    'Jupiter': '♃',
    'Saturn': '♄',
    'Uranus': '♅',
    'Neptune': '♆',
    'Pluto': '♇',
    'Ascendant': 'ASC',
    'Midheaven': 'MC',
  };

  Map<String, dynamic> toJson() => {
        'planetPositions': planetPositions,
        'planetDataMap': planetDataMap.map((k, v) => MapEntry(k, {
          'name': v.name,
          'sign': v.sign,
          'degree': v.degree,
          'absoluteDegree': v.absoluteDegree,
          'house': v.house,
          'retrograde': v.retrograde,
          'signDegree': v.signDegree,
        })),
        'birthTime': birthTime,
        'houses': houses,
        'system': system.name,
      };

  factory NatalChart.fromJson(Map<String, dynamic> json) {
    AstrologySystem sys = AstrologySystem.western;
    if (json['system'] != null) {
      try {
        sys = AstrologySystem.values.firstWhere((e) => e.name == json['system']);
      } catch (_) {}
    }

    final Map<String, PlanetData> dataMap = {};
    if (json['planetDataMap'] != null) {
      (json['planetDataMap'] as Map).forEach((k, v) {
        dataMap[k as String] = PlanetData(
          name: v['name'] as String? ?? k,
          sign: v['sign'] as String? ?? '',
          degree: (v['degree'] as double?)?.toDouble() ?? 0,
          absoluteDegree: (v['absoluteDegree'] as double?)?.toDouble() ?? 0,
          house: v['house'] as int?,
          retrograde: v['retrograde'] as bool? ?? false,
          signDegree: v['signDegree'] as String? ?? '',
        );
      });
    }

    return NatalChart(
      planetPositions: Map<String, double>.from(
        (json['planetPositions'] as Map).map(
          (k, v) => MapEntry(k as String, (v as double)),
        ),
      ),
      planetDataMap: dataMap,
      birthTime: json['birthTime'] as String?,
      houses: json['houses'] != null
          ? Map<String, double>.from(
              (json['houses'] as Map).map(
                (k, v) => MapEntry(k as String, (v as double)),
              ),
            )
          : null,
      system: sys,
    );
  }

  factory NatalChart.fromWesternChartResponse(Map<String, dynamic> json) {
    final Map<String, double> positions = {};
    final Map<String, PlanetData> planetData = {};
    final planets = json['planets'] as List<dynamic>? ?? [];
    for (final p in planets) {
      final String name = p['planet'] as String;
      final double absDeg = (p['absolute_degree'] as double).toDouble();
      positions[name] = absDeg;
      planetData[name] = PlanetData(
        name: name,
        sign: p['sign'] as String? ?? '',
        degree: (p['degree'] as double?)?.toDouble() ?? 0,
        absoluteDegree: absDeg,
        house: p['house'] as int?,
        retrograde: p['retrograde'] as bool? ?? false,
        signDegree: p['sign_degree'] as String? ?? '',
      );
    }

    final ascendant = json['ascendant'] as Map<String, dynamic>?;
    if (ascendant != null) {
      final double ascDeg = (ascendant['absolute_degree'] as double).toDouble();
      positions['Ascendant'] = ascDeg;
      planetData['Ascendant'] = PlanetData(
        name: 'Ascendant',
        sign: ascendant['sign'] as String? ?? '',
        degree: (ascendant['degree'] as double?)?.toDouble() ?? 0,
        absoluteDegree: ascDeg,
        house: 1,
        retrograde: false,
        signDegree: ascendant['sign_degree'] as String? ?? '',
      );
    }

    final mc = json['mc'] as Map<String, dynamic>?;
    if (mc != null) {
      final double mcDeg = (mc['absolute_degree'] as double).toDouble();
      positions['Midheaven'] = mcDeg;
      planetData['Midheaven'] = PlanetData(
        name: 'Midheaven',
        sign: mc['sign'] as String? ?? '',
        degree: (mc['degree'] as double?)?.toDouble() ?? 0,
        absoluteDegree: mcDeg,
        house: 10,
        retrograde: false,
        signDegree: mc['sign_degree'] as String? ?? '',
      );
    }

    final houseCusps = json['house_cusps'] as List<dynamic>? ?? [];
    final Map<String, double> houses = {};
    for (final h in houseCusps) {
      final int num = h['house_number'] as int;
      final double deg = (h['absolute_degree'] as double);
      houses['House $num'] = deg;
    }

    return NatalChart(
      planetPositions: positions,
      planetDataMap: planetData,
      houses: houses.isNotEmpty ? houses : null,
      system: AstrologySystem.western,
    );
  }
}
