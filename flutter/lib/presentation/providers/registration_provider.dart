import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart';

// Typedef to support usages of RegistrationData if it was renamed or used in other services
typedef RegistrationData = RegistrationState;

class ProfileData {
  final String? name;
  final String? lastName;
  final int? height;
  final String? birthDate;
  final String? birthTime;
  final int? locationId;
  final int? sexId;
  final int? orientationId;
  final List<int> intentionIds;
  final List<int> coreValueIds;
  final String? bio;
  final List<int> hobbyIds;
  final List<int> professionIds;
  final List<int> educationIds;

  const ProfileData({
    this.name,
    this.lastName,
    this.height,
    this.birthDate,
    this.birthTime,
    this.locationId,
    this.sexId,
    this.orientationId,
    this.intentionIds = const [],
    this.coreValueIds = const [],
    this.bio,
    this.hobbyIds = const [],
    this.professionIds = const [],
    this.educationIds = const [],
  });

  factory ProfileData.fromMap(Map<String, dynamic> map) {
    return ProfileData(
      name: map['name'] as String?,
      lastName: map['last_name'] as String?,
      height: map['height'] as int?,
      birthDate: map['birth_date'] as String?,
      birthTime: map['birth_time'] as String?,
      locationId: map['location_id'] as int?,
      sexId: map['sex_id'] as int?,
      orientationId: map['orientation_id'] as int?,
      intentionIds: map['intention_ids'] != null
          ? List<int>.from(map['intention_ids'])
          : (map['intentions'] as List?)?.map((e) => e['id'] as int).toList() ?? [],
      coreValueIds: map['core_value_ids'] != null
          ? List<int>.from(map['core_value_ids'])
          : (map['core_values'] as List?)?.map((e) => e['id'] as int).toList() ?? [],
      bio: map['bio'] as String?,
      hobbyIds: map['hobby_ids'] != null
          ? List<int>.from(map['hobby_ids'])
          : (map['hobbies'] as List?)?.map((e) => e['id'] as int).toList() ?? [],
      professionIds: map['profession_ids'] != null
          ? List<int>.from(map['profession_ids'])
          : (map['professions'] as List?)?.map((e) => e['id'] as int).toList() ?? [],
      educationIds: map['education_ids'] != null
          ? List<int>.from(map['education_ids'])
          : (map['educations'] as List?)?.map((e) => e['id'] as int).toList() ?? [],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'last_name': lastName,
      'height': height,
      'birth_date': birthDate,
      'birth_time': birthTime,
      'location_id': locationId,
      'sex_id': sexId,
      'orientation_id': orientationId,
      'intention_ids': intentionIds,
      'core_value_ids': coreValueIds,
      'bio': bio,
      'hobby_ids': hobbyIds,
      'profession_ids': professionIds,
      'education_ids': educationIds,
    }..removeWhere((key, value) => value == null || (value is List && value.isEmpty));
  }

  bool get isInitial => name == null || name!.isEmpty;
}

class RegistrationState {
  final String email;
  final String password;
  final ProfileData profileData;
  final List<XFile> photos;

  const RegistrationState({
    this.email = '',
    this.password = '',
    this.profileData = const ProfileData(),
    this.photos = const [],
  });

  // Used in main.dart to check if registration flow has started (Step 1 complete)
  Map<String, dynamic> get step1Data => email.isNotEmpty ? {'email': email, 'password': password} : {};

  // Used in AuthService to get profile details (excluding core values/intentions which are handled separately)
  Map<String, dynamic> get step2Data => profileData.toMap();
  List<int> get coreValueIds => profileData.coreValueIds;
  List<int> get intentionIds => profileData.intentionIds;

  RegistrationState copyWith({
    String? email,
    String? password,
    ProfileData? profileData,
    List<XFile>? photos,
  }) {
    return RegistrationState(
      email: email ?? this.email,
      password: password ?? this.password,
      profileData: profileData ?? this.profileData,
      photos: photos ?? this.photos,
    );
  }
}

class RegistrationNotifier extends StateNotifier<RegistrationState> {
  RegistrationNotifier() : super(const RegistrationState());

  void setCredentials(String email, String password) {
    state = state.copyWith(email: email, password: password);
  }

  // void updateProfileData(Map<String, dynamic> data) {
  //   // Directly update the profile data from the map provided from registration step 2.
  //   state = state.copyWith(profileData: ProfileData.fromMap(data));
  // }
  void updateProfileData(Map<String, dynamic> data) {
    print('DEBUG: updateProfileData called with: $data');

    // Merge strategy: Get current valid data as a map, and overlay the new data on top.
    // This ensures that if 'data' is partial, we don't lose existing fields.
    final Map<String, dynamic> currentMap = state.profileData.toMap();
    final Map<String, dynamic> mergedMap = {...currentMap, ...data};

    final newProfile = ProfileData.fromMap(mergedMap);
    
    print('DEBUG: Merged ProfileData result: ${newProfile.toMap()}');

    state = state.copyWith(profileData: newProfile);
}

 void addPhotos(List<XFile> newPhotos) {
  state = state.copyWith(photos: [...state.photos, ...newPhotos]);
 }

 void removePhotoAt(int index) {
  if (index >= 0 && index < state.photos.length) {
   final newPhotos = List<XFile>.from(state.photos);
   newPhotos.removeAt(index);
      state = state.copyWith(photos: newPhotos);
    }
  }

  void reorderPhotos(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= state.photos.length) return;
    
    final newPhotos = List<XFile>.from(state.photos);
    final item = newPhotos.removeAt(oldIndex);
    
    if (newIndex > newPhotos.length) newIndex = newPhotos.length;
    if (newIndex < 0) newIndex = 0;

    newPhotos.insert(newIndex, item);
    state = state.copyWith(photos: newPhotos);
  }

  void reset() {
    state = const RegistrationState();
  }
}

final registrationProvider = StateNotifierProvider<RegistrationNotifier, RegistrationState>((ref) {
  return RegistrationNotifier();
});