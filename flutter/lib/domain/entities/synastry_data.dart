class SynastryData {
  final double moonScore;
  final double mercuryScore;
  final double venusMarsScore;
  final double nodesScore;
  final double saturnScore;
  final List<Aspect> detailedAspects;
  final String interpretation;
  final Map<String, double> dimensionScores;
  final List<String> strengths;
  final List<String> challenges;
  final String communicationText;
  final String emotionalDynamicText;
  final String valuesText;
  final String growthDynamicText;
  final List<Map<String, dynamic>> importantAspects;
  final bool aiUsed;
  final String personalityA;
  final String personalityB;
  final String loveLanguage;
  final String trustLoyalty;
  final String intimacyText;
  final String conflictStyle;
  final String overallVerdict;
  final List<String> coachTips;

  /// Aspects that drive the headline score, ranked by weight x orb tightness.
  final List<Map<String, dynamic>> topAspects;

  /// True when a birth time was missing and the chart was computed at noon
  /// (houses/Ascendant are approximate).
  final bool chartPartial;

  SynastryData({
    required this.moonScore,
    required this.mercuryScore,
    required this.venusMarsScore,
    required this.nodesScore,
    required this.saturnScore,
    required this.detailedAspects,
    required this.interpretation,
    this.dimensionScores = const {},
    this.strengths = const [],
    this.challenges = const [],
    this.communicationText = '',
    this.emotionalDynamicText = '',
    this.valuesText = '',
    this.growthDynamicText = '',
    this.importantAspects = const [],
    this.aiUsed = false,
    this.personalityA = '',
    this.personalityB = '',
    this.loveLanguage = '',
    this.trustLoyalty = '',
    this.intimacyText = '',
    this.conflictStyle = '',
    this.overallVerdict = '',
    this.coachTips = const [],
    this.topAspects = const [],
    this.chartPartial = false,
  });

  double get overallScore => (moonScore + mercuryScore + venusMarsScore + nodesScore + saturnScore) / 5;

  double get romanceScore => dimensionScores['romance'] ?? dimensionScores['attraction'] ?? venusMarsScore;
  double get emotionalScore => dimensionScores['emotional'] ?? moonScore;
  double get communicationScore => dimensionScores['communication'] ?? mercuryScore;
  double get longTermScore => dimensionScores['long_term'] ?? dimensionScores['stability'] ?? saturnScore;
  double get marriageScore => dimensionScores['marriage'] ?? (saturnScore * 0.9 + moonScore * 0.1);
  double get friendshipScore => dimensionScores['friendship'] ?? (mercuryScore * 0.7 + moonScore * 0.3);
  double get chemistryScore => dimensionScores['chemistry'] ?? dimensionScores['attraction'] ?? venusMarsScore;
  double get spiritualScore => dimensionScores['spiritual'] ?? dimensionScores['growth'] ?? nodesScore;
  double get valuesScore => dimensionScores['values'] ?? 50.0;
  double get conflictScore => dimensionScores['conflict'] ?? 50.0;
  double get stabilityScore => dimensionScores['stability'] ?? saturnScore;
  double get overallDimensionScore => dimensionScores['overall'] ?? overallScore;

  /// One primary match score for headers/badges.
  double primaryScore({double? fallback}) {
    final double? overallDim = dimensionScores['overall'];
    if (overallDim != null) return overallDim;
    if (fallback != null) return fallback;
    return overallScore;
  }

  /// Secondary scores that differ from [primary] by at least 1 point.
  /// [parts] keys are display labels (e.g. Chart, Behavior, Profile).
  List<MapEntry<String, double>> distinctSecondaryScores(
    double primary,
    Map<String, double> parts,
  ) {
    final List<MapEntry<String, double>> out = [];
    for (final MapEntry<String, double> e in parts.entries) {
      if ((e.value - primary).abs() >= 1.0) {
        out.add(e);
      }
    }
    return out;
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'moonScore': moonScore,
        'mercuryScore': mercuryScore,
        'venusMarsScore': venusMarsScore,
        'nodesScore': nodesScore,
        'saturnScore': saturnScore,
        'detailedAspects': detailedAspects.map((Aspect a) => a.toJson()).toList(),
        'interpretation': interpretation,
        'dimensionScores': dimensionScores,
        'strengths': strengths,
        'challenges': challenges,
        'communicationText': communicationText,
        'emotionalDynamicText': emotionalDynamicText,
        'valuesText': valuesText,
        'growthDynamicText': growthDynamicText,
        'importantAspects': importantAspects,
        'aiUsed': aiUsed,
        'personalityA': personalityA,
        'personalityB': personalityB,
        'loveLanguage': loveLanguage,
        'trustLoyalty': trustLoyalty,
        'intimacyText': intimacyText,
        'conflictStyle': conflictStyle,
        'overallVerdict': overallVerdict,
        'coachTips': coachTips,
        'topAspects': topAspects,
        'chartPartial': chartPartial,
      };

  factory SynastryData.fromJson(Map<String, dynamic> json) => SynastryData(
        moonScore: (json['moonScore'] as double),
        mercuryScore: (json['mercuryScore'] as double),
        venusMarsScore: (json['venusMarsScore'] as double),
        nodesScore: (json['nodesScore'] as double),
        saturnScore: (json['saturnScore'] as double),
        detailedAspects: (json['detailedAspects'] as List).map((a) => Aspect.fromJson(a as Map<String, dynamic>)).toList(),
        interpretation: json['interpretation'] as String,
        dimensionScores: json['dimensionScores'] != null
            ? Map<String, double>.from((json['dimensionScores'] as Map).map(
                (k, v) => MapEntry(k as String, (v as num).toDouble()),
              ))
            : const {},
        strengths: (json['strengths'] as List<dynamic>?)?.map((e) => e as String).toList() ?? [],
        challenges: (json['challenges'] as List<dynamic>?)?.map((e) => e as String).toList() ?? [],
        communicationText: json['communicationText'] as String? ?? '',
        emotionalDynamicText: json['emotionalDynamicText'] as String? ?? '',
        valuesText: json['valuesText'] as String? ?? '',
        growthDynamicText: json['growthDynamicText'] as String? ?? '',
        importantAspects: (json['importantAspects'] as List<dynamic>?)?.map((e) => e as Map<String, dynamic>).toList() ?? const [],
        aiUsed: json['aiUsed'] as bool? ?? false,
        personalityA: json['personalityA'] as String? ?? '',
        personalityB: json['personalityB'] as String? ?? '',
        loveLanguage: json['loveLanguage'] as String? ?? '',
        trustLoyalty: json['trustLoyalty'] as String? ?? '',
        intimacyText: json['intimacyText'] as String? ?? '',
        conflictStyle: json['conflictStyle'] as String? ?? '',
        overallVerdict: json['overallVerdict'] as String? ?? '',
        coachTips: (json['coachTips'] as List<dynamic>?)?.map((e) => e as String).toList() ?? const [],
        topAspects: (json['topAspects'] as List<dynamic>?)?.map((e) => e as Map<String, dynamic>).toList() ?? const [],
        chartPartial: json['chartPartial'] as bool? ?? false,
      );

  factory SynastryData.fromCompatibilityResponse(Map<String, dynamic> json) {
    final dims = json['dimensions'] as Map<String, dynamic>? ?? {};
    final interp = json['interpretation'] as Map<String, dynamic>? ?? {};
    final synastry = json['western_synastry'] as Map<String, dynamic>? ?? {};

    final List<Aspect> aspects = [];
    final planetAspects = synastry['planet_aspects'] as List<dynamic>? ?? [];
    for (final a in planetAspects) {
      final String aspectType = a['aspect'] as String? ?? '';
      final String planetA = a['planet_a'] as String? ?? '';
      final String planetB = a['planet_b'] as String? ?? '';
      final double orb = (a['orb'] as num?)?.toDouble() ?? 0;
      final String signA = a['sign_a'] as String? ?? '';
      final String signB = a['sign_b'] as String? ?? '';
      final int? houseA = a['house_a'] as int?;
      final int? houseB = a['house_b'] as int?;

      final String description = _buildRealDescription(aspectType, planetA, planetB, signA, signB, houseA, houseB, orb);

      aspects.add(Aspect(
        planet1: planetA,
        planet2: planetB,
        aspectType: _mapAspectType(aspectType),
        score: _aspectScore(aspectType, orb),
        description: description,
        planet1Sign: signA,
        planet2Sign: signB,
        house1: houseA,
        house2: houseB,
        orb: orb,
        isHarmonious: _isHarmonious(aspectType),
      ));
    }

    aspects.sort((a, b) => b.score.compareTo(a.score));

    final summary = interp['summary'] as String? ?? '';
    final communication = interp['communication'] as String? ?? '';
    final emotionalDynamic = interp['emotional_dynamic'] as String? ?? '';
    final valuesText = interp['values'] as String? ?? '';
    final growthDynamic = interp['growth_dynamic'] as String? ?? '';
    final strengths = (interp['strengths'] as List<dynamic>?)?.map((e) => e as String).toList() ?? [];
    final challenges = (interp['challenges'] as List<dynamic>?)?.map((e) => e as String).toList() ?? [];
    final importantAspects = (interp['important_aspects'] as List<dynamic>?)?.map((e) => e as Map<String, dynamic>).toList() ?? [];

    final Map<String, double> dimensionScores = {};
    dims.forEach((key, value) {
      dimensionScores[key] = (value as num).toDouble();
    });

    final double moonScore = dimensionScores['emotional'] ?? 50.0;
    final double mercuryScore = dimensionScores['communication'] ?? 50.0;
    final double venusMarsScore = dimensionScores['attraction'] ?? 50.0;
    final double nodesScore = dimensionScores['growth'] ?? 50.0;
    final double saturnScore = dimensionScores['stability'] ?? 50.0;

    return SynastryData(
      moonScore: moonScore,
      mercuryScore: mercuryScore,
      venusMarsScore: venusMarsScore,
      nodesScore: nodesScore,
      saturnScore: saturnScore,
      detailedAspects: aspects,
      interpretation: summary,
      dimensionScores: dimensionScores,
      strengths: strengths,
      challenges: challenges,
      communicationText: communication,
      emotionalDynamicText: emotionalDynamic,
      valuesText: valuesText,
      growthDynamicText: growthDynamic,
      importantAspects: importantAspects,
      aiUsed: json['ai_used'] as bool? ?? false,
      personalityA: interp['personality_a'] as String? ?? '',
      personalityB: interp['personality_b'] as String? ?? '',
      loveLanguage: interp['love_language'] as String? ?? '',
      trustLoyalty: interp['trust_loyalty'] as String? ?? '',
      intimacyText: interp['intimacy_text'] as String? ?? '',
      conflictStyle: interp['conflict_style'] as String? ?? '',
      overallVerdict: interp['overall_verdict'] as String? ?? '',
      coachTips: (interp['coach_tips'] as List<dynamic>?)?.map((e) => e as String).toList() ?? const [],
      topAspects: (json['top_aspects'] as List<dynamic>?)?.map((e) => e as Map<String, dynamic>).toList() ?? const [],
      chartPartial: json['score_partial'] as bool? ?? json['partial'] as bool? ?? false,
    );
  }

  // Planet keywords used in descriptions
  static const Map<String, String> _planetKeywords = {
    'Sun': 'core identity',
    'Moon': 'emotions',
    'Mercury': 'communication',
    'Venus': 'love and attraction',
    'Mars': 'passion and drive',
    'Jupiter': 'growth and luck',
    'Saturn': 'commitment and structure',
    'Uranus': 'change and freedom',
    'Neptune': 'dreams and intuition',
    'Pluto': 'transformation',
    'ASC': 'personality',
    'MC': 'public life',
  };

  // House life-area keywords
  static const Map<int, String> _houseAreas = {
    1: 'self and appearance',
    2: 'finances and values',
    3: 'communication and siblings',
    4: 'home and family',
    5: 'creativity and romance',
    6: 'health and daily routines',
    7: 'partnerships and marriage',
    8: 'intimacy and shared resources',
    9: 'adventure and philosophy',
    10: 'career and public image',
    11: 'friendships and community',
    12: 'inner world and healing',
  };

  static String _buildRealDescription(String aspectType, String planetA, String planetB,
      String signA, String signB, int? houseA, int? houseB, double orb) {
    final String key = '${planetA.toLowerCase()}_${planetB.toLowerCase()}_${aspectType.toLowerCase()}';
    final String keyReverse = '${planetB.toLowerCase()}_${planetA.toLowerCase()}_${aspectType.toLowerCase()}';

    // Try exact match first, then reverse
    String? lookup = _aspectDescriptions[key] ?? _aspectDescriptions[keyReverse];
    if (lookup != null) {
      return _personalizeDescription(lookup, planetA, planetB, signA, signB, houseA, houseB);
    }

    // Fallback: build a real description from components
    return _buildFallbackDescription(aspectType, planetA, planetB, signA, signB, houseA, houseB, orb);
  }

  static String _personalizeDescription(String base, String planetA, String planetB,
      String signA, String signB, int? houseA, int? houseB) {
    String result = base;

    // Add sign flavor
    if (signA.isNotEmpty) {
      result = result.replaceAll('{signA}', signA);
    } else {
      result = result.replaceAll('{signA}', planetA);
    }
    if (signB.isNotEmpty) {
      result = result.replaceAll('{signB}', signB);
    } else {
      result = result.replaceAll('{signB}', planetB);
    }

    // Add house flavor
    if (houseA != null && _houseAreas.containsKey(houseA)) {
      result = result.replaceAll('{houseA}', 'in your ${_houseAreas[houseA]} area');
    } else {
      result = result.replaceAll('{houseA}', '');
    }
    if (houseB != null && _houseAreas.containsKey(houseB)) {
      result = result.replaceAll('{houseB}', 'in their ${_houseAreas[houseB]} area');
    } else {
      result = result.replaceAll('{houseB}', '');
    }

    // Clean up extra spaces
    result = result.replaceAll(RegExp(r'\s+'), ' ').trim();
    return result;
  }

  static String _buildFallbackDescription(String aspectType, String planetA, String planetB,
      String signA, String signB, int? houseA, int? houseB, double orb) {
    final String kwA = _planetKeywords[planetA] ?? 'energy';
    final String kwB = _planetKeywords[planetB] ?? 'energy';
    final String signFlavorA = signA.isNotEmpty ? ' ($signA)' : '';
    final String signFlavorB = signB.isNotEmpty ? ' ($signB)' : '';
    final String houseA_text = houseA != null ? ' in your ${_houseAreas[houseA] ?? 'life'} area' : '';
    final String houseB_text = houseB != null ? ' in their ${_houseAreas[houseB] ?? 'life'} area' : '';

    switch (aspectType.toLowerCase()) {
      case 'conjunction':
        return 'Your $planetA$signFlavorA$houseA_text merges with their $planetB$signFlavorB$houseB_text — '
            'a powerful fusion of ${kwA} and ${kwB} that creates deep resonance between you.';
      case 'trine':
        return 'Your $planetA$signFlavorA$houseA_text flows naturally with their $planetB$signFlavorB$houseB_text — '
            'your ${kwA} and ${kwB} harmonize effortlessly, creating ease and mutual understanding.';
      case 'sextile':
        return 'Your $planetA$signFlavorA$houseA_text supports their $planetB$signFlavorB$houseB_text — '
            'your ${kwA} and ${kwB} complement each other, offering opportunities for growth.';
      case 'square':
        return 'Your $planetA$signFlavorA$houseA_text creates tension with their $planetB$signFlavorB$houseB_text — '
            'your ${kwA} and ${kwB} clash at times, but this friction drives both of you to grow.';
      case 'opposition':
        return 'Your $planetA$signFlavorA$houseA_text faces their $planetB$signFlavorB$houseB_text — '
            'your ${kwA} and ${kwB} mirror each other, creating both attraction and the need for balance.';
      default:
        return 'Connection between your $planetA and their $planetB.';
    }
  }

  // Real synastry interpretations keyed by planet_pair_aspect
  static const Map<String, String> _aspectDescriptions = {
    // === SUN-MOON ===
    'Sun_Moon_conjunction': 'Your Sun in {signA} {houseA} conjunct their Moon in {signB} {houseB} — one of the most powerful bonds in synastry. Your conscious identity deeply nourishes their emotional world. You feel naturally drawn to each other, as if you complete a puzzle. This is the classic "soulmate" aspect.',
    'Sun_Moon_trine': 'Your Sun in {signA} {houseA} trines their Moon in {signB} {houseB} — a deeply supportive connection where your identity and their emotions flow together effortlessly. You bring out the best in each other without trying. Comfort and warmth come naturally.',
    'Sun_Moon_sextile': 'Your Sun in {signA} {houseA} sextiles their Moon in {signB} {houseB} — your identity gently awakens their emotional side. There is a natural warmth between you that makes both feel seen and appreciated.',
    'Sun_Moon_square': 'Your Sun in {signA} {houseA} squares their Moon in {signB} {houseB} — your conscious self-expression sometimes clashes with their emotional needs. You may feel you are not on the same page, but this tension can push both of you to grow emotionally.',
    'Sun_Moon_opposition': 'Your Sun in {signA} {houseA} opposes their Moon in {signB} {houseB} — strong magnetic pull but you may feel like opposites at times. What you lack, they provide, and vice versa. Learning to appreciate differences is the key.',

    // === SUN-VENUS ===
    'Sun_Venus_conjunction': 'Your Sun in {signA} {houseA} conjunct their Venus in {signB} {houseB} — you instinctively know how to make them feel loved. There is natural warmth, affection, and a sense of "home" when you are together. Romantic chemistry feels effortless.',
    'Sun_Venus_trine': 'Your Sun in {signA} {houseA} trines their Venus in {signB} {houseB} — your identity and their love language speak the same dialect. You bring joy to each other naturally, and affection flows without reservation.',
    'Sun_Venus_sextile': 'Your Sun in {signA} {houseA} sextiles their Venus in {signB} {houseB} — a sweet and gentle connection where your presence makes them feel appreciated. Small gestures carry deep meaning between you.',
    'Sun_Venus_square': 'Your Sun in {signA} {houseA} squares their Venus in {signB} {houseB} — your self-expression and their love needs sometimes pull in different directions. You may love differently, but learning each other\'s language creates depth.',
    'Sun_Venus_opposition': 'Your Sun in {signA} {houseA} opposes their Venus in {signB} {houseB} — intense romantic attraction, but you may have different styles of giving and receiving love. The pull is magnetic; the work is in meeting halfway.',

    // === SUN-MARS ===
    'Sun_Mars_conjunction': 'Your Sun in {signA} {houseA} conjunct their Mars in {signB} {houseB} — a fiery, dynamic connection. Your identities merge with their drive, creating powerful momentum together. You energize each other physically and mentally.',
    'Sun_Mars_trine': 'Your Sun in {signA} {houseA} trines their Mars in {signB} {houseB} — your presence ignites their passion and drive in the most supportive way. You inspire each other to take action and pursue goals together.',
    'Sun_Mars_sextile': 'Your Sun in {signA} {houseA} sextiles their Mars in {signB} {houseB} — a spark of energy between you. Your identity gently activates their ambition, creating opportunities for shared adventures.',
    'Sun_Mars_square': 'Your Sun in {signA} {houseA} squares their Mars in {signB} {houseB} — competitive energy. Your willpower sometimes collides with their aggression. This can be passionate but also heated; channel it into shared activities.',
    'Sun_Mars_opposition': 'Your Sun in {signA} {houseA} opposes their Mars in {signB} {houseB} — intense physical magnetism. You challenge each other to be stronger, but watch for power struggles. The chemistry is undeniable.',

    // === SUN-SATURN ===
    'Sun_Saturn_conjunction': 'Your Sun in {signA} {houseA} conjunct their Saturn in {signB} {houseB} — a serious, committed bond. Saturn brings structure and responsibility to your identity. This is a relationship that builds something lasting, though it may feel weighty at times.',
    'Sun_Saturn_trine': 'Your Sun in {signA} {houseA} trines their Saturn in {signB} {houseB} — your identity is supported by their sense of responsibility and maturity. They help you grow into your fullest potential with patience and structure.',
    'Sun_Saturn_sextile': 'Your Sun in {signA} {houseA} sextiles their Saturn in {signB} {houseB} — a mature connection where your goals are gently supported by their discipline. Together you can build something real and lasting.',
    'Sun_Saturn_square': 'Your Sun in {signA} {houseA} squares their Saturn in {signB} {houseB} — they may feel like a restriction on your self-expression, or you may feel judged. This aspect demands maturity from both sides but rewards with deep growth.',
    'Sun_Saturn_opposition': 'Your Sun in {signA} {houseA} opposes their Saturn in {signB} {houseB} — a push-pull between your identity and their limitations. You may feel blocked by them, but this friction teaches both of you about boundaries and responsibility.',

    // === MOON-VENUS ===
    'Moon_Venus_conjunction': 'Your Moon in {signA} {houseA} conjunct their Venus in {signB} {houseB} — your emotional worlds and their love nature resonate deeply. You feel each other\'s affections intuitively. This is tender, nurturing love.',
    'Moon_Venus_trine': 'Your Moon in {signA} {houseA} trines their Venus in {signB} {houseB} — emotional comfort and romantic affection blend beautifully. You make each other feel safe to love openly and without fear.',
    'Moon_Venus_sextile': 'Your Moon in {signA} {houseA} sextiles their Venus in {signB} {houseB} — a sweet, gentle bond where your emotions and their affections support each other. Love feels natural and unforced.',
    'Moon_Venus_square': 'Your Moon in {signA} {houseA} squares their Venus in {signB} {houseB} — emotional needs and love styles don\'t always align. You may love differently, but understanding these differences deepens intimacy.',
    'Moon_Venus_opposition': 'Your Moon in {signA} {houseA} opposes their Venus in {signB} {houseB} — strong romantic pull, but emotional needs may differ. What soothes you might not soothe them, and vice versa. Finding balance is the gift.',

    // === MOON-MARS ===
    'Moon_Mars_conjunction': 'Your Moon in {signA} {houseA} conjunct their Mars in {signB} {houseB} — emotionally charged and physically passionate. Their drive stirs your feelings deeply. This is raw, unfiltered connection.',
    'Moon_Mars_trine': 'Your Moon in {signA} {houseA} trines their Mars in {signB} {houseB} — emotional support meets passionate action. They energize your inner world without overwhelming it. You feel both safe and alive.',
    'Moon_Mars_square': 'Your Moon in {signA} {houseA} squares their Mars in {signB} {houseB} — emotional irritability and arguments can arise. Their intensity sometimes overwhelms your feelings. Patience and emotional awareness are essential.',
    'Moon_Mars_opposition': 'Your Moon in {signA} {houseA} opposes their Mars in {signB} {houseB} — emotional magnetism with a volatile edge. You may trigger each other\'s sensitivities, but the passion is powerful when channeled well.',

    // === MERCURY-MERCURY ===
    'Mercury_Mercury_conjunction': 'Your Mercury in {signA} {houseA} conjunct their Mercury in {signB} {houseB} — you think alike. Conversations flow naturally, and you understand each other\'s mental processes. This is the foundation of a meeting of minds.',
    'Mercury_Mercury_trine': 'Your Mercury in {signA} {houseA} trines their Mercury in {signB} {houseB} — communication is effortless and enjoyable. You complement each other\'s thinking styles and can talk for hours without tiring.',
    'Mercury_Mercury_sextile': 'Your Mercury in {signA} {houseA} sextiles their Mercury in {signB} {houseB} — easy, stimulating conversation. You spark each other\'s curiosity and enjoy exchanging ideas.',
    'Mercury_Mercury_square': 'Your Mercury in {signA} {houseA} squares their Mercury in {signB} {houseB} — you think and communicate differently. Misunderstandings can arise, but learning each other\'s mental language builds stronger communication.',
    'Mercury_Mercury_opposition': 'Your Mercury in {signA} {houseA} opposes their Mercury in {signB} {houseB} — you approach conversations from opposite angles. This can be enriching if you listen, or frustrating if you don\'t.',

    // === MERCURY-VENUS ===
    'Mercury_Venus_conjunction': 'Your Mercury in {signA} {houseA} conjunct their Venus in {signB} {houseB} — words become poetry between you. You know how to speak their love language, and conversations feel like foreplay. Intellectual and romantic connection merge.',
    'Mercury_Venus_trine': 'Your Mercury in {signA} {houseA} trines their Venus in {signB} {houseB} — you charm each other with words and ideas. Communication feels like a love language. Sweet nothings come easily.',
    'Mercury_Venus_sextile': 'Your Mercury in {signA} {houseA} sextiles their Venus in {signB} {houseB} — playful, affectionate communication. You make each other smile with how you express yourselves.',

    // === MERCURY-MARS ===
    'Mercury_Mars_conjunction': 'Your Mercury in {signA} {houseA} conjunct their Mars in {signB} {houseB} — sharp, stimulating conversations. You challenge each other mentally and enjoy witty debates. The mind is your erogenous zone.',
    'Mercury_Mars_trine': 'Your Mercury in {signA} {houseA} trines their Mars in {signB} {houseB} — intellectual passion. You energize each other\'s thoughts and can turn ideas into action together.',
    'Mercury_Mars_square': 'Your Mercury in {signA} {houseA} squares their Mars in {signB} {houseB} — sharp words and heated debates. You can push each other\'s buttons mentally, but this friction sharpens both of you.',

    // === VENUS-MARS ===
    'Venus_Mars_conjunction': 'Your Venus in {signA} {houseA} conjunct their Mars in {signB} {houseB} — the classic romantic and sexual magnetism aspect. You are deeply attracted to each other on every level. Chemistry is off the charts.',
    'Venus_Mars_trine': 'Your Venus in {signA} {houseA} trines their Mars in {signB} {houseB} — sensual harmony. Your love nature and their passion blend beautifully. Physical affection feels natural and deeply satisfying.',
    'Venus_Mars_sextile': 'Your Venus in {signA} {houseA} sextiles their Mars in {signB} {houseB} — an attractive spark. You draw each other in with ease, and romantic adventures come naturally.',
    'Venus_Mars_square': 'Your Venus in {signA} {houseA} squares their Mars in {signB} {houseB} — passionate but volatile. The attraction is intense, but so are the disagreements. Learning to fight fair is the lesson.',
    'Venus_Mars_opposition': 'Your Venus in {signA} {houseA} opposes their Mars in {signB} {houseB} — magnetic pull, opposite approaches to love and desire. You want what they have, and they want what you have. Balancing gives and takes is key.',

    // === VENUS-SATURN ===
    'Venus_Saturn_conjunction': 'Your Venus in {signA} {houseA} conjunct their Saturn in {signB} {houseB} — love that endures. Saturn grounds your affection into something real and lasting. This may start slow, but it becomes unshakeable.',
    'Venus_Saturn_trine': 'Your Venus in {signA} {houseA} trines their Saturn in {signB} {houseB} — mature, stable love. You build trust naturally and your affection deepens with time rather than fading.',
    'Venus_Saturn_square': 'Your Venus in {signA} {houseA} squares their Saturn in {signB} {houseB} — love feels restricted or delayed. There may be insecurities around worthiness, but working through them builds unbreakable bonds.',

    // === VENUS-NEPTUNE ===
    'Venus_Neptune_conjunction': 'Your Venus in {signA} {houseA} conjunct their Neptune in {signB} {houseB} — dreamy, romantic love. You see each other through rose-colored glasses. Beautiful for romance; ground in reality when needed.',
    'Venus_Neptune_trine': 'Your Venus in {signA} {houseA} trines their Neptune in {signB} {houseB} — spiritual, compassionate love. You connect on a soul level that transcends the physical. Intuition runs deep.',

    // === VENUS-PLUTO ===
    'Venus_Pluto_conjunction': 'Your Venus in {signA} {houseA} conjunct their Pluto in {signB} {houseB} — transformative, all-consuming love. This connection changes you both. Obsessive at times, but deeply powerful and healing.',
    'Venus_Pluto_trine': 'Your Venus in {signA} {houseA} trines their Pluto in {signB} {houseB} — love with depth and soul. You intuitively understand each other\'s deepest desires and fears, creating profound intimacy.',
    'Venus_Pluto_square': 'Your Venus in {signA} {houseA} squares their Pluto in {signB} {houseB} — intense, complicated love. Jealousy and power dynamics can surface, but facing them together transforms the relationship.',
    'Venus_Pluto_opposition': 'Your Venus in {signA} {houseA} opposes their Pluto in {signB} {houseB} — magnetic, obsessive attraction. This is not a casual connection. It reaches into your deepest vulnerabilities and demands transformation.',

    // === MARS-SATURN ===
    'Mars_Saturn_conjunction': 'Your Mars in {signA} {houseA} conjunct their Saturn in {signB} {houseB} — disciplined drive. Your passion is grounded by their structure. Together you can accomplish anything, though patience is required.',
    'Mars_Saturn_trine': 'Your Mars in {signA} {houseA} trines their Saturn in {signB} {houseB} — your energy and their discipline work in perfect sync. You motivate each other and build real results together.',
    'Mars_Saturn_square': 'Your Mars in {signA} {houseA} squares their Saturn in {signB} {houseB} — frustration and blocked energy. Your drive meets their resistance. This teaches persistence but requires compromise.',

    // === MERCURY-JUPITER ===
    'Mercury_Jupiter_conjunction': 'Your Mercury in {signA} {houseA} conjunct their Jupiter in {signB} {houseB} — expansive conversations. You open each other\'s minds and inspire big thinking. Learning together is a joy.',
    'Mercury_Jupiter_trine': 'Your Mercury in {signA} {houseA} trines their Jupiter in {signB} {houseB} — optimistic, inspiring communication. You see the bigger picture together and lift each other\'s spirits.',

    // === SUN-JUPITER ===
    'Sun_Jupiter_conjunction': 'Your Sun in {signA} {houseA} conjunct their Jupiter in {signB} {houseB} — expansion and joy. Your identity flourishes in their presence. They believe in you and that belief becomes self-fulfilling.',
    'Sun_Jupiter_trine': 'Your Sun in {signA} {houseA} trines their Jupiter in {signB} {houseB} — mutual growth and optimism. Their generosity of spirit nourishes your confidence. Together, anything feels possible.',
    'Sun_Jupiter_square': 'Your Sun in {signA} {houseA} squares their Jupiter in {signB} {houseB} — overconfidence and excess. You may enable each other\'s worst habits, but also inspire each other to dream bigger.',

    // === MOON-JUPITER ===
    'Moon_Jupiter_conjunction': 'Your Moon in {signA} {houseA} conjunct their Jupiter in {signB} {houseB} — emotional generosity. Their optimism nurtures your inner world. You feel understood and emotionally expanded.',
    'Moon_Jupiter_trine': 'Your Moon in {signA} {houseA} trines their Jupiter in {signB} {houseB} — emotional warmth and generosity flow between you. They make you feel safe to dream big.',

    // === MOON-SATURN ===
    'Moon_Saturn_conjunction': 'Your Moon in {signA} {houseA} conjunct their Saturn in {signB} {houseB} — deep emotional bond built on responsibility. They ground your feelings and provide stability. This relationship feels serious and real.',
    'Moon_Saturn_trine': 'Your Moon in {signA} {houseA} trines their Saturn in {signB} {houseB} — emotional security through structure. Their maturity soothes your worries. You feel held and supported.',
    'Moon_Saturn_square': 'Your Moon in {signA} {houseA} squares their Saturn in {signB} {houseB} — emotional heaviness. They may feel like a wet blanket on your feelings, or you may feel restricted emotionally. Work through the walls together.',

    // === MOON-PLUTO ===
    'Moon_Pluto_conjunction': 'Your Moon in {signA} {houseA} conjunct their Pluto in {signB} {houseB} — soul-deep emotional bond. They see through your masks to your rawest self. Transformative but intense.',
    'Moon_Pluto_trine': 'Your Moon in {signA} {houseA} trines their Pluto in {signB} {houseB} — emotional healing through connection. They understand your depths intuitively. This bond feels destined.',
    'Moon_Pluto_square': 'Your Moon in {signA} {houseA} squares their Pluto in {signB} {houseB} — emotional power struggles. Old wounds surface for healing, but the process can be turbulent. Growth comes through facing shadows together.',

    // === JUPITER-SATURN ===
    'Jupiter_Saturn_conjunction': 'Your Jupiter in {signA} {houseA} conjunct their Saturn in {signB} {houseB} — balance of expansion and restraint. You temper each other\'s excesses while building real dreams. A mature, productive bond.',
    'Jupiter_Saturn_trine': 'Your Jupiter in {signA} {houseA} trines their Saturn in {signB} {houseB} — optimism meets discipline. Your big ideas are grounded by their practicality, creating real results.',

    // === NORTH NODE aspects ===
    'NorthNode_Moon_conjunction': 'Your North Node in {signA} {houseA} conjunct their Moon in {signB} {houseB} — karmic emotional connection. Their feelings guide you toward your soul\'s purpose. This bond feels fated.',
    'NorthNode_Sun_conjunction': 'Your North Node in {signA} {houseA} conjunct their Sun in {signB} {houseB} — they illuminate your life path. Being with them inspires you to become who you are meant to be.',
    'NorthNode_Venus_conjunction': 'Your North Node in {signA} {houseA} conjunct their Venus in {signB} {houseB} — love that evolves your soul. This relationship teaches you about unconditional love and your deepest values.',
    'NorthNode_Saturn_conjunction': 'Your North Node in {signA} {houseA} conjunct their Saturn in {signB} {houseB} — karmic lessons through commitment. This relationship challenges you to grow up and embrace your destiny.',
  };

  static String _mapAspectType(String backendType) {
    switch (backendType.toLowerCase()) {
      case 'conjunction': return 'Conjunction';
      case 'opposition': return 'Opposition';
      case 'trine': return 'Trine';
      case 'square': return 'Square';
      case 'sextile': return 'Sextile';
      default: return backendType;
    }
  }

  static bool _isHarmonious(String type) {
    switch (type.toLowerCase()) {
      case 'conjunction':
      case 'trine':
      case 'sextile':
        return true;
      case 'opposition':
      case 'square':
        return false;
      default:
        return true;
    }
  }

  static double _aspectScore(String type, double orb) {
    double base;
    switch (type.toLowerCase()) {
      case 'conjunction': base = 85; break;
      case 'trine': base = 80; break;
      case 'sextile': base = 70; break;
      case 'square': base = 45; break;
      case 'opposition': base = 40; break;
      default: base = 50;
    }
    return (base - orb * 2).clamp(20.0, 98.0);
  }

  SynastryData copyWith({
    double? moonScore,
    double? mercuryScore,
    double? venusMarsScore,
    double? nodesScore,
    double? saturnScore,
    List<Aspect>? detailedAspects,
    String? interpretation,
    Map<String, double>? dimensionScores,
    List<String>? strengths,
    List<String>? challenges,
    String? communicationText,
    String? emotionalDynamicText,
    String? valuesText,
    String? growthDynamicText,
    List<Map<String, dynamic>>? importantAspects,
    bool? aiUsed,
    String? personalityA,
    String? personalityB,
    String? loveLanguage,
    String? trustLoyalty,
    String? intimacyText,
    String? conflictStyle,
    String? overallVerdict,
    List<String>? coachTips,
    List<Map<String, dynamic>>? topAspects,
    bool? chartPartial,
  }) =>
      SynastryData(
        moonScore: moonScore ?? this.moonScore,
        mercuryScore: mercuryScore ?? this.mercuryScore,
        venusMarsScore: venusMarsScore ?? this.venusMarsScore,
        nodesScore: nodesScore ?? this.nodesScore,
        saturnScore: saturnScore ?? this.saturnScore,
        detailedAspects: detailedAspects ?? this.detailedAspects,
        interpretation: interpretation ?? this.interpretation,
        dimensionScores: dimensionScores ?? this.dimensionScores,
        strengths: strengths ?? this.strengths,
        challenges: challenges ?? this.challenges,
        communicationText: communicationText ?? this.communicationText,
        emotionalDynamicText: emotionalDynamicText ?? this.emotionalDynamicText,
        valuesText: valuesText ?? this.valuesText,
        growthDynamicText: growthDynamicText ?? this.growthDynamicText,
        importantAspects: importantAspects ?? this.importantAspects,
        aiUsed: aiUsed ?? this.aiUsed,
        personalityA: personalityA ?? this.personalityA,
        personalityB: personalityB ?? this.personalityB,
        loveLanguage: loveLanguage ?? this.loveLanguage,
        trustLoyalty: trustLoyalty ?? this.trustLoyalty,
        intimacyText: intimacyText ?? this.intimacyText,
        conflictStyle: conflictStyle ?? this.conflictStyle,
        overallVerdict: overallVerdict ?? this.overallVerdict,
        coachTips: coachTips ?? this.coachTips,
        topAspects: topAspects ?? this.topAspects,
        chartPartial: chartPartial ?? this.chartPartial,
      );
}

