import 'package:flutter_riverpod/legacy.dart';

/// A notifier to manage a global loading state (e.g., for full-screen overlays).
class LoadingStateNotifier extends StateNotifier<bool> {
  // Initialize the state to `false` (not loading).
  LoadingStateNotifier() : super(false);

  /// Sets the loading state to `true`.
  void show() {
    if (!state) {
      state = true;
    }
  }

  /// Sets the loading state to `false`.
  void hide() {
    if (state) {
      state = false;
    }
  }
}

/// The provider for the [LoadingStateNotifier].
/// This allows the UI to watch the loading state and other providers to change it.
final loadingStateProvider = StateNotifierProvider<LoadingStateNotifier, bool>((ref) {
  return LoadingStateNotifier();
});