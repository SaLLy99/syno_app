import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:syno_app/domain/entities/user.dart';
import 'package:syno_app/presentation/providers/auth_providers.dart';
import 'package:syno_app/domain/entities/education_data.dart';

final educationServiceProvider = Provider<EducationService>((ref) {
  final backendUrl = ref.watch(backendUrlProvider);
  return EducationService(backendUrl);
});

class EducationService {
  final Dio _dio = Dio();
  final String _backendUrl;

  EducationService(this._backendUrl);

  Future<List<EducationModel>> searchEducations(String query) async {
    final url = '$_backendUrl/api/educations/?q=$query';
    try {
      final response = await _dio.get(url);
      return (response.data as List).map((json) => EducationModel.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Failed to load educations: $e');
    }
  }
}