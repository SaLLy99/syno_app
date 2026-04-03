import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:syno_app/data/repositories/block_repository.dart';
import 'package:syno_app/domain/entities/user.dart';
import 'package:syno_app/presentation/providers/user_provider.dart';


final Provider<BlockRepository> blockRepositoryProvider = Provider((Ref ref) => BlockRepository());

// Returns a list of blocked User objects for the current authenticated user
final blockedUsersProvider = FutureProvider<List<User>>((ref) async {
  final userService = ref.watch(userServiceProvider);
  return userService.fetchBlockedUsers();
});

// Convenience: whether the given target user is blocked by current user
final isUserBlockedProvider = FutureProvider.family<bool, String>((ref, targetUserId) async {
  // Watch the provider to get the AsyncValue state.
  final asyncCurrentUser = ref.watch(currentUserProvider);

  final User? currentUser = asyncCurrentUser.value;
  if (currentUser == null) return false; // Not logged in or still loading
  final List<User> blocked = await ref.watch(blockedUsersProvider.future);
  return blocked.any((u) => u.userId.toString() == targetUserId);
});

final Provider<BlockActions> blockActionsProvider = Provider((Ref ref) => BlockActions(ref));

class BlockActions {
  final Ref ref;
  BlockActions(this.ref);

  Future<void> block(String targetUserId) async {
    final User? currentUser = ref.read(currentUserProvider).value;
    if (currentUser == null) return;
    final repo = ref.read(blockRepositoryProvider);
    await repo.blockUser(currentUserId: currentUser.id.toString(), targetUserId: targetUserId);
    // Invalidate related providers
    ref.invalidate(blockedUsersProvider);
  }

  Future<void> unblock(String targetUserId) async {
    final User? currentUser = ref.read(currentUserProvider).value;
    if (currentUser == null) return;
    final repo = ref.read(blockRepositoryProvider);
    await repo.unblockUser(currentUserId: currentUser.id.toString(), targetUserId: targetUserId);
    // Invalidate related providers
    ref.invalidate(blockedUsersProvider);
  }
}
