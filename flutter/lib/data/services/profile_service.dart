import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:syno_app/domain/entities/user.dart';

class ProfileService {
  final String _backendUrl;

  ProfileService(this._backendUrl);

  Future<List<Sex>> getGenders() async {
    final response = await http.get(Uri.parse('$_backendUrl/api/genders'));

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((json) => Sex.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load genders');
    }
  }

  Future<List<OrientationModel>> getOrientations() async {
    final response = await http.get(Uri.parse('$_backendUrl/api/orientations'));

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((json) => OrientationModel.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load orientations');
    }
  }

  Future<List<Hobby>> getHobbies() async {
    final response = await http.get(Uri.parse('$_backendUrl/api/hobbies'));

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((json) => Hobby.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load hobbies');
    }
  }
}