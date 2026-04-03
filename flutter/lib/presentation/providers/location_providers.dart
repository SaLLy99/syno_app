import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:syno_app/data/services/location_service.dart';
import 'package:syno_app/domain/entities/location_item.dart';
import 'package:syno_app/presentation/providers/auth_providers.dart';

/// Provider for the [LocationService].
final locationServiceProvider = Provider<LocationService>((ref) {
  final backendUrl = ref.watch(backendUrlProvider);
  return LocationService(backendUrl);
});

/// A provider that searches for locations (cities and countries) based on a query.
/// It uses a family to accept the search string as a parameter.
final locationSearchProvider =
    FutureProvider.family<List<LocationItem>, String>((ref, query) async {
  return ref.watch(locationServiceProvider).searchLocations(query);
});
