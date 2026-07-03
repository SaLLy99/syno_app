import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

class Sex {
  final int id;
  final String name;
   final String translationKey;
  Sex({required this.id, required this.name, required this.translationKey});
  factory Sex.fromJson(Map<String, dynamic> json) => Sex(
        id: json['id'],
        name: json['name'],
        translationKey: json['translation_key'],
      );
}


class StaticDataService {
  final String _baseUrl = 'http://10.0.2.2:8000';

  Future<List<Sex>> getSexes() async {
    final response = await http.get(Uri.parse('$_baseUrl/api/sexes/'));
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => Sex.fromJson(json)).toList();
    }
    throw Exception('Failed to load sexes');
  }

}

final sexesDataServiceProvider = Provider((ref) => StaticDataService());
final sexesProvider = FutureProvider((ref) => ref.watch(sexesDataServiceProvider).getSexes());
