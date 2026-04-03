import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:syno_app/domain/entities/user.dart';
import 'package:syno_app/presentation/providers/auth_providers.dart';
import 'package:syno_app/domain/entities/profession_data.dart';

final professionServiceProvider = Provider<ProfessionService>((ref) {
  final backendUrl = ref.watch(backendUrlProvider);
  return ProfessionService(backendUrl);
});

class ProfessionService {
  final Dio _dio = Dio();
  final String _backendUrl;

  ProfessionService(this._backendUrl);

  Future<List<ProfessionModel>> searchProfessions(String query) async {
    final url = '$_backendUrl/api/professions/?q=$query';
    try {
      final response = await _dio.get(url);
      return (response.data as List).map((json) => ProfessionModel.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Failed to load professions: $e');
    }
  }
}