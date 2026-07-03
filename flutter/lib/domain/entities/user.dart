import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:syno_app/domain/entities/profile_options.dart';

// --- Supporting Models ---

class Hobby {
  final int id;
  final String name;
  Hobby({required this.id, required this.name});

  factory Hobby.fromJson(Map<String, dynamic> json) {
    return Hobby(
      id: json['id'] as int,
      name: json['name'] as String,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Hobby &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

class Sex {
  final int id;
  final String name;
  Sex({required this.id, required this.name, required String translationKey});

  factory Sex.fromJson(Map<String, dynamic> json) {
    return Sex(
      id: json['id'] as int,
      translationKey: 'sex',
      name: json['name'] as String,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Sex && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
class CoreValue {
  final int id;
  final String key;
  final String translationKey;

  // Corrected constructor
  CoreValue({
    required this.id,
    required this.key,
    required this.translationKey,
  });

  // Factory constructor to create CoreValue from JSON
  factory CoreValue.fromJson(Map<String, dynamic> json) {
    return CoreValue(
     id: json['id'] is int ? json['id'] as int : int.parse(json['id'].toString()),
    key: json['key'] ?? '', 
    translationKey: json['translation_key'] ?? '', 
    );
  }
}

class Intentions {
  final int id;
  final String key;
  final String translationKey;

  // Corrected constructor
  Intentions({
    required this.id,
    required this.key,
    required this.translationKey,
  });

  // Factory constructor to create CoreValue from JSON
  factory Intentions.fromJson(Map<String, dynamic> json) {
    return Intentions(
     id: json['id'] is int ? json['id'] as int : int.parse(json['id'].toString()),
    key: json['key'] ?? '', 
    translationKey: json['translation_key'] ?? '', 
    );
  }
}



class OrientationModel {
  final int id;
  final String name;
  OrientationModel({required this.id, required this.name});

  factory OrientationModel.fromJson(Map<String, dynamic> json) {
    return OrientationModel(
      id: json['id'] as int,
      name: json['name'] as String
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OrientationModel &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

class ProfessionModel {
  final int id;
  final String name;
  ProfessionModel({required this.id, required this.name});

  factory ProfessionModel.fromJson(Map<String, dynamic> json) {
    return ProfessionModel(
      id: json['id'] as int,
      name: json['name'] as String,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProfessionModel &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

class EducationModel {
  final int id;
  final String name;
  EducationModel({required this.id, required this.name});

  factory EducationModel.fromJson(Map<String, dynamic> json) {
    return EducationModel(
      id: json['id'] as int,
      name: json['name'] as String,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EducationModel &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

class Photo {
  final int id;
  final String url;
  final bool isPrimary;
  final int uploadOrder;

  Photo({
    required this.id,
    required this.url,
    required this.isPrimary,
    this.uploadOrder = 0,
  });

  factory Photo.fromJson(Map<String, dynamic> json) {
    return Photo(
      id: json['id'] as int,
      url: json['url'] as String? ?? '',
      isPrimary: json['is_primary'] as bool? ?? false,
      uploadOrder: json['upload_order'] as int? ?? 0,
    );
  }
}

class LocationParent {
  final int? id;
  final String name;

  LocationParent({this.id, required this.name});

  factory LocationParent.fromJson(Map<String, dynamic> json) {
    return LocationParent(
      id: json['id'] as int?,
      name: json['name'] as String,
    );
  }
}


class Location {
  final int id;
  final String name;
  final String? type;
  final LocationParent? parent;

  Location({
    required this.id,
    required this.name,
    this.type,
    this.parent,
  });

  factory Location.fromJson(Map<String, dynamic> json) => Location(
        id: json['id'] as int,
        name: json['name'] as String,
        type: json['type'] as String?,
        parent: json['parent'] != null
            ? LocationParent.fromJson(json['parent'] as Map<String, dynamic>)
            : null,
      );

  Location copyWith({
    int? id,
    String? name,
    String? type,
    LocationParent? parent,
  }) {
    return Location(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      parent: parent ?? this.parent,
    );
  }
}

class UserPreferences {
  final int minAge;
  final int maxAge;
  final int maxDistance;
  final List<String> interestedIn;

  UserPreferences({
    required this.minAge,
    required this.maxAge,
    required this.maxDistance,
    required this.interestedIn,
  });

  factory UserPreferences.fromJson(Map<String, dynamic> json) {
    return UserPreferences(
      minAge: json['minAge'] as int,
      maxAge: json['maxAge'] as int,
      maxDistance: json['maxDistance'] as int,
      interestedIn: (json['interestedIn'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'minAge': minAge,
        'maxAge': maxAge,
        'maxDistance': maxDistance,
        'interestedIn': interestedIn,
      };
}

// --- Main User Model ---

class User {
  final int id;
  final int userId;
  final String? name;
  final String? lastName;
  final double? height;
  final DateTime? birthDate;
  final String? birthTime;
  final Location? location;
  final List<Intentions> intentions;
  final List<CoreValue> coreValues;
  final String? bio;
  final Sex? sex;
  final OrientationModel? orientation;
  final List<Hobby> hobbies;
  final List<Photo> photos;
  final List<ProfessionModel> professions;
  final List<EducationModel> educations;
  final Map<String, dynamic> personalityTraits;
  final UserPreferences? preferences;
  final String? profilePhotoUrl;
  final DateTime? lastProfileEditAt;
  final Map<String, dynamic>? themePreferences; // Field added

  User({
    required this.id,
    required this.userId,
    this.name,
    this.lastName,
    this.height,
    this.birthDate,
    this.birthTime,
    this.location,
    this.intentions= const[],
    this.coreValues = const [],
    this.bio,
    this.sex,
    this.orientation,
    this.hobbies = const [],
    this.photos = const [],
    this.professions = const [],
    this.educations = const [],
    this.personalityTraits = const {},
    this.preferences,
    this.profilePhotoUrl,
    this.lastProfileEditAt,
    this.themePreferences,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    try {
      return User(
        id: json['id'] as int,
        userId: json['user_id'] as int,
        name: json['name'] as String?,
        lastName: json['last_name'] as String?,
        height: (json['height'] as num?)?.toDouble(),
        birthDate: json['birth_date'] != null
            ? DateTime.tryParse(json['birth_date'] as String)
            : null,
        birthTime: json['birth_time'] as String?,
        location: json['location'] is Map<String, dynamic>
            ? Location.fromJson(json['location'] as Map<String, dynamic>)
            : null,
        intentions: (json['intentions'] as List<dynamic>?)
                ?.map((e) => Intentions.fromJson(e as Map<String, dynamic>))
                .toList() ?? [],
        coreValues: (json['core_values'] as List<dynamic>?)
                ?.map((e) => CoreValue.fromJson(e as Map<String, dynamic>))
                .toList() ?? [],
        bio: json['bio'] as String?,
        sex: json['sex'] != null
            ? Sex.fromJson(json['sex'] as Map<String, dynamic>)
            : null,
        orientation: json['orientation'] != null
            ? OrientationModel.fromJson(json['orientation'] as Map<String, dynamic>)
            : null,
        hobbies: (json['hobbies'] as List<dynamic>?)
                ?.map((e) => Hobby.fromJson(e as Map<String, dynamic>))
                .toList() ?? [],
        photos: (json['photos'] as List<dynamic>?)
                ?.map((e) => Photo.fromJson(e as Map<String, dynamic>))
                .toList() ?? [],
        professions: (json['professions'] as List<dynamic>?)
                ?.map((e) => ProfessionModel.fromJson(e as Map<String, dynamic>))
                .toList() ?? [],
        educations: (json['educations'] as List<dynamic>?)
                ?.map((e) => EducationModel.fromJson(e as Map<String, dynamic>))
                .toList() ?? [],
        personalityTraits: json['personality_traits'] != null
            ? Map<String, dynamic>.from(json['personality_traits'] as Map)
            : {},
        preferences: json['preferences'] != null
            ? UserPreferences.fromJson(json['preferences'] as Map<String, dynamic>)
            : null,
        profilePhotoUrl: json['profile_photo_url'] as String?,
        lastProfileEditAt: json['last_profile_edit_at'] != null
            ? DateTime.tryParse(json['last_profile_edit_at'] as String)
            : null,
        themePreferences: json['theme_preferences'] != null
            ? Map<String, dynamic>.from(json['theme_preferences'] as Map)
            : null,
      );
    } catch (e, stacktrace) {
      debugPrint('Error parsing User from JSON: $e');
      debugPrint(stacktrace.toString());
      rethrow;
    }
  }

  int? get age {
    if (birthDate == null) return null;
    final now = DateTime.now();
    int age = now.year - birthDate!.year;
    if (now.month < birthDate!.month ||
        (now.month == birthDate!.month && now.day < birthDate!.day)) {
      age--;
    }
    return age;
  }

  String? get zodiacSign {
    if (birthDate == null) return null;
    DateTime date = birthDate!;
    int day = date.day;
    int month = date.month;
    if (month == 1) return day >= 20 ? 'Aquarius' : 'Capricorn';
    if (month == 2) return day >= 19 ? 'Pisces' : 'Aquarius';
    if (month == 3) return day >= 21 ? 'Aries' : 'Pisces';
    if (month == 4) return day >= 20 ? 'Taurus' : 'Aries';
    if (month == 5) return day >= 21 ? 'Gemini' : 'Taurus';
    if (month == 6) return day >= 21 ? 'Cancer' : 'Gemini';
    if (month == 7) return day >= 23 ? 'Leo' : 'Cancer';
    if (month == 8) return day >= 23 ? 'Virgo' : 'Leo';
    if (month == 9) return day >= 23 ? 'Libra' : 'Virgo';
    if (month == 10) return day >= 23 ? 'Scorpio' : 'Libra';
    if (month == 11) return day >= 22 ? 'Sagittarius' : 'Scorpio';
    if (month == 12) return day >= 22 ? 'Capricorn' : 'Sagittarius';
    return null;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'name': name,
      'last_name': lastName,
      'height': height,
      'birth_date': birthDate?.toIso8601String().split('T').first,
      'birth_time': birthTime,
      'location': location,
      'intentions': intentions.map((cv) => {
        'id': cv.id,
        'key': cv.key,
        'translation_key': cv.translationKey,
      }).toList(),
      'core_values': coreValues.map((cv) => {
        'id': cv.id,
        'key': cv.key,
        'translation_key': cv.translationKey,
      }).toList(),
      'bio': bio,
      'sex': sex != null ? {'id': sex!.id, 'name': sex!.name} : null,
      'orientation': orientation != null
          ? {'id': orientation!.id, 'name': orientation!.name}
          : null,
      'hobbies': hobbies.map((h) => {'id': h.id, 'name': h.name}).toList(),
      'photos': photos.map((p) => {'id': p.id, 'url': p.url, 'is_primary': p.isPrimary}).toList(),
      'professions': professions.map((p) => {'id': p.id, 'name': p.name}).toList(),
      'educations': educations.map((e) => {'id': e.id, 'name': e.name}).toList(),
      'personality_traits': personalityTraits,
      'preferences': preferences?.toJson(),
      'profile_photo_url': profilePhotoUrl,
      'last_profile_edit_at': lastProfileEditAt?.toIso8601String(),
      'theme_preferences': themePreferences,
    };
  }

  User copyWith({
    int? id,
    int? userId,
    String? name,
    String? lastName,
    double? height,
    DateTime? birthDate,
    String? birthTime,
    Location? location,
    List<Intentions>? intentions,
    List<CoreValue>? coreValues,
    String? bio,
    Sex? sex,
    OrientationModel? orientation,
    List<Hobby>? hobbies,
    List<Photo>? photos,
    List<ProfessionModel>? professions,
    List<EducationModel>? educations,
    Map<String, dynamic>? personalityTraits,
    UserPreferences? preferences,
    String? profilePhotoUrl,
    Map<String, dynamic>? themePreferences,
  }) {
    return User(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      lastName: lastName ?? this.lastName,
      height: height ?? this.height,
      birthDate: birthDate ?? this.birthDate,
      birthTime: birthTime ?? this.birthTime,
      location: location ?? this.location,
      intentions: intentions?? this.intentions,
      coreValues: coreValues ?? this.coreValues,
      bio: bio ?? this.bio,
      sex: sex ?? this.sex,
      orientation: orientation ?? this.orientation,
      hobbies: hobbies ?? this.hobbies,
      photos: photos ?? this.photos,
      professions: professions ?? this.professions,
      educations: educations ?? this.educations,
      personalityTraits: personalityTraits ?? this.personalityTraits,
      preferences: preferences ?? this.preferences,
      profilePhotoUrl: profilePhotoUrl ?? this.profilePhotoUrl,
      lastProfileEditAt: this.lastProfileEditAt, // Kept stable
      themePreferences: themePreferences ?? this.themePreferences,
    );
  }
}

extension UserEditPermissions on User {
  bool get canEditProfile {
    if (lastProfileEditAt == null) return true;
    return DateTime.now().difference(lastProfileEditAt!).inDays >= 7;
  }

  int get daysUntilNextEdit {
    if (canEditProfile) return 0;
    final nextEditDate = lastProfileEditAt!.add(const Duration(days: 7));
    final remaining = nextEditDate.difference(DateTime.now());
    return remaining.inDays + 1;
  }
}