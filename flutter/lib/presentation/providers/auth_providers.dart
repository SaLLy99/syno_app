import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:syno_app/data/services/auth_service.dart';
import 'package:syno_app/data/services/user_service.dart';
import 'package:syno_app/domain/entities/user.dart';
import 'package:syno_app/presentation/providers/registration_provider.dart';
import 'package:syno_app/presentation/providers/user_provider.dart';


final backendUrlProvider = Provider<String>((ref) => throw UnimplementedError());


final authServiceProvider = Provider<AuthService>((ref) { 
  return AuthService(ref.watch(backendUrlProvider));
});


final userServiceProvider = Provider<UserService>((ref) {
  return UserService(ref.watch(backendUrlProvider));
});


class AuthNotifier extends AsyncNotifier<User?> {
  @override
  Future<User?> build() async {
    return null;
  }

  Future<void> login(String email, String password) async {
    state = const AsyncLoading();
    try {
      final authService = ref.read(authServiceProvider);
      await authService.login(email, password); 
      ref.invalidate(currentUserProvider); 
      state = const AsyncData(null); 
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<void> logOut() async {
    state = const AsyncLoading();
    try {
      final authService = ref.read(authServiceProvider);
      await authService.logOut();
      ref.invalidate(currentUserProvider); 
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<void> register(String email, String password) async {
    state = const AsyncLoading();
    try {
      final authService = ref.read(authServiceProvider);
      await authService.register(email, password);
      ref.invalidate(currentUserProvider);
      state = const AsyncData(null); 
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<void> checkEmailExists(String email) async {
     state = const AsyncLoading();
    try {
      final authService = ref.read(authServiceProvider);
      await authService.checkEmailExists(email);
      state = const AsyncData(null); 
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<void> deleteAccount() async {}

  Future<void> registerCompleteUser(RegistrationState regState) async {
    state = const AsyncLoading();
    try {
      final authService = ref.read(authServiceProvider);
      await authService.registerCompleteUser(regState);
      // DO NOT invalidate currentUserProvider here.
      // The calling screen (RegisterPhotosScreen) is responsible for manually
      // fetching the user profile, which prevents a navigation race condition.
      state = const AsyncData(null); 
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }
}
final authProvider = AsyncNotifierProvider<AuthNotifier, User?>(AuthNotifier.new);