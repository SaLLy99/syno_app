import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syno_app/data/repositories/match_repository.dart';
import 'package:syno_app/data/services/matching_engine_service.dart';
import 'package:syno_app/domain/entities/match.dart';
import 'package:syno_app/domain/entities/user.dart';
import 'package:syno_app/domain/entities/user_preferences.dart';
import 'package:syno_app/presentation/providers/user_provider.dart';
import 'package:syno_app/presentation/providers/preferences_provider.dart';
import 'package:syno_app/presentation/providers/block_provider.dart';

final Provider<MatchRepository> matchRepositoryProvider =
  Provider<MatchRepository>((Ref ref) => MatchRepository());

final Provider<MatchingEngineService> matchingEngineProvider =
  Provider<MatchingEngineService>((Ref ref) => MatchingEngineService());

final FutureProvider<List<Match>> potentialMatchesProvider =
  FutureProvider<List<Match>>((Ref ref) async {
  try {
    final User? currentUser = ref.read(currentUserProvider).value;
    if (currentUser == null) {
      debugPrint('[potentialMatches] No current user');
      return <Match>[];
    }

    final DiscoverPreferences? preferences = ref.read(preferencesProvider).value;

    final List<User> allUsers = await ref.read(allUsersProvider.future);

    final List<Match> existingMatches =
    await ref.read(userMatchesProvider(currentUser.id.toString()).future);

    final MatchingEngineService matchingEngine = ref.read(matchingEngineProvider);
    final List<Match> potentialMatches = await matchingEngine.findPotentialMatches(currentUser, allUsers, preferences);
    debugPrint('[potentialMatches] ${allUsers.length} profiles -> ${potentialMatches.length} after engine');

    final List<User> blockedUsers = await ref.read(blockedUsersProvider.future);
    final Set<String> blockedIds = blockedUsers.map((User u) => u.userId.toString()).toSet();

    final List<Match> result = potentialMatches
      .where((Match pm) =>
        !existingMatches.any((Match em) => em.matchedUserId == pm.matchedUserId))
      .where((Match pm) => !blockedIds.contains(pm.matchedUserId.toString()))
      .where((Match pm) => !existingMatches.any(
        (Match em) => em.matchedUserId == pm.matchedUserId && 
        (em.status == MatchStatus.hidden || em.status == MatchStatus.saved)))
      .toList();

    debugPrint('[potentialMatches] ${result.length} final matches');
    return result;
  } catch (e, st) {
    debugPrint('[potentialMatches] ERROR: $e');
    debugPrint('[potentialMatches] Stack: $st');
    return <Match>[];
  }
});

final userMatchesProvider =
    FutureProvider.family<List<Match>, String>((Ref ref, String userId) async {
  final MatchRepository repository = ref.watch(matchRepositoryProvider);
  return repository.getMatches(userId);
});

final acceptedMatchesProvider =
    FutureProvider.family<List<Match>, String>((Ref ref, String userId) async {
  final MatchRepository repository = ref.watch(matchRepositoryProvider);
  return repository.getAcceptedMatches(userId);
});

final Provider<MatchActions> matchActionsProvider =
    Provider<MatchActions>((Ref ref) => MatchActions(ref));

class ChatListItem {
  final int matchId;
  final int matchedUserId;
  final String? matchedName;
  final String? matchedPhotoUrl;
  final String? lastMessage;
  final DateTime? lastMessageAt;
  final bool isRead;

  ChatListItem({
    required this.matchId,
    required this.matchedUserId,
    this.matchedName,
    this.matchedPhotoUrl,
    this.lastMessage,
    this.lastMessageAt,
    this.isRead = true,
  });
}