class Aspect {
  final String planet1;
  final String planet2;
  final String aspectType;
  final double score;
  final String description;
  final String? planet1Sign;
  final String? planet2Sign;
  final int? house1;
  final int? house2;
  final double? orb;
  final bool isHarmonious;

  Aspect({
    required this.planet1,
    required this.planet2,
    required this.aspectType,
    required this.score,
    required this.description,
    this.planet1Sign,
    this.planet2Sign,
    this.house1,
    this.house2,
    this.orb,
    this.isHarmonious = true,
  });

  String get aspectSymbol {
    switch (aspectType.toLowerCase()) {
      case 'conjunction': return '☌';
      case 'sextile': return '⚹';
      case 'trine': return '△';
      case 'square': return '□';
      case 'opposition': return '☍';
      default: return '•';
    }
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'planet1': planet1,
        'planet2': planet2,
        'aspectType': aspectType,
        'score': score,
        'description': description,
        'planet1Sign': planet1Sign,
        'planet2Sign': planet2Sign,
        'house1': house1,
        'house2': house2,
        'orb': orb,
        'isHarmonious': isHarmonious,
      };

  factory Aspect.fromJson(Map<String, dynamic> json) => Aspect(
        planet1: json['planet1'] as String,
        planet2: json['planet2'] as String,
        aspectType: json['aspectType'] as String,
        score: (json['score'] as num).toDouble(),
        description: json['description'] as String,
        planet1Sign: json['planet1Sign'] as String?,
        planet2Sign: json['planet2Sign'] as String?,
        house1: json['house1'] as int?,
        house2: json['house2'] as int?,
        orb: (json['orb'] as num?)?.toDouble(),
        isHarmonious: json['isHarmonious'] as bool? ?? true,
      );
}
