import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syno_app/domain/entities/natal_chart.dart';
import 'package:syno_app/domain/entities/synastry_data.dart';
import 'package:syno_app/domain/entities/user.dart';

class AstrologyApiService {
  final String _backendUrl;

  AstrologyApiService(this._backendUrl);

  static final Map<String, NatalChart> _chartCache = {};
  static final Map<String, SynastryData> _synastryCache = {};
  static final Map<String, Map<String, dynamic>> _reportCache = {};

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  Map<String, String> _headers(String token) => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $token',
  };

  Map<String, dynamic> _buildBirthData(User user) {
    final String birthDate = user.birthDate != null
        ? '${user.birthDate!.year.toString().padLeft(4, '0')}-${user.birthDate!.month.toString().padLeft(2, '0')}-${user.birthDate!.day.toString().padLeft(2, '0')}'
        : '2000-01-01';
    final String birthTime = user.birthTime ?? '12:00';
    final String timezone = 'UTC';
    final double latitude = user.location?.latitude ?? 0.0;
    final double longitude = user.location?.longitude ?? 0.0;

    debugPrint('[AstrologyApi] Birth data: date=$birthDate, time=$birthTime, lat=$latitude, lon=$longitude, loc=${user.location?.name}');

    return {
      'birth_date': birthDate,
      'birth_time': birthTime,
      'timezone': timezone,
      'latitude': latitude,
      'longitude': longitude,
      'location_name': user.location?.name,
    };
  }

  String _chartCacheKey(User user, String system) {
    final birthDate = user.birthDate != null
        ? '${user.birthDate!.year}-${user.birthDate!.month}-${user.birthDate!.day}'
        : 'unknown';
    return '$birthDate|${user.birthTime}|${user.location?.latitude}|${user.location?.longitude}|$system';
  }

  String _synastryCacheKey(User user1, User user2) {
    final dates = [user1, user2].map((u) {
      final bd = u.birthDate != null
          ? '${u.birthDate!.year}-${u.birthDate!.month}-${u.birthDate!.day}'
          : 'unknown';
      return '$bd|${u.birthTime}|${u.location?.latitude}|${u.location?.longitude}';
    }).toList();
    dates.sort();
    return dates.join('||');
  }

  Future<NatalChart?> getChart(User user, {String system = 'western_tropical'}) async {
    final cacheKey = _chartCacheKey(user, system);
    if (_chartCache.containsKey(cacheKey)) {
      return _chartCache[cacheKey];
    }

    final token = await _getToken();
    if (token == null) {
      debugPrint('[AstrologyApi] No auth token');
      return null;
    }

    final url = Uri.parse('$_backendUrl/api/astrology/chart');
    final body = json.encode({
      'birth_data': _buildBirthData(user),
      'system': system,
    });

    try {
      final response = await http.post(url, headers: _headers(token), body: body).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final chart = NatalChart.fromWesternChartResponse(data);
        _chartCache[cacheKey] = chart;
        return chart;
      } else {
        debugPrint('[AstrologyApi] Chart failed: ${response.statusCode} ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('[AstrologyApi] Chart error: $e');
      return null;
    }
  }

  Future<SynastryData?> getSynastry(User user1, User user2) async {
    final cacheKey = _synastryCacheKey(user1, user2);
    if (_synastryCache.containsKey(cacheKey)) {
      return _synastryCache[cacheKey];
    }

    final token = await _getToken();
    if (token == null) {
      debugPrint('[AstrologyApi] No auth token');
      return null;
    }

    final url = Uri.parse('$_backendUrl/api/astrology/interpretation');
    final body = json.encode({
      'person_a': _buildBirthData(user1),
      'person_b': _buildBirthData(user2),
      'include_vedic': false,
    });

    try {
      final response = await http.post(url, headers: _headers(token), body: body).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final synastry = SynastryData.fromCompatibilityResponse(data);
        _synastryCache[cacheKey] = synastry;
        return synastry;
      } else {
        debugPrint('[AstrologyApi] Synastry failed: ${response.statusCode} ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('[AstrologyApi] Synastry error: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> getReport(User user1, User user2) async {
    final cacheKey = _synastryCacheKey(user1, user2);
    if (_reportCache.containsKey(cacheKey)) {
      return _reportCache[cacheKey];
    }

    final token = await _getToken();
    if (token == null) {
      debugPrint('[AstrologyApi] No auth token');
      return null;
    }

    final url = Uri.parse('$_backendUrl/api/astrology/report');
    final body = json.encode({
      'person_a': _buildBirthData(user1),
      'person_b': _buildBirthData(user2),
      'include_vedic': false,
    });

    try {
      final response = await http.post(url, headers: _headers(token), body: body).timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        _reportCache[cacheKey] = data;
        return data;
      } else {
        debugPrint('[AstrologyApi] Report failed: ${response.statusCode} ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('[AstrologyApi] Report error: $e');
      return null;
    }
  }
}