final FutureProvider<List<ChatListItem>> chatsFromBackendProvider =
  FutureProvider<List<ChatListItem>>((Ref ref) async {
  try {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? token = prefs.getString('auth_token');
    final String? baseUrl = prefs.getString('backend_url');
    if (token == null || baseUrl == null) return <ChatListItem>[];

    final response = await Dio().get(
      '$baseUrl/api/chats',
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    if (response.statusCode == 200) {
      final List<dynamic> data = response.data as List<dynamic>;
      return data.map((json) => ChatListItem(
        matchId: json['match_id'] as int,
        matchedUserId: json['matched_user_id'] as int,
        matchedName: json['matched_profile']?['name'] as String?,
        matchedPhotoUrl: json['matched_profile']?['photo_url'] as String?,
        lastMessage: json['last_message'] as String?,
        lastMessageAt: json['last_message_at'] != null ? DateTime.tryParse(json['last_message_at'] as String) : null,
        isRead: json['is_read'] as bool? ?? true,
      )).toList();
    }
  } catch (e) {
    debugPrint('[chatsFromBackend] Error: $e');
  }
  return <ChatListItem>[];
});

class BackendMatchItem {
  final int matchId;
  final int matchedUserId;
  final String status;
  final int? compatibilityScore;
  final String? matchedName;
  final String? matchedPhotoUrl;

  BackendMatchItem({
    required this.matchId,
    required this.matchedUserId,
    required this.status,
    this.compatibilityScore,
    this.matchedName,
    this.matchedPhotoUrl,
  });
}

final FutureProvider<List<BackendMatchItem>> matchesFromBackendProvider =
  FutureProvider<List<BackendMatchItem>>((Ref ref) async {
  try {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? token = prefs.getString('auth_token');
    final String? baseUrl = prefs.getString('backend_url');
    if (token == null || baseUrl == null) return <BackendMatchItem>[];

    final response = await Dio().get(
      '$baseUrl/api/matches',
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    if (response.statusCode == 200) {
      final List<dynamic> data = response.data as List<dynamic>;
      
      Map<int, dynamic> profileMap = {};
      try {
        final userResp = await Dio().get(
          '$baseUrl/api/discover',
          options: Options(headers: {'Authorization': 'Bearer $token'}),
        );
        if (userResp.statusCode == 200) {
          final profiles = userResp.data as List<dynamic>;
          for (final p in profiles) {
            profileMap[p['user_id'] as int] = p;
          }
        }
      } catch (_) {}

      final List<BackendMatchItem> matches = [];
      for (final json in data) {
        final matchedUserId = json['matched_user_id'] as int;
        final profile = profileMap[matchedUserId];
        String? name;
        String? photoUrl;
        if (profile != null) {
          name = profile['name'] as String?;
          final photos = profile['photos'] as List<dynamic>?;
          if (photos != null && photos.isNotEmpty) {
            photoUrl = '/api/photos/${photos.first['id']}';
          }
        }
        matches.add(BackendMatchItem(
          matchId: json['id'] as int,
          matchedUserId: matchedUserId,
          status: json['status'] as String,
          compatibilityScore: json['compatibility_score'] as int?,
          matchedName: name,
          matchedPhotoUrl: photoUrl,
        ));
      }
      return matches;
    }
  } catch (e) {
    debugPrint('[matchesFromBackend] Error: $e');
  }
  return <BackendMatchItem>[];
});

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

  Future<void> passMatch(Match match) async {
    final MatchRepository repository = ref.read(matchRepositoryProvider);
    final User? currentUser = ref.read(currentUserProvider).value;
    if (currentUser == null) return;

    final List<Match> existingMatches = await repository.getMatches(currentUser.id.toString());
    existingMatches.add(match);
    await repository.saveMatches(existingMatches);
    await repository.saveMatchToBackend(match);

    ref.invalidate(userMatchesProvider(currentUser.id.toString()));
    ref.invalidate(potentialMatchesProvider);
  }
 
  Future<bool> saveMatch(Match match) async {
    final MatchRepository repository = ref.read(matchRepositoryProvider);
    final User? currentUser = ref.read(currentUserProvider).value;
    if (currentUser == null) return false;

    final List<Match> existingMatches = await repository.getMatches(currentUser.id.toString());
    existingMatches.add(match);
    await repository.saveMatches(existingMatches);

    await repository.saveMatchToBackend(match);

    final bool isMutual = await repository.checkMutualMatch(match.matchedUserId);

    ref.invalidate(userMatchesProvider(currentUser.id.toString()));
    ref.invalidate(acceptedMatchesProvider(currentUser.id.toString()));
    ref.invalidate(potentialMatchesProvider);
    ref.invalidate(chatsFromBackendProvider);
    ref.invalidate(incomingLikesProvider);
    ref.invalidate(likedUserIdsProvider);
    return isMutual;
  }

  Future<bool> acceptIncomingLike(int matchId) async {
    final MatchRepository repository = ref.read(matchRepositoryProvider);
    final result = await repository.acceptIncomingLike(matchId);
    ref.invalidate(incomingLikesProvider);
    ref.invalidate(likedUserIdsProvider);
    ref.invalidate(chatsFromBackendProvider);
    ref.invalidate(potentialMatchesProvider);
    return result != null;
  }

  Future<void> declineIncomingLike(int matchId) async {
    final MatchRepository repository = ref.read(matchRepositoryProvider);
    await repository.declineIncomingLike(matchId);
    ref.invalidate(incomingLikesProvider);
    ref.invalidate(likedUserIdsProvider);
  }
}

class IncomingLike {
  final int matchId;
  final int userId;
  final int? compatibilityScore;
  final DateTime? createdAt;
  final String? name;
  final String? lastName;
  final String? bio;
  final String? photoUrl;
  final String? birthDate;
  final String? locationName;
  final String? sexName;

  IncomingLike({
    required this.matchId,
    required this.userId,
    this.compatibilityScore,
    this.createdAt,
    this.name,
    this.lastName,
    this.bio,
    this.photoUrl,
    this.birthDate,
    this.locationName,
    this.sexName,
  });
}

final FutureProvider<List<IncomingLike>> incomingLikesProvider =
  FutureProvider<List<IncomingLike>>((Ref ref) async {
  try {
    final MatchRepository repository = ref.read(matchRepositoryProvider);
    final List<Map<String, dynamic>> rawLikes = await repository.getReceivedLikes();
    return rawLikes.map((json) {
      final profile = json['profile'] as Map<String, dynamic>?;
      final photoUrl = profile?['photo_url'] as String?;
      final location = profile?['location'] as Map<String, dynamic>?;
      final sex = profile?['sex'] as Map<String, dynamic>?;
      return IncomingLike(
        matchId: json['match_id'] as int,
        userId: json['user_id'] as int,
        compatibilityScore: json['compatibility_score'] as int?,
        createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'] as String) : null,
        name: profile?['name'] as String?,
        lastName: profile?['last_name'] as String?,
        bio: profile?['bio'] as String?,
        photoUrl: photoUrl,
        birthDate: profile?['birth_date'] as String?,
        locationName: location?['name'] as String?,
        sexName: sex?['name'] as String?,
      );
    }).toList();
  } catch (e) {
    debugPrint('[incomingLikes] Error: $e');
    return <IncomingLike>[];
  }
});

final FutureProvider<Set<int>> likedUserIdsProvider =
  FutureProvider<Set<int>>((Ref ref) async {
  try {
    final List<IncomingLike> likes = await ref.read(incomingLikesProvider.future);
    return likes.map((IncomingLike l) => l.userId).toSet();
  } catch (e) {
    return <int>{};
  }
});
