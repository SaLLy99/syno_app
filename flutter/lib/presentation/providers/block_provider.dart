import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:syno_app/data/repositories/block_repository.dart';
import 'package:syno_app/data/services/user_service.dart';
import 'package:syno_app/domain/entities/user.dart';
import 'package:syno_app/presentation/providers/user_provider.dart';


final Provider<BlockRepository> blockRepositoryProvider = Provider((Ref ref) => BlockRepository());

final FutureProvider<List<User>> blockedUsersProvider = FutureProvider<List<User>>((Ref ref) async {
  final UserService userService = ref.watch(userServiceProvider);
  try {
    return await userService.fetchBlockedUsers();
  } catch (e) {
    debugPrint('[blockedUsersProvider] Error: $e');
    return <User>[];
  }
});

// Convenience: whether the given target user is blocked by current user
final FutureProviderFamily<bool, String> isUserBlockedProvider = FutureProvider.family<bool, String>((Ref ref, String targetUserId) async {
  // Watch the provider to get the AsyncValue state.
  final AsyncValue<User?> asyncCurrentUser = ref.watch(currentUserProvider);

  final User? currentUser = asyncCurrentUser.value;
  if (currentUser == null) return false; // Not logged in or still loading
  final List<User> blocked = await ref.watch(blockedUsersProvider.future);
  return blocked.any((User u) => u.userId.toString() == targetUserId);
});

final Provider<BlockActions> blockActionsProvider = Provider((Ref ref) => BlockActions(ref));

class BlockActions {
  final Ref ref;
  BlockActions(this.ref);

  Future<void> block(String targetUserId) async {
    final User? currentUser = ref.read(currentUserProvider).value;
    if (currentUser == null) return;
    final BlockRepository repo = ref.read(blockRepositoryProvider);
    await repo.blockUser(currentUserId: currentUser.id.toString(), targetUserId: targetUserId);
    // Invalidate related providers
    ref.invalidate(blockedUsersProvider);
  }

  Future<void> unblock(String targetUserId) async {
    final User? currentUser = ref.read(currentUserProvider).value;
    if (currentUser == null) return;
    final BlockRepository repo = ref.read(blockRepositoryProvider);
    await repo.unblockUser(currentUserId: currentUser.id.toString(), targetUserId: targetUserId);
    // Invalidate related providers
    ref.invalidate(blockedUsersProvider);
  }
}
