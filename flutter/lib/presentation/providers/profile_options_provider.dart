import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:syno_app/domain/entities/user.dart';
import 'package:syno_app/presentation/providers/auth_providers.dart';

/// 1. Data Model
class ProfileOptions {
  final List<Sex> sexes;
  final List<OrientationModel> orientations;
  final List<Hobby> hobbies;
  final List<ProfessionModel> professions;
  final List<EducationModel> educations;

  ProfileOptions({
    required this.sexes,
    required this.orientations,
    required this.hobbies,
    required this.professions,
    required this.educations,
  });

  factory ProfileOptions.empty() => ProfileOptions(
        sexes: <Sex>[],
        orientations: <OrientationModel>[],
        hobbies: <Hobby>[],
        professions: <ProfessionModel>[],
        educations: <EducationModel>[],
      );
}

/// 2. Dio Provider
/// Centralizing Dio allows you to add Interceptors for Auth tokens later.
final Provider<Dio> dioProvider = Provider<Dio>((Ref ref) {
  return Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 5),
    receiveTimeout: const Duration(seconds: 3),
  ));
});

/// 3. Profile Options Provider
final FutureProvider<ProfileOptions> profileOptionsProvider = FutureProvider.autoDispose<ProfileOptions>((Ref ref) async {
  final String backendUrl = ref.watch(backendUrlProvider);
  final Dio dio = ref.watch(dioProvider);

  try {
    // Future.wait runs all requests in parallel for maximum speed.
    // If one fails, the whole FutureProvider enters the 'error' state.
    final List<Response> responses = await Future.wait(<Future<Response>>[
      dio.get('$backendUrl/api/sexes/'),
      dio.get('$backendUrl/api/orientations/'),
      dio.get('$backendUrl/api/hobbies/'),
      dio.get('$backendUrl/api/professions/'),
      dio.get('$backendUrl/api/educations/'),
    ]);

    return ProfileOptions(
      // Mandatory fields: Assuming these must exist
      sexes: (responses[0].data as List)
          .map((json) => Sex.fromJson(json))
          .toList(),
      orientations: (responses[1].data as List)
          .map((json) => OrientationModel.fromJson(json))
          .toList(),

      // Optional fields: Using null-checks and empty list fallbacks (?? [])
      hobbies: (responses[2].data as List? ?? <dynamic>[])
          .map((json) => Hobby.fromJson(json))
          .toList(),
      professions: (responses[3].data as List? ?? <dynamic>[])
          .map((json) => ProfessionModel.fromJson(json))
          .toList(),
      educations: (responses[4].data as List? ?? <dynamic>[])
          .map((json) => EducationModel.fromJson(json))
          .toList(),
    );
  } on DioException catch (e) {
    // Specific error handling for network/server issues
    final errorMessage = e.response?.data?['message'] ?? e.message;
    throw Exception('Network Error: $errorMessage');
  } catch (e) {
    // Generic catch for mapping or logic errors
    throw Exception('Data Processing Error: $e');
  }
});