class NatalChart {
  final Map<String, double> planetPositions;
  final String? birthTime;

  NatalChart({
    required this.planetPositions,
    this.birthTime,
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

  String getSunSign() => signFromDegree(sun ?? 0);
  String getMoonSign() => signFromDegree(moon ?? 0);
  String getMercurySign() => signFromDegree(mercury ?? 0);
  String getVenusSign() => signFromDegree(venus ?? 0);
  String getMarsSign() => signFromDegree(mars ?? 0);

  static String signFromDegree(double degree) {
    final normalized = degree % 360;
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

  Map<String, dynamic> toJson() => {
        'planetPositions': planetPositions,
        'birthTime': birthTime,
      };

  factory NatalChart.fromJson(Map<String, dynamic> json) => NatalChart(
        planetPositions: Map<String, double>.from(
          (json['planetPositions'] as Map).map(
            (k, v) => MapEntry(k as String, (v as num).toDouble()),
          ),
        ),
        birthTime: json['birthTime'] as String?,
      );
}
