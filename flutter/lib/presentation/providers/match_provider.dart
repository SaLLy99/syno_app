import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:syno_app/data/repositories/match_repository.dart';
import 'package:syno_app/data/services/matching_engine_service.dart';
import 'package:syno_app/domain/entities/match.dart';
import 'package:syno_app/domain/entities/user.dart';
import 'package:syno_app/presentation/providers/user_provider.dart';
import 'package:syno_app/presentation/providers/block_provider.dart';

final Provider<MatchRepository> matchRepositoryProvider =
  Provider<MatchRepository>((ref) => MatchRepository());

final Provider<MatchingEngineService> matchingEngineProvider =
  Provider<MatchingEngineService>((ref) => MatchingEngineService());

final FutureProvider<List<Match>> potentialMatchesProvider =
  FutureProvider<List<Match>>((ref) async {
  final currentUser = await ref.watch(currentUserProvider).value;
  if (currentUser == null) return <Match>[];

    final allUsers = await ref.watch(allUsersProvider.future);
    final List<User> allUsersList = (allUsers as List<User>?) ?? <User>[];
    final List<Match> existingMatches =
    await ref.watch(userMatchesProvider(currentUser.id.toString()).future);

  final MatchingEngineService matchingEngine = ref.watch(matchingEngineProvider);
    final dynamic potentialRaw =
      await matchingEngine.findPotentialMatches(currentUser, allUsersList);

  final List<Match> potentialMatches =
    (potentialRaw is Iterable) ? potentialRaw.cast<Match>().toList() : <Match>[];

  // Exclude already matched and blocked users
  final List<User> blockedUsers = await ref.watch(blockedUsersProvider.future);
  final Set<String> blockedIds = blockedUsers.map((u) => u.userId.toString()).toSet();

  return potentialMatches
    .where((pm) =>
      !existingMatches.any((em) => em.matchedUserId == pm.matchedUserId))
    .where((pm) => !blockedIds.contains(pm.matchedUserId.toString()))
    .toList();
});

final userMatchesProvider =
    FutureProvider.family<List<Match>, String>((ref, String userId) async {
  final MatchRepository repository = ref.watch(matchRepositoryProvider);
  return repository.getMatches(userId);
});

final acceptedMatchesProvider =
    FutureProvider.family<List<Match>, String>((ref, String userId) async {
  final MatchRepository repository = ref.watch(matchRepositoryProvider);
  return repository.getAcceptedMatches(userId);
});

final Provider<MatchActions> matchActionsProvider =
    Provider<MatchActions>((ref) => MatchActions(ref));

class MatchActions {
  final Ref ref;
  MatchActions(this.ref);

  Future<void> acceptMatch(Match match) async {
    final MatchRepository repository = ref.read(matchRepositoryProvider);
    await repository.updateMatchStatus(match.id, MatchStatus.accepted);
 
    final User? currentUser = ref.read(currentUserProvider).value;
    if (currentUser != null) {
      ref.invalidate(userMatchesProvider(currentUser.id.toString()));
      ref.invalidate(acceptedMatchesProvider(currentUser.id.toString()));
      ref.invalidate(potentialMatchesProvider);
    }
  }
 
  Future<void> declineMatch(Match match) async {
    final MatchRepository repository = ref.read(matchRepositoryProvider);
    await repository.updateMatchStatus(match.id, MatchStatus.declined);
 
    final User? currentUser = ref.read(currentUserProvider).value;
    if (currentUser != null) {
      ref.invalidate(userMatchesProvider(currentUser.id.toString()));
      ref.invalidate(potentialMatchesProvider);
    }
  }
 
  Future<void> saveMatch(Match match) async {
    final MatchRepository repository = ref.read(matchRepositoryProvider);
    final User? currentUser = ref.read(currentUserProvider).value;
    if (currentUser == null) return;
 
    final List<Match> existingMatches = await repository.getMatches(currentUser.id.toString());
    existingMatches.add(match);
    await repository.saveMatches(existingMatches);
 
    ref.invalidate(userMatchesProvider(currentUser.id.toString()));
    ref.invalidate(potentialMatchesProvider);
  }
}