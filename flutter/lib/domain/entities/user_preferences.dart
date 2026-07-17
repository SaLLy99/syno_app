class DiscoverPreferences {
  final int minAge;
  final int maxAge;
  final int maxDistance;
  final List<String> genders;
  final List<String> orientations;
  final List<String> lookingFor;
  final bool verifiedOnly;
  final bool onlineRecently;

  final int minCompatibility;
  final String priorityType;
  final Map<String, double> weights;
  final String birthTimeRequirement;

  final String? wantsChildren;
  final String? smoking;
  final String? drinking;
  final String? religion;
  final String? political;
  final String? education;
  final List<String> languages;
  final String? pets;
  final int? minHeight;
  final int? maxHeight;

  final bool hideSwiped;
  final bool hideInactive;
  final bool showTraveling;
  final bool globalSearch;
  final bool photosOnly;
  final bool completeProfilesOnly;

  const DiscoverPreferences({
    this.minAge = 18,
    this.maxAge = 50,
    this.maxDistance = 100,
    this.genders = const [],
    this.orientations = const [],
    this.lookingFor = const [],
    this.verifiedOnly = false,
    this.onlineRecently = false,
    this.minCompatibility = 0,
    this.priorityType = 'balanced',
    this.weights = const {
      'romance': 50,
      'emotional': 50,
      'communication': 50,
      'long_term': 50,
      'marriage': 50,
      'friendship': 50,
      'chemistry': 50,
      'spiritual': 50,
    },
    this.birthTimeRequirement = 'optional',
    this.wantsChildren,
    this.smoking,
    this.drinking,
    this.religion,
    this.political,
    this.education,
    this.languages = const [],
    this.pets,
    this.minHeight,
    this.maxHeight,
    this.hideSwiped = true,
    this.hideInactive = false,
    this.showTraveling = false,
    this.globalSearch = false,
    this.photosOnly = false,
    this.completeProfilesOnly = false,
  });

  factory DiscoverPreferences.fromJson(Map<String, dynamic> json) {
    return DiscoverPreferences(
      minAge: json['min_age'] as int? ?? 18,
      maxAge: json['max_age'] as int? ?? 50,
      maxDistance: json['max_distance'] as int? ?? 100,
      genders: (json['genders'] as List<dynamic>?)?.map((e) => e as String).toList() ?? [],
      orientations: (json['orientations'] as List<dynamic>?)?.map((e) => e as String).toList() ?? [],
      lookingFor: (json['looking_for'] as List<dynamic>?)?.map((e) => e as String).toList() ?? [],
      verifiedOnly: json['verified_only'] as bool? ?? false,
      onlineRecently: json['online_recently'] as bool? ?? false,
      minCompatibility: json['min_compatibility'] as int? ?? 0,
      priorityType: json['priority_type'] as String? ?? 'balanced',
      weights: {
        'romance': (json['weight_romance'] as int? ?? 50).toDouble(),
        'emotional': (json['weight_emotional'] as int? ?? 50).toDouble(),
        'communication': (json['weight_communication'] as int? ?? 50).toDouble(),
        'long_term': (json['weight_long_term'] as int? ?? 50).toDouble(),
        'marriage': (json['weight_marriage'] as int? ?? 50).toDouble(),
        'friendship': (json['weight_friendship'] as int? ?? 50).toDouble(),
        'chemistry': (json['weight_chemistry'] as int? ?? 50).toDouble(),
        'spiritual': (json['weight_spiritual'] as int? ?? 50).toDouble(),
      },
      birthTimeRequirement: json['birth_time_requirement'] as String? ?? 'optional',
      wantsChildren: json['wants_children'] as String?,
      smoking: json['smoking'] as String?,
      drinking: json['drinking'] as String?,
      religion: json['religion'] as String?,
      political: json['political'] as String?,
      education: json['education'] as String?,
      languages: (json['languages'] as List<dynamic>?)?.map((e) => e as String).toList() ?? [],
      pets: json['pets'] as String?,
      minHeight: json['min_height'] as int?,
      maxHeight: json['max_height'] as int?,
      hideSwiped: json['hide_swiped'] as bool? ?? true,
      hideInactive: json['hide_inactive'] as bool? ?? false,
      showTraveling: json['show_traveling'] as bool? ?? false,
      globalSearch: json['global_search'] as bool? ?? false,
      photosOnly: json['photos_only'] as bool? ?? false,
      completeProfilesOnly: json['complete_profiles_only'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'min_age': minAge,
    'max_age': maxAge,
    'max_distance': maxDistance,
    'genders': genders,
    'orientations': orientations,
    'looking_for': lookingFor,
    'verified_only': verifiedOnly,
    'online_recently': onlineRecently,
    'min_compatibility': minCompatibility,
    'priority_type': priorityType,
    'weight_romance': weights['romance']?.toInt() ?? 50,
    'weight_emotional': weights['emotional']?.toInt() ?? 50,
    'weight_communication': weights['communication']?.toInt() ?? 50,
    'weight_long_term': weights['long_term']?.toInt() ?? 50,
    'weight_marriage': weights['marriage']?.toInt() ?? 50,
    'weight_friendship': weights['friendship']?.toInt() ?? 50,
    'weight_chemistry': weights['chemistry']?.toInt() ?? 50,
    'weight_spiritual': weights['spiritual']?.toInt() ?? 50,
    'birth_time_requirement': birthTimeRequirement,
    'wants_children': wantsChildren,
    'smoking': smoking,
    'drinking': drinking,
    'religion': religion,
    'political': political,
    'education': education,
    'languages': languages,
    'pets': pets,
    'min_height': minHeight,
    'max_height': maxHeight,
    'hide_swiped': hideSwiped,
    'hide_inactive': hideInactive,
    'show_traveling': showTraveling,
    'global_search': globalSearch,
    'photos_only': photosOnly,
    'complete_profiles_only': completeProfilesOnly,
  };

  DiscoverPreferences copyWith({
    int? minAge,
    int? maxAge,
    int? maxDistance,
    List<String>? genders,
    List<String>? orientations,
    List<String>? lookingFor,
    bool? verifiedOnly,
    bool? onlineRecently,
    int? minCompatibility,
    String? priorityType,
    Map<String, double>? weights,
    String? birthTimeRequirement,
    String? wantsChildren,
    String? smoking,
    String? drinking,
    String? religion,
    String? political,
    String? education,
    List<String>? languages,
    String? pets,
    int? minHeight,
    int? maxHeight,
    bool? hideSwiped,
    bool? hideInactive,
    bool? showTraveling,
    bool? globalSearch,
    bool? photosOnly,
    bool? completeProfilesOnly,
  }) {
    return DiscoverPreferences(
      minAge: minAge ?? this.minAge,
      maxAge: maxAge ?? this.maxAge,
      maxDistance: maxDistance ?? this.maxDistance,
      genders: genders ?? this.genders,
      orientations: orientations ?? this.orientations,
      lookingFor: lookingFor ?? this.lookingFor,
      verifiedOnly: verifiedOnly ?? this.verifiedOnly,
      onlineRecently: onlineRecently ?? this.onlineRecently,
      minCompatibility: minCompatibility ?? this.minCompatibility,
      priorityType: priorityType ?? this.priorityType,
      weights: weights ?? this.weights,
      birthTimeRequirement: birthTimeRequirement ?? this.birthTimeRequirement,
      wantsChildren: wantsChildren ?? this.wantsChildren,
      smoking: smoking ?? this.smoking,
      drinking: drinking ?? this.drinking,
      religion: religion ?? this.religion,
      political: political ?? this.political,
      education: education ?? this.education,
      languages: languages ?? this.languages,
      pets: pets ?? this.pets,
      minHeight: minHeight ?? this.minHeight,
      maxHeight: maxHeight ?? this.maxHeight,
      hideSwiped: hideSwiped ?? this.hideSwiped,
      hideInactive: hideInactive ?? this.hideInactive,
      showTraveling: showTraveling ?? this.showTraveling,
      globalSearch: globalSearch ?? this.globalSearch,
      photosOnly: photosOnly ?? this.photosOnly,
      completeProfilesOnly: completeProfilesOnly ?? this.completeProfilesOnly,
    );
  }

  static const List<String> priorityTypes = [
    'balanced',
    'romance',
    'emotional',
    'communication',
    'long_term',
    'marriage',
    'friendship',
    'chemistry',
    'spiritual',
  ];

  static const Map<String, String> priorityLabels = {
    'balanced': 'Balanced',
    'romance': 'Romance',
    'emotional': 'Emotional Compatibility',
    'communication': 'Communication',
    'long_term': 'Long-term Stability',
    'marriage': 'Marriage Potential',
    'friendship': 'Friendship',
    'chemistry': 'Sexual Chemistry',
    'spiritual': 'Spiritual Growth',
  };

  static const Map<String, String> weightIcons = {
    'romance': '❤️',
    'emotional': '🌙',
    'communication': '🧠',
    'long_term': '💍',
    'marriage': '💎',
    'friendship': '🤝',
    'chemistry': '⚡',
    'spiritual': '✨',
  };
}
