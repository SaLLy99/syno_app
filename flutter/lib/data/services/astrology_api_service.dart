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

  /// Checks if a user has sufficient birth data for synastry calculation.
  static bool hasBirthData(User user) {
    return user.birthDate != null && user.location != null;
  }

  /// Returns a description of what birth data is missing for a user.
  static String? getMissingBirthDataInfo(User user) {
    final List<String> missing = [];
    if (user.birthDate == null) missing.add('birth date');
    if (user.location == null) missing.add('birth location');
    if (missing.isEmpty) return null;
    return 'Missing ${missing.join(" and ")}';
  }

  /// Full display name ("First Last") so the backend can address people
  /// by name instead of "Person A"/"Person B".
  static String _displayName(User user) {
    final first = (user.name ?? '').trim();
    final last = (user.lastName ?? '').trim();
    return '$first $last'.trim();
  }

  Future<Map<String, dynamic>?> _buildBirthData(User user) async {
    if (user.birthDate == null) {
      debugPrint('[AstrologyApi][BIRTH_DATA] ERROR: Missing birth date for ${user.name}');
      return null;
    }

    final String birthDate = '${user.birthDate!.year.toString().padLeft(4, '0')}-${user.birthDate!.month.toString().padLeft(2, '0')}-${user.birthDate!.day.toString().padLeft(2, '0')}';
    final String birthTime = user.birthTime ?? '12:00';

    double? latitude = user.location?.latitude;
    double? longitude = user.location?.longitude;
    String timezone = user.location?.timezone ?? 'UTC';
    String? locationName = user.location?.name;

    debugPrint('[AstrologyApi][BIRTH_DATA] ${user.name}: date=$birthDate, time=$birthTime, lat=$latitude, lon=$longitude, tz=$timezone, loc=$locationName');

    if (latitude == null || longitude == null) {
      debugPrint('[AstrologyApi][BIRTH_DATA] WARNING: lat/lon is NULL for ${user.name}, attempting Nominatim resolve...');
      if (locationName != null && locationName.isNotEmpty) {
        final resolved = await _resolveFromNominatim(locationName, timezone: timezone);
        if (resolved != null) {
          latitude = resolved['latitude'];
          longitude = resolved['longitude'];
          timezone = resolved['timezone'] ?? timezone;
          debugPrint('[AstrologyApi][BIRTH_DATA] Nominatim resolved: lat=$latitude, lon=$longitude, tz=$timezone');
        }
      }

      if (latitude == null || longitude == null) {
        debugPrint('[AstrologyApi][BIRTH_DATA] CRITICAL: Could not resolve lat/lon for ${user.name}, using DEFAULT Tbilisi coordinates');
        latitude = latitude ?? 41.7151;
        longitude = longitude ?? 44.8271;
        timezone = timezone == 'UTC' ? 'Asia/Tbilisi' : timezone;
        locationName = locationName ?? 'Tbilisi';
      }
    }

    if (timezone == 'UTC' || timezone.isEmpty) {
      debugPrint('[AstrologyApi][BIRTH_DATA] WARNING: timezone was UTC/empty, forcing Asia/Tbilisi');
      timezone = 'Asia/Tbilisi';
    }

    debugPrint('[AstrologyApi][BIRTH_DATA] FINAL: date=$birthDate, time=$birthTime, lat=$latitude, lon=$longitude, tz=$timezone, loc=$locationName');

    return {
      'birth_date': birthDate,
      'birth_time': birthTime,
      'timezone': timezone,
      'latitude': latitude,
      'longitude': longitude,
      'location_name': locationName,
    };
  }

  Future<Map<String, dynamic>?> _resolveFromNominatim(String locationName, {String? timezone}) async {
    try {
      var url = '$_backendUrl/api/locations/resolve?q=${Uri.encodeComponent(locationName)}';
      if (timezone != null && timezone.isNotEmpty) {
        url += '&timezone=${Uri.encodeComponent(timezone)}';
      }
      final resp = await http.get(Uri.parse(url));
      if (resp.statusCode == 200) {
        return json.decode(resp.body);
      }
      debugPrint('[AstrologyApi] Nominatim resolve returned ${resp.statusCode}');
      return null;
    } catch (e) {
      debugPrint('[AstrologyApi] Nominatim resolve error: $e');
      return null;
    }
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
      debugPrint('[AstrologyApi][CACHE HIT] getChart: user=${user.name}, key=$cacheKey');
      return _chartCache[cacheKey];
    }

    debugPrint('[AstrologyApi][REQUEST] getChart: user=${user.name}, birthDate=${user.birthDate}, birthTime=${user.birthTime}, lat=${user.location?.latitude}, lon=${user.location?.longitude}, tz=${user.location?.timezone}, system=$system');

    final token = await _getToken();
    if (token == null) {
      debugPrint('[AstrologyApi][ERROR] No auth token for getChart');
      return null;
    }

    final birthData = await _buildBirthData(user);
    if (birthData == null) {
      debugPrint('[AstrologyApi][ERROR] getChart: _buildBirthData returned null for ${user.name}');
      return null;
    }

    debugPrint('[AstrologyApi][REQUEST] getChart: sending POST to /api/astrology/chart with birth_data=$birthData');
    final url = Uri.parse('$_backendUrl/api/astrology/chart');
    final body = json.encode({
      'birth_data': birthData,
      'system': system,
    });

    try {
      final response = await http.post(url, headers: _headers(token), body: body).timeout(const Duration(seconds: 30));
      debugPrint('[AstrologyApi][RESPONSE] getChart: status=${response.statusCode}, bodyLength=${response.body.length}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final chart = NatalChart.fromWesternChartResponse(data);
        _chartCache[cacheKey] = chart;
        debugPrint('[AstrologyApi][SUCCESS] getChart: sun=${chart.getSunSign()}, moon=${chart.getMoonSign()}, rising=${chart.getAscendantSign()}, planets=${chart.getPlanetSigns().length}');
        return chart;
      } else {
        debugPrint('[AstrologyApi][FAILED] getChart: ${response.statusCode} - ${response.body.substring(0, response.body.length.clamp(0, 300))}');
        return null;
      }
    } catch (e) {
      debugPrint('[AstrologyApi][EXCEPTION] getChart: $e');
      return null;
    }
  }

  Future<SynastryData?> getSynastry(User user1, User user2) async {
    final cacheKey = _synastryCacheKey(user1, user2);
    if (_synastryCache.containsKey(cacheKey)) {
      debugPrint('[AstrologyApi][CACHE HIT] getSynastry: user1=${user1.name}, user2=${user2.name}, key=$cacheKey');
      return _synastryCache[cacheKey];
    }

    debugPrint('[AstrologyApi][REQUEST] getSynastry: user1=${user1.name} (birthDate=${user1.birthDate}, lat=${user1.location?.latitude}, lon=${user1.location?.longitude}), user2=${user2.name} (birthDate=${user2.birthDate}, lat=${user2.location?.latitude}, lon=${user2.location?.longitude})');

    final token = await _getToken();
    if (token == null) {
      debugPrint('[AstrologyApi][ERROR] No auth token for getSynastry');
      return null;
    }

    final birthData1 = await _buildBirthData(user1);
    final birthData2 = await _buildBirthData(user2);
    if (birthData1 == null || birthData2 == null) {
      debugPrint('[AstrologyApi][ERROR] getSynastry: _buildBirthData returned null - person_a=${birthData1 != null}, person_b=${birthData2 != null}');
      return null;
    }

    debugPrint('[AstrologyApi][REQUEST] getSynastry: sending POST to /api/astrology/interpretation with person_a=$birthData1, person_b=$birthData2');
    final url = Uri.parse('$_backendUrl/api/astrology/interpretation');
    final body = json.encode({
      'person_a': birthData1,
      'person_b': birthData2,
      'person_a_name': _displayName(user1),
      'person_b_name': _displayName(user2),
    });

    try {
      final response = await http.post(url, headers: _headers(token), body: body).timeout(const Duration(seconds: 60));
      debugPrint('[AstrologyApi][RESPONSE] getSynastry: status=${response.statusCode}, bodyLength=${response.body.length}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final synastry = SynastryData.fromCompatibilityResponse(data);
        _synastryCache[cacheKey] = synastry;
        debugPrint('[AstrologyApi][SUCCESS] getSynastry: overall=${synastry.overallScore}, moon=${synastry.moonScore}, venus=${synastry.venusMarsScore}, communication=${synastry.communicationScore}, emotional=${synastry.emotionalScore}, aspects=${synastry.detailedAspects.length}, aiUsed=${synastry.aiUsed}');
        debugPrint('[AstrologyApi][SUCCESS] getSynastry RAW SCORES: moon=${synastry.moonScore}, mercury=${synastry.mercuryScore}, venusMars=${synastry.venusMarsScore}, nodes=${synastry.nodesScore}, saturn=${synastry.saturnScore}');
        debugPrint('[AstrologyApi][SUCCESS] getSynastry DIMENSIONS: ${synastry.dimensionScores}');
        debugPrint('[AstrologyApi][SUCCESS] getSynastry ASPECTS: ${synastry.detailedAspects.map((a) => '${a.planet1}-${a.planet2} ${a.aspectType} orb=${a.orb?.toStringAsFixed(1)} score=${a.score.toStringAsFixed(0)}% harm=${a.isHarmonious}').join(' | ')}');
        debugPrint('[AstrologyApi][SUCCESS] getSynastry STRENGTHS: ${synastry.strengths}');
        debugPrint('[AstrologyApi][SUCCESS] getSynastry CHALLENGES: ${synastry.challenges}');
        return synastry;
      } else {
        debugPrint('[AstrologyApi][FAILED] getSynastry: ${response.statusCode} - ${response.body.substring(0, response.body.length.clamp(0, 300))}');
        return null;
      }
    } catch (e) {
      debugPrint('[AstrologyApi][EXCEPTION] getSynastry: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> getReport(User user1, User user2) async {
    final cacheKey = _synastryCacheKey(user1, user2);
    if (_reportCache.containsKey(cacheKey)) {
      debugPrint('[AstrologyApi][CACHE HIT] getReport: user1=${user1.name}, user2=${user2.name}, key=$cacheKey');
      return _reportCache[cacheKey];
    }

    debugPrint('[AstrologyApi][REQUEST] getReport: user1=${user1.name}, user2=${user2.name}');

    final token = await _getToken();
    if (token == null) {
      debugPrint('[AstrologyApi][ERROR] No auth token for getReport');
      return null;
    }

    final birthData1 = await _buildBirthData(user1);
    final birthData2 = await _buildBirthData(user2);
    if (birthData1 == null || birthData2 == null) {
      debugPrint('[AstrologyApi][ERROR] getReport: _buildBirthData returned null - person_a=${birthData1 != null}, person_b=${birthData2 != null}');
      return null;
    }

    debugPrint('[AstrologyApi][REQUEST] getReport: sending POST to /api/astrology/report');
    final url = Uri.parse('$_backendUrl/api/astrology/report');
    final body = json.encode({
      'person_a': birthData1,
      'person_b': birthData2,
      'person_a_name': _displayName(user1),
      'person_b_name': _displayName(user2),
    });

    try {
      final response = await http.post(url, headers: _headers(token), body: body).timeout(const Duration(seconds: 60));
      debugPrint('[AstrologyApi][RESPONSE] getReport: status=${response.statusCode}, bodyLength=${response.body.length}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        _reportCache[cacheKey] = data;
        debugPrint('[AstrologyApi][SUCCESS] getReport: keys=${data.keys.toList()}');
        return data;
      } else {
        debugPrint('[AstrologyApi][FAILED] getReport: ${response.statusCode} - ${response.body.substring(0, response.body.length.clamp(0, 300))}');
        return null;
      }
    } catch (e) {
      debugPrint('[AstrologyApi][EXCEPTION] getReport: $e');
      return null;
    }
  }
}
