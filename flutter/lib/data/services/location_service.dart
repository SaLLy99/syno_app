import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:syno_app/domain/entities/location_item.dart';

/// A top-level function to parse and filter locations in a separate isolate.
List<LocationItem> _parseAndFilterLocations(String responseBody) {
  final List<dynamic> data = json.decode(responseBody);
  return data.map((json) => LocationItem.fromJson(json)).toList();
}

/// A service for fetching location data like countries and cities.
class LocationService {
  final String _backendUrl;

  LocationService(this._backendUrl);

  /// Fetches all available city locations.
  Future<List<LocationItem>> getAllLocations() async {
    final String urlString = '$_backendUrl/api/location/search';
    final Uri url = Uri.parse(urlString);
    final http.Response response = await http.get(url);

    if (response.statusCode == 200) {
      return compute(_parseAndFilterLocations, response.body);
    } else {
      throw Exception('Failed to load all locations');
    }
  }

  /// Searches for locations (countries and cities) from the unified endpoint.
  Future<List<LocationItem>> searchLocations(String pattern) async {
    String urlString = '$_backendUrl/api/location/search';
    
    if (pattern.isNotEmpty) {
      urlString += '?q=${Uri.encodeQueryComponent(pattern)}';
    }

    final Uri url = Uri.parse(urlString);
    final http.Response response = await http.get(url);

    if (response.statusCode == 200) {
      return compute(_parseAndFilterLocations, response.body);
    } else {
      throw Exception('Failed to search locations');
    }
  }
}