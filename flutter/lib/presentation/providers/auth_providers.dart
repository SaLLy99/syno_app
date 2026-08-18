import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:syno_app/data/services/auth_service.dart';
import 'package:syno_app/data/services/user_service.dart';
import 'package:syno_app/domain/entities/user.dart';
import 'package:syno_app/presentation/providers/match_provider.dart';
import 'package:syno_app/presentation/providers/registration_provider.dart';
import 'package:syno_app/presentation/providers/user_provider.dart';
import 'package:syno_app/presentation/providers/websocket_provider.dart';


final Provider<String> backendUrlProvider = Provider<String>((Ref ref) => throw UnimplementedError());


final Provider<AuthService> authServiceProvider = Provider<AuthService>((Ref ref) { 
  return AuthService(ref.watch(backendUrlProvider));
});


final Provider<UserService> userServiceProvider = Provider<UserService>((Ref ref) {
  return UserService(
    ref.watch(backendUrlProvider),
    onUnauthorized: () {
      try {
        ref.read(authProvider.notifier).logOut();
      } catch (_) {}
    },
  );
});


class AuthNotifier extends AsyncNotifier<User?> {
  @override
  Future<User?> build() async {
    return null;
  }

  Future<void> login(String email, String password) async {
    state = const AsyncLoading();
    try {
      final AuthService authService = ref.read(authServiceProvider);
      await authService.login(email, password); 
      ref.invalidate(currentUserProvider);
      state = const AsyncData(null);
      _connectWebSocket();
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  void _connectWebSocket() {
    try {
      final wsService = ref.read(webSocketServiceProvider);
      wsService.connect();
    } catch (e) {
      // WebSocket connection is optional, don't fail login
    }
  }

  Future<void> logOut() async {
    state = const AsyncLoading();
    try {
      _disconnectWebSocket();
      final AuthService authService = ref.read(authServiceProvider);
      await authService.logOut();
      ref.read(registrationProvider.notifier).reset();
      ref.invalidate(currentUserProvider);
      ref.invalidate(allUsersProvider);
      ref.invalidate(potentialMatchesProvider);
      ref.invalidate(chatsFromBackendProvider);
      ref.invalidate(matchesFromBackendProvider);
      ref.invalidate(incomingLikesProvider);
      ref.invalidate(likedUserIdsProvider);
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  void _disconnectWebSocket() {
    try {
      final wsService = ref.read(webSocketServiceProvider);
      wsService.disconnect();
    } catch (e) {
      // Ignore disconnect errors
    }
  }

  Future<void> register(String email, String password) async {
    state = const AsyncLoading();
    try {
      final AuthService authService = ref.read(authServiceProvider);
      await authService.register(email, password);
      ref.invalidate(currentUserProvider);
      state = const AsyncData(null); 
      _connectWebSocket();
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<void> checkEmailExists(String email) async {
     state = const AsyncLoading();
    try {
      final AuthService authService = ref.read(authServiceProvider);
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
      final AuthService authService = ref.read(authServiceProvider);
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
final AsyncNotifierProvider<AuthNotifier, User?> authProvider = AsyncNotifierProvider<AuthNotifier, User?>(AuthNotifier.new);