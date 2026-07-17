import 'package:syno_app/data/services/profile_options.dart';
import 'package:syno_app/domain/entities/hobbies_data.dart';
import 'package:syno_app/domain/entities/location_item.dart';
import 'package:syno_app/domain/entities/orientations_data.dart';
import 'package:syno_app/domain/entities/sexes_data.dart';
import 'package:syno_app/data/services/education_service.dart';
import 'package:syno_app/data/services/profession_service.dart';
import 'package:syno_app/domain/entities/user.dart' hide Sex, Hobby, CoreValue;

class Photo {
  final int id;
  final bool isPrimary;

  Photo({required this.id, required this.isPrimary});

  factory Photo.fromJson(Map<String, dynamic> json) {
    return Photo(
      id: json['id'],
      isPrimary: json['is_primary'] ?? false,
    );
  }
}

class User {
  final String id;
  final String email;
  final String? name;
  final String? lastName;
  final DateTime? birthDate;
  final String? birthTime;
  final String? bio;
  final int? age;
  final String? zodiacSign;
  final LocationItem? location;
  final Sex? sex;
  final Orientations? orientation;
  final List<Photo> photos;
  final List<Hobby> hobbies;
  final List<ProfessionModel> professions;
  final List<EducationModel> educations;
  final bool? canEditProfile;
  final int? daysUntilNextEdit;

  // Refactored fields
  final List<CoreValue> coreValues;
  final List<Intention> intentions;

  User({
    required this.id,
    required this.email,
    this.name,
    this.lastName,
    this.birthDate,
    this.birthTime,
    this.bio,
    this.age,
    this.zodiacSign,
    this.location,
    this.sex,
    this.orientation,
    this.photos = const <Photo>[],
    this.hobbies = const <Hobby>[],
    this.professions = const <ProfessionModel>[],
    this.educations = const <EducationModel>[],
    this.canEditProfile,
    this.daysUntilNextEdit,
    this.coreValues = const <CoreValue>[],
    this.intentions = const <Intention>[],
  });

  factory User.fromJson(Map<String, dynamic> json) {
    // Helper to safely parse lists of objects
    List<T> parseList<T>(String key, T Function(Map<String, dynamic>) fromJson) {
      if (json[key] == null) return <T>[];
      return (json[key] as List<dynamic>)
          .map((item) => fromJson(item as Map<String, dynamic>))
          .toList();
    }

    return User(
      id: json['id'],
      email: json['email'],
      name: json['name'],
      lastName: json['last_name'],
      birthDate: json['birth_date'] != null ? DateTime.tryParse(json['birth_date']) : null,
      birthTime: json['birth_time'],
      bio: json['bio'],
      age: json['age'],
      zodiacSign: json['zodiac_sign'],
      location: json['location'] != null ? LocationItem.fromJson(json['location']) : null,
      sex: json['sex'] != null ? Sex.fromJson(json['sex']) : null,
      orientation: json['orientation'] != null ? Orientations.fromJson(json['orientation']) : null,
      photos: parseList('photos', Photo.fromJson),
      hobbies: parseList('hobbies', Hobby.fromJson),
      professions: parseList('professions', ProfessionModel.fromJson),
      educations: parseList('educations', EducationModel.fromJson),
      canEditProfile: json['can_edit_profile'],
      daysUntilNextEdit: json['days_until_next_edit'],
      
      // Updated fields
      coreValues: parseList('core_values', CoreValue.fromJson),
      intentions: parseList('intentions', Intention.fromJson),
    );
  }
}