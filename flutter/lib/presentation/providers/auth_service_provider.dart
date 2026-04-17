import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:syno_app/data/services/auth_service.dart';
import 'auth_providers.dart';

/// Provider for the [AuthService] instance.
///
/// It depends on [backendUrlProvider] to initialize the service with the correct API URL.
final authServiceProvider = Provider<AuthService>((ref) {
  final baseUrl = ref.watch(backendUrlProvider);
  return AuthService(baseUrl);
});