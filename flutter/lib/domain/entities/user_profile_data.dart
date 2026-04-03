import 'package:flutter/foundation.dart'; // For listEquals
import 'package:syno_app/domain/entities/user.dart';

class UserProfileData {
  final String? name;
  final String? lastName;
  final double? height;
  final DateTime? birthDate;
  final String? birthTime;
  final String? bio;
  final Sex? sex;
  final Location? location;
  final OrientationModel? orientation;
  final List<String>? intention;
  final List<String> coreValues;
  final List<Hobby> hobbies;
  final List<ProfessionModel> professions;
  final List<EducationModel> educations;

  UserProfileData({
    this.name,
    this.lastName,
    this.height,
    this.birthDate,
    this.birthTime,
    this.bio,
    this.sex,
    this.location,
    this.orientation,
    this.intention = const [],
    this.coreValues = const [],
    this.hobbies = const [],
    this.professions = const [],
    this.educations = const [],
  });

  factory UserProfileData.fromUser(User user) {
    return UserProfileData(
      name: user.name,
      lastName: user.lastName,
      height: user.height,
      birthDate: user.birthDate,
      birthTime: user.birthTime,
      bio: user.bio,
      sex: user.sex,
      location: user.location,
      orientation: user.orientation,
      intention: List.from(user.intentions),
      coreValues: List.from(user.coreValues),
      hobbies: List.from(user.hobbies),
      professions: List.from(user.professions),
      educations: List.from(user.educations),
    );
  }

  // This method is used to convert the data to a format suitable for the API.
  // The exact structure might need adjustment based on your backend API.
  Map<String, dynamic> toApiData(List<Sex> sexes, List<OrientationModel> orientations) {
    return {
      'name': name,
      'last_name': lastName,
      'height': height,
      'birth_date': birthDate?.toIso8601String().split('T').first,
      'birth_time': birthTime,
      'bio': bio,
      'sex_id': sex?.id, // Use the ID from the selected Sex object
      'location_id': location?.id,
      'orientation_id': orientation?.id, // Use the ID from the selected Orientation object
      'intention': intention,
      'core_values': coreValues,
      'hobby_ids': hobbies.map((h) => h.id).toList(),
      'profession_ids': professions.map((p) => p.id).toList(),
      'education_ids': educations.map((e) => e.id).toList(),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserProfileData &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          lastName == other.lastName &&
          height == other.height &&
          birthDate == other.birthDate &&
          birthTime == other.birthTime &&
          bio == other.bio &&
          sex == other.sex &&
          location == other.location &&
          orientation == other.orientation &&
          intention == other.intention &&
          listEquals(coreValues, other.coreValues) && // Use listEquals for list comparison
          listEquals(hobbies, other.hobbies) && // Use listEquals for list comparison
          listEquals(professions, other.professions) &&
          listEquals(educations, other.educations);

  @override
  int get hashCode =>
      name.hashCode ^
      lastName.hashCode ^
      height.hashCode ^
      birthDate.hashCode ^
      birthTime.hashCode ^
      bio.hashCode ^
      sex.hashCode ^
      location.hashCode ^
      orientation.hashCode ^
      intention.hashCode ^
      listHashCode(coreValues) ^ // Custom hash for lists
      listHashCode(hobbies) ^ // Custom hash for lists
      listHashCode(professions) ^
      listHashCode(educations);

  // Helper for list hash code
  int listHashCode(List list) {
    int hash = 0;
    for (var item in list) {
      hash = hash ^ item.hashCode;
    }
    return hash;
  }
}