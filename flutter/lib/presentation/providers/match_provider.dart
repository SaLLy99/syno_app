import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syno_app/data/repositories/match_repository.dart';
import 'package:syno_app/domain/entities/match.dart';
import 'package:syno_app/domain/entities/synastry_data.dart';
import 'package:syno_app/domain/entities/user.dart';
import 'package:syno_app/presentation/providers/auth_providers.dart';
import 'package:syno_app/presentation/providers/user_provider.dart';
import 'package:syno_app/presentation/providers/block_provider.dart';
import 'package:syno_app/presentation/providers/app_mode_provider.dart';
import 'package:syno_app/domain/entities/app_mode.dart';

final Provider<MatchRepository> matchRepositoryProvider =
  Provider<MatchRepository>((Ref ref) => MatchRepository());

final FutureProvider<List<Match>> potentialMatchesProvider =
  FutureProvider<List<Match>>((Ref ref) async {
  try {
    final User? currentUser = ref.read(currentUserProvider).value;
    if (currentUser == null) {
      debugPrint('[potentialMatches] No current user');
      return <Match>[];
    }

    // Watch appModeProvider to re-fetch when mode changes
    ref.watch(appModeProvider);

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? token = prefs.getString('auth_token');
    final String? baseUrl = prefs.getString('backend_url');
    if (token == null || baseUrl == null) {
      debugPrint('[potentialMatches] No auth token or backend URL');
      return <Match>[];
    }

    final currentMode = ref.read(appModeProvider);
    final String mode = currentMode.value;

    debugPrint('[potentialMatches] Fetching from backend /api/discover/smart (mode=$mode)');
    final response = await Dio().get(
      '$baseUrl/api/discover/smart',
      queryParameters: {'mode': mode},
      options: Options(
        headers: {'Authorization': 'Bearer $token'},
        receiveTimeout: const Duration(seconds: 30),
      ),
    );

    if (response.statusCode != 200) {
      debugPrint('[potentialMatches] Backend returned ${response.statusCode}');
      return <Match>[];
    }

    final List<dynamic> data = response.data as List<dynamic>;
    debugPrint('[potentialMatches] Backend returned ${data.length} profiles');
    if (data.isNotEmpty) {
      final first = data[0] as Map<String, dynamic>;
      debugPrint('[potentialMatches] First profile: name=${first['name']}, birth_date=${first['birth_date']}, birth_time=${first['birth_time']}, location=${first['location']}, synastry_score=${first['synastry_score']}, compat=${first['compatibility_score']}');
    }

    final List<Match> potentialMatches = data.map((json) {
      final item = json as Map<String, dynamic>;

      final photos = (item['photos'] as List<dynamic>? ?? []).map((p) {
        final photo = p as Map<String, dynamic>;
        return Photo(
          id: photo['id'] as int,
          url: photo['url'] as String,
          isPrimary: photo['is_primary'] as bool? ?? false,
        );
      }).toList();

      final locationData = item['location'] as Map<String, dynamic>?;
      final sexData = item['sex'] as Map<String, dynamic>?;
      final orientationData = item['orientation'] as Map<String, dynamic>?;

      final User matchedUser = User(
        id: item['user_id'] as int,
        userId: item['user_id'] as int,
        name: item['name'] as String?,
        lastName: item['last_name'] as String?,
        bio: item['bio'] as String?,
        height: (item['height'] as num?)?.toDouble(),
        birthDate: item['birth_date'] != null ? DateTime.tryParse(item['birth_date'] as String) : null,
        birthTime: item['birth_time'] as String?,
        photos: photos,
        location: locationData != null ? Location(
          id: locationData['id'] as int,
          name: locationData['name'] as String? ?? '',
          translationKey: locationData['translation_key'] as String? ?? '',
          latitude: (locationData['latitude'] as num?)?.toDouble(),
          longitude: (locationData['longitude'] as num?)?.toDouble(),
        ) : null,
        sex: sexData != null ? Sex(id: sexData['id'] as int, name: sexData['name'] as String, translationKey: sexData['translation_key'] as String? ?? '') : null,
        orientation: orientationData != null ? OrientationModel(id: orientationData['id'] as int, name: orientationData['name'] as String, translationKey: orientationData['translation_key'] as String? ?? '') : null,
      );

      SynastryData? synastryData;
      final rawSynastryData = item['synastry_data'] as Map<String, dynamic>?;
      final topAspects = (rawSynastryData?['top_aspects'] as List<dynamic>?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          const <Map<String, dynamic>>[];
      if (rawSynastryData != null) {
        try {
          synastryData = SynastryData(
            moonScore: (rawSynastryData['dimensions']?['emotional'] as num?)?.toDouble() ?? 50.0,
            mercuryScore: (rawSynastryData['dimensions']?['communication'] as num?)?.toDouble() ?? 50.0,
            venusMarsScore: (rawSynastryData['dimensions']?['attraction'] as num?)?.toDouble() ?? 50.0,
            nodesScore: (rawSynastryData['dimensions']?['growth'] as num?)?.toDouble() ?? 50.0,
            saturnScore: (rawSynastryData['dimensions']?['stability'] as num?)?.toDouble() ?? 50.0,
            detailedAspects: _parseAspects(rawSynastryData['synastry']?['planet_aspects'] as List<dynamic>?),
            interpretation: (rawSynastryData['interpretation']?['summary'] as String?) ?? '',
            dimensionScores: _parseDimensionScores(rawSynastryData['dimensions'] as Map<String, dynamic>?),
            strengths: List<String>.from(rawSynastryData['interpretation']?['strengths'] as List<dynamic>? ?? []),
            challenges: List<String>.from(rawSynastryData['interpretation']?['challenges'] as List<dynamic>? ?? []),
            communicationText: (rawSynastryData['interpretation']?['communication'] as String?) ?? '',
            emotionalDynamicText: (rawSynastryData['interpretation']?['emotional_dynamic'] as String?) ?? '',
            valuesText: (rawSynastryData['interpretation']?['values'] as String?) ?? '',
            growthDynamicText: (rawSynastryData['interpretation']?['growth_dynamic'] as String?) ?? '',
            importantAspects: (rawSynastryData['interpretation']?['important_aspects'] as List<dynamic>?)?.map((e) => e as Map<String, dynamic>).toList() ?? [],
            aiUsed: (rawSynastryData['ai_used'] as bool?) ?? (rawSynastryData['interpretation']?['ai_used'] as bool?) ?? false,
            personalityA: (rawSynastryData['interpretation']?['personality_a'] as String?) ?? '',
            personalityB: (rawSynastryData['interpretation']?['personality_b'] as String?) ?? '',
            loveLanguage: (rawSynastryData['interpretation']?['love_language'] as String?) ?? '',
            trustLoyalty: (rawSynastryData['interpretation']?['trust_loyalty'] as String?) ?? '',
            intimacyText: (rawSynastryData['interpretation']?['intimacy_text'] as String?) ?? '',
            conflictStyle: (rawSynastryData['interpretation']?['conflict_style'] as String?) ?? '',
            overallVerdict: (rawSynastryData['interpretation']?['overall_verdict'] as String?) ?? '',
            coachTips: List<String>.from(rawSynastryData['interpretation']?['coach_tips'] as List<dynamic>? ?? []),
            topAspects: topAspects,
            chartPartial: (item['chart_partial'] as bool?) ?? false,
          );
          debugPrint('[potentialMatches] Parsed synastryData: aspects=${synastryData.detailedAspects.length}, dims=${synastryData.dimensionScores}');
        } catch (e) {
          debugPrint('[potentialMatches] Failed to parse synastry_data: $e');
          synastryData = null;
        }
      }

      final scoreParts = (item['score_parts'] as List<dynamic>?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          const <Map<String, dynamic>>[];

      return Match(
        id: 'discover_${item['user_id']}',
        userId: currentUser.id.toString(),
        matchedUserId: (item['user_id'] as int).toString(),
        matchedUser: matchedUser,
        finalScore: (item['compatibility_score'] as num? ?? 50).toDouble(),
        synastryScore: (item['synastry_score'] as num? ??
                item['chart_score'] as num? ??
                item['compatibility_score'] as num? ??
                50)
            .toDouble(),
        behavioralScore: (item['behavioral_score'] as num?)?.toDouble(),
        topReasons: List<String>.from(item['top_reasons'] as List<dynamic>? ?? []),
        cosmicInsight: item['cosmic_insight'] as String? ?? '',
        synastryData: synastryData,
        status: MatchStatus.pending,
        createdAt: DateTime.now(),
        weightedScore: (item['weighted_score'] as num?)?.toDouble(),
        scoreParts: scoreParts,
        chartPartial: (item['chart_partial'] as bool?) ?? false,
      );
    }).toList();

    potentialMatches.sort((Match a, Match b) => b.finalScore.compareTo(a.finalScore));

    debugPrint('[potentialMatches] ${data.length} profiles -> ${potentialMatches.length} matches (scores: ${potentialMatches.take(3).map((m) => m.finalScore.round()).join(', ')})');
    return potentialMatches;
  } catch (e, st) {
    debugPrint('[potentialMatches] ERROR: $e');
    debugPrint('[potentialMatches] Stack: $st');
    return <Match>[];
  }
});

List<Aspect> _parseAspects(List<dynamic>? aspectsJson) {
  if (aspectsJson == null) return [];
  return aspectsJson.map((a) {
    final String aspectType = a['aspect'] as String? ?? '';
    final String planetA = a['planet_a'] as String? ?? '';
    final String planetB = a['planet_b'] as String? ?? '';
    final double orb = (a['orb'] as num?)?.toDouble() ?? 0;
    final String signA = a['sign_a'] as String? ?? '';
    final String signB = a['sign_b'] as String? ?? '';
    final int? houseA = a['house_a'] as int?;
    final int? houseB = a['house_b'] as int?;

    return Aspect(
      planet1: planetA,
      planet2: planetB,
      aspectType: _mapAspectType(aspectType),
      score: _aspectScore(aspectType, orb),
      description: _buildRealDescription(aspectType, planetA, planetB, signA, signB, houseA, houseB, orb),
      planet1Sign: signA,
      planet2Sign: signB,
      house1: houseA,
      house2: houseB,
      orb: orb,
      isHarmonious: _isHarmonious(aspectType),
    );
  }).toList();
}

Map<String, double> _parseDimensionScores(Map<String, dynamic>? dimsJson) {
  if (dimsJson == null) return {};
  final Map<String, double> scores = {};
  dimsJson.forEach((key, value) {
    scores[key] = (value as num).toDouble();
  });
  return scores;
}

String _mapAspectType(String type) {
  switch (type) {
    case 'conjunction': return 'Conjunction';
    case 'trine': return 'Trine';
    case 'sextile': return 'Sextile';
    case 'square': return 'Square';
    case 'opposition': return 'Opposition';
    default: return type;
  }
}

double _aspectScore(String type, double orb) {
  final double orbFactor = (1.0 - (orb / 15.0)).clamp(0.3, 1.0);
  switch (type) {
    case 'conjunction': return 90 * orbFactor;
    case 'trine': return 80 * orbFactor;
    case 'sextile': return 65 * orbFactor;
    case 'square': return 35 * orbFactor;
    case 'opposition': return 40 * orbFactor;
    default: return 50 * orbFactor;
  }
}

bool _isHarmonious(String type) {
  return type == 'conjunction' || type == 'trine' || type == 'sextile';
}

String _buildRealDescription(
  String aspectType, String planetA, String planetB,
  String signA, String signB, int? houseA, int? houseB, double orb,
) {
  final String label = aspectType[0].toUpperCase() + aspectType.substring(1);
  final String signs = signA.isNotEmpty && signB.isNotEmpty ? ' in $signA/$signB' : '';
  final String orbText = ' (orb ${orb.toStringAsFixed(1)}°)';
  final String houses = (houseA != null && houseB != null) ? ', houses $houseA/$houseB' : '';

  final Map<String, String> planetMeanings = {
    'Sun': 'core identity and vitality',
    'Moon': 'emotional nature and instincts',
    'Mercury': 'communication and thinking',
    'Venus': 'love, beauty, and values',
    'Mars': 'drive, passion, and assertion',
    'Jupiter': 'growth, optimism, and philosophy',
    'Saturn': 'discipline, responsibility, and structure',
    'Uranus': 'innovation, freedom, and change',
    'Neptune': 'dreams, intuition, and spirituality',
    'Pluto': 'transformation, power, and depth',
  };

  final String meaningA = planetMeanings[planetA] ?? planetA.toLowerCase();
  final String meaningB = planetMeanings[planetB] ?? planetB.toLowerCase();

  String quality;
  switch (aspectType) {
    case 'conjunction':
      quality = 'merging and amplifying';
      break;
    case 'trine':
      quality = 'flowing harmoniously';
      break;
    case 'sextile':
      quality = 'supporting and stimulating';
      break;
    case 'square':
      quality = 'creating tension and dynamic energy';
      break;
    case 'opposition':
      quality = 'polarizing and requiring integration';
      break;
    default:
      quality = 'interacting';
  }

  return '$planetA $aspectType $planetB$signs$orbText$houses - '
      '${meaningA} ${quality} with ${meaningB}';
}

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
  final int? compatibilityScore;
  final String? lastMessage;
  final DateTime? lastMessageAt;
  final int? lastMessageSenderId;
  final bool isRead;
  final int unreadCount;
  final DateTime? lastActiveAt;

  ChatListItem({
    required this.matchId,
    required this.matchedUserId,
    this.matchedName,
    this.matchedPhotoUrl,
    this.compatibilityScore,
    this.lastMessage,
    this.lastMessageAt,
    this.lastMessageSenderId,
    this.isRead = true,
    this.unreadCount = 0,
    this.lastActiveAt,
  });
}

final FutureProvider<List<ChatListItem>> chatsFromBackendProvider =
  FutureProvider<List<ChatListItem>>((Ref ref) async {
  try {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? token = prefs.getString('auth_token');
    final String? baseUrl = prefs.getString('backend_url');
    // Watch appModeProvider to re-fetch when mode changes
    final currentMode = ref.watch(appModeProvider);
    final String mode = currentMode.value;
    if (token == null || baseUrl == null) return <ChatListItem>[];

    final response = await Dio().get(
      '$baseUrl/api/chats',
      queryParameters: {'mode': mode},
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    if (response.statusCode == 200) {
      final List<dynamic> data = response.data as List<dynamic>;
      return data.map((json) => ChatListItem(
        matchId: json['match_id'] as int,
        matchedUserId: json['matched_user_id'] as int,
        matchedName: json['matched_profile']?['name'] as String?,
        matchedPhotoUrl: json['matched_profile']?['photo_url'] as String?,
        compatibilityScore: json['compatibility_score'] as int?,
        lastMessage: json['last_message'] as String?,
        lastMessageAt: json['last_message_at'] != null ? DateTime.tryParse(json['last_message_at'] as String) : null,
        lastMessageSenderId: json['last_message_sender_id'] as int?,
        isRead: json['is_read'] as bool? ?? true,
        unreadCount: json['unread_count'] as int? ?? 0,
        lastActiveAt: json['matched_profile']?['last_active_at'] != null
            ? DateTime.tryParse(json['matched_profile']['last_active_at'] as String)
            : null,
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
  final String? birthDate;
  final String? birthTime;
  final String? locationName;
  final double? latitude;
  final double? longitude;

  BackendMatchItem({
    required this.matchId,
    required this.matchedUserId,
    required this.status,
    this.compatibilityScore,
    this.matchedName,
    this.matchedPhotoUrl,
    this.birthDate,
    this.birthTime,
    this.locationName,
    this.latitude,
    this.longitude,
  });
}

final FutureProvider<List<BackendMatchItem>> matchesFromBackendProvider =
  FutureProvider<List<BackendMatchItem>>((Ref ref) async {
  try {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? token = prefs.getString('auth_token');
    final String? baseUrl = prefs.getString('backend_url');
    // Watch appModeProvider to re-fetch when mode changes
    final currentMode = ref.watch(appModeProvider);
    final String mode = currentMode.value;
    if (token == null || baseUrl == null) return <BackendMatchItem>[];

    final response = await Dio().get(
      '$baseUrl/api/matches',
      queryParameters: {'mode': mode},
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    if (response.statusCode == 200) {
      final List<dynamic> data = response.data as List<dynamic>;
      final List<BackendMatchItem> matches = [];
      for (final json in data) {
        final matchedUserId = json['matched_user_id'] as int;
        final profile = json['matched_profile'] as Map<String, dynamic>?;
        String? name;
        String? photoUrl;
        String? birthDate;
        String? birthTime;
        String? locationName;
        double? latitude;
        double? longitude;
        if (profile != null) {
          final fn = profile['name'] as String?;
          final ln = profile['last_name'] as String?;
          name = [if (fn != null) fn, if (ln != null) ln].join(' ');
          if (name.isEmpty) name = null;
          photoUrl = profile['photo_url'] as String?;
          birthDate = profile['birth_date'] as String?;
          birthTime = profile['birth_time'] as String?;
          final loc = profile['location'] as Map<String, dynamic>?;
          if (loc != null) {
            locationName = loc['name'] as String?;
            latitude = (loc['latitude'] as num?)?.toDouble();
            longitude = (loc['longitude'] as num?)?.toDouble();
          }
        }
        matches.add(BackendMatchItem(
          matchId: json['id'] as int,
          matchedUserId: matchedUserId,
          status: json['status'] as String,
          compatibilityScore: json['compatibility_score'] as int?,
          matchedName: name,
          matchedPhotoUrl: photoUrl,
          birthDate: birthDate,
          birthTime: birthTime,
          locationName: locationName,
          latitude: latitude,
          longitude: longitude,
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
 
  Future<Match?> saveMatch(Match match) async {
    final MatchRepository repository = ref.read(matchRepositoryProvider);
    final User? currentUser = ref.read(currentUserProvider).value;
    if (currentUser == null) return null;

    final int? backendId = await repository.saveMatchToBackend(match);
    final Match updatedMatch = backendId != null ? match.copyWith(backendMatchId: backendId) : match;

    final List<Match> existingMatches = await repository.getMatches(currentUser.id.toString());
    existingMatches.add(updatedMatch);
    await repository.saveMatches(existingMatches);

    final bool isMutual = await repository.checkMutualMatch(match.matchedUserId);

    ref.invalidate(userMatchesProvider(currentUser.id.toString()));
    ref.invalidate(acceptedMatchesProvider(currentUser.id.toString()));
    ref.invalidate(potentialMatchesProvider);
    ref.invalidate(chatsFromBackendProvider);
    ref.invalidate(incomingLikesProvider);
    ref.invalidate(likedUserIdsProvider);
    return isMutual ? updatedMatch : null;
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
    // Watch appModeProvider to re-fetch when mode changes
    ref.watch(appModeProvider);
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
