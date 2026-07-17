import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod/src/providers/future_provider.dart';
import 'package:syno_app/data/services/location_service.dart';
import 'package:syno_app/domain/entities/location_item.dart';
import 'package:syno_app/presentation/providers/auth_providers.dart';

/// Provider for the [LocationService].
final Provider<LocationService> locationServiceProvider = Provider<LocationService>((Ref ref) {
  final String backendUrl = ref.watch(backendUrlProvider);
  return LocationService(backendUrl);
});

/// A provider that searches for locations (cities and countries) based on a query.
/// It uses a family to accept the search string as a parameter.
final FutureProviderFamily<List<LocationItem>, String> locationSearchProvider =
    FutureProvider.family<List<LocationItem>, String>((Ref ref, String query) async {
  return ref.watch(locationServiceProvider).searchLocations(query);
});
