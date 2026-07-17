import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:image_picker/image_picker.dart';


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
  final String? themeId;
  final String? backgroundColor;
  final String? accentColor;
  final String? layout;

  const ProfileData({
    this.name,
    this.lastName,
    this.height,
    this.birthDate,
    this.birthTime,
    this.locationId,
    this.sexId,
    this.orientationId,
    this.intentionIds = const <int>[],
    this.coreValueIds = const <int>[],
    this.bio,
    this.hobbyIds = const <int>[],
    this.professionIds = const <int>[],
    this.educationIds = const <int>[],
    // Theme preferences
    this.themeId,
    this.backgroundColor,
    this.accentColor,
    this.layout,
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
          : (map['intentions'] as List?)?.map((e) => e['id'] as int).toList() ?? <int>[],
      coreValueIds: map['core_value_ids'] != null
          ? List<int>.from(map['core_value_ids'])
          : (map['core_values'] as List?)?.map((e) => e['id'] as int).toList() ?? <int>[],
      bio: map['bio'] as String?,
      hobbyIds: map['hobby_ids'] != null
          ? List<int>.from(map['hobby_ids'])
          : (map['hobbies'] as List?)?.map((e) => e['id'] as int).toList() ?? <int>[],
      themeId: map['theme_id'] as String?,
      backgroundColor: map['background_color'] as String?,
      accentColor: map['accent_color'] as String?,
      professionIds: map['profession_ids'] != null
          ? List<int>.from(map['profession_ids'])
          : (map['professions'] as List?)?.map((e) => e['id'] as int).toList() ?? <int>[],
      educationIds: map['education_ids'] != null
          ? List<int>.from(map['education_ids'])
          : (map['educations'] as List?)?.map((e) => e['id'] as int).toList() ?? <int>[],
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
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
      'theme_id': themeId,
      'background_color': backgroundColor,
      'accent_color': accentColor,
    }..removeWhere((String key, value) => value == null || (value is List && value.isEmpty));
  }

  bool get isInitial => name == null || name!.isEmpty;
  
  toJson() {
    return toMap();

  }
}

class RegistrationState {
  final String email;
  final String password;
  final String phoneNumber;
  final ProfileData profileData;
  final List<XFile> photos;

  const RegistrationState({
    this.email = '',
    this.password = '',
    this.phoneNumber = '',
    this.profileData = const ProfileData(),
    this.photos = const <XFile>[],
  });

  // Used in main.dart to check if registration flow has started (Step 1 complete)
  Map<String, dynamic> get step1Data => <String, dynamic>{
    if (email.isNotEmpty) 'email': email,
    if (password.isNotEmpty) 'password': password,
    if (phoneNumber.isNotEmpty) 'phone_number': phoneNumber,
  };

  // Used in AuthService to get profile details (excluding core values/intentions which are handled separately)
  Map<String, dynamic> get step2Data => profileData.toMap();
  List<int> get coreValueIds => profileData.coreValueIds;
  List<int> get intentionIds => profileData.intentionIds;

  RegistrationState copyWith({
    String? email,
    String? password,
    String? phoneNumber,
    ProfileData? profileData,
    List<XFile>? photos,
  }) {
    return RegistrationState(
      email: email ?? this.email,
      password: password ?? this.password,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      profileData: profileData ?? this.profileData,
      photos: photos ?? this.photos,
    );
  }
  toJson(){
    return <String, dynamic>{
      'email': email,
      'password': password,
      'phone_number': phoneNumber,
      'profile_data': profileData.toJson(),
      'photos': photos.map((XFile file) => file.path).toList(),
    };
  }
}

class RegistrationNotifier extends StateNotifier<RegistrationState> {
  RegistrationNotifier() : super(const RegistrationState());

  void setCredentials(String email, String password) {
    state = state.copyWith(email: email, password: password);
  }

  void updateProfileData(Map<String, dynamic> data) {
    print('DEBUG: updateProfileData called with: $data');

    final Map<String, dynamic> currentMap = state.profileData.toMap();
    final Map<String, dynamic> mergedMap = <String, dynamic>{...currentMap, ...data};

    final ProfileData newProfile = ProfileData.fromMap(mergedMap);
    
    print('DEBUG: Merged ProfileData result: ${newProfile.toMap()}');

    state = state.copyWith(profileData: newProfile);
}

 void addPhotos(List<XFile> newPhotos) {
  state = state.copyWith(photos: <XFile>[...state.photos, ...newPhotos]);
 }

 void removePhotoAt(int index) {
  if (index >= 0 && index < state.photos.length) {
   final List<XFile> newPhotos = List<XFile>.from(state.photos);
   newPhotos.removeAt(index);
   state = state.copyWith(photos: newPhotos);
  }
 }

  void reorderPhotos(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= state.photos.length) return;
    
    final List<XFile> newPhotos = List<XFile>.from(state.photos);
    final XFile item = newPhotos.removeAt(oldIndex);
    
    if (newIndex > newPhotos.length) newIndex = newPhotos.length;
    if (newIndex < 0) newIndex = 0;

    newPhotos.insert(newIndex, item);
    state = state.copyWith(photos: newPhotos);
  }

  void reset() {
    state = const RegistrationState();
  }

  void updateStep1Data(Map<String, String> map) {
    state = state.copyWith(
      email: map.containsKey('email') ? map['email'] ?? '' : state.email,
      password: map.containsKey('password') ? map['password'] ?? '' : state.password,
      phoneNumber: map.containsKey('phone_number') ? map['phone_number'] ?? '' : state.phoneNumber,
    );
  }

  void updateStep2Data(Map<String, dynamic> map) {
    state = state.copyWith(profileData: ProfileData.fromMap(map));
  }
}

final StateNotifierProvider<RegistrationNotifier, RegistrationState> registrationProvider = StateNotifierProvider<RegistrationNotifier, RegistrationState>((Ref ref) {
  return RegistrationNotifier();
});