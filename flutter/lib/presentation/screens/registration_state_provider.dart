import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

class RegistrationState {
  final String email;
  final String password;

  RegistrationState({this.email = '', this.password = ''});
}

class RegistrationStateNotifier extends StateNotifier<RegistrationState> {
  RegistrationStateNotifier() : super(RegistrationState());

  void setCredentials(String email, String password) {
    state = RegistrationState(email: email, password: password);
  }
}

final registrationStateProvider = StateNotifierProvider<RegistrationStateNotifier, RegistrationState>((ref) {
  return RegistrationStateNotifier();
});