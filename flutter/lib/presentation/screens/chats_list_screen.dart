import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:go_router/go_router.dart';
import 'package:syno_app/domain/entities/match.dart';
import 'package:syno_app/domain/entities/synastry_data.dart';
import 'package:syno_app/domain/entities/user.dart';
import 'package:syno_app/presentation/providers/match_provider.dart';
import 'package:syno_app/presentation/providers/auth_providers.dart';
import 'package:syno_app/presentation/providers/user_provider.dart';
import 'package:syno_app/theme.dart';
import 'package:syno_app/presentation/providers/theme_provider.dart';

class ChatsListScreen extends ConsumerStatefulWidget {
  const ChatsListScreen({super.key});

  @override
  ConsumerState<ChatsListScreen> createState() => _ChatsListScreenState();
}

class _ChatsListScreenState extends ConsumerState<ChatsListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.invalidate(chatsFromBackendProvider);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<ChatListItem>> chatsAsync = ref.watch(chatsFromBackendProvider);
    final AsyncValue<User?> currentUserAsync = ref.watch(currentUserProvider);
    final AppThemeData theme = ref.watch(themeProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BoxDecoration(gradient: theme.gradient),
        child: SafeArea(
          child: Column(
            children: <Widget>[
              _buildAppBar(context, theme),
              Expanded(
                child: currentUserAsync.when(
                  data: (User? currentUser) {
                    return chatsAsync.when(
                      data: (List<ChatListItem> chats) {
                        if (chats.isEmpty) {
                          return _buildEmptyState(context, theme);
                        }
                        return ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          itemCount: chats.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 2),
                          itemBuilder: (BuildContext context, int index) {
                            final chat = chats[index];
                            return _buildChatTile(context, chat, theme, ref, currentUser?.id);
                          },
                        );
                      },
                      loading: () => Center(child: CircularProgressIndicator(color: Colors.white.withOpacity(0.5))),
                      error: (Object error, StackTrace stack) => _buildErrorState(context, theme),
                    );
                  },
                  loading: () => Center(child: CircularProgressIndicator(color: Colors.white.withOpacity(0.5))),
                  error: (Object error, StackTrace stack) => _buildErrorState(context, theme),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context, AppThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: <Widget>[
          IconButton(
            icon: Icon(Icons.arrow_back_ios_new, color: theme.primaryTextColor, size: 20),
            onPressed: () => context.go('/discover'),
          ),
          Expanded(
            child: Text(
              'Messages',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: theme.primaryTextColor,
                fontWeight: FontWeight.bold,
                fontSize: 22,
              ),
            ),
          ),
          Icon(Icons.edit_note, color: theme.primaryTextColor.withOpacity(0.7), size: 24),
        ],
      ),
    );
  }

  Widget _buildChatTile(BuildContext context, ChatListItem chat, AppThemeData theme, WidgetRef ref, int? currentUserId) {
    final String? baseUrl = ref.read(backendUrlProvider);
    final String photoUrl = chat.matchedPhotoUrl != null && baseUrl != null
        ? '$baseUrl${chat.matchedPhotoUrl}'
        : '';

    final String timeStr = _formatTimestamp(chat.lastMessageAt);
    final bool hasUnread = chat.unreadCount > 0;
    final bool isOnline = chat.lastActiveAt != null && DateTime.now().difference(chat.lastActiveAt!).inMinutes < 5;
    final bool isSentByMe = chat.lastMessageSenderId != null && chat.lastMessageSenderId == currentUserId;

    final matchObj = Match(
      id: chat.matchId.toString(),
      userId: '0',
      matchedUserId: chat.matchedUserId.toString(),
      matchedUser: User(
        id: chat.matchedUserId,
        userId: chat.matchedUserId,
        name: chat.matchedName ?? 'Unknown',
        photos: photoUrl.isNotEmpty ? [Photo(id: 0, url: photoUrl, isPrimary: true)] : [],
      ),
      finalScore: (chat.compatibilityScore ?? 0).toDouble(),
      synastryScore: 0,
      behavioralScore: 0,
      topReasons: const <String>[],
      cosmicInsight: '',
      synastryData: SynastryData(
        moonScore: 0, mercuryScore: 0, venusMarsScore: 0,
        nodesScore: 0, saturnScore: 0,
        detailedAspects: const <Aspect>[],
        interpretation: '',
      ),
      status: MatchStatus.accepted,
      createdAt: DateTime.now(),
      backendMatchId: chat.matchId,
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push('/chat', extra: matchObj),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: <Widget>[
            Stack(
              children: [
                _buildAvatar(photoUrl, hasUnread),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: isOnline ? const Color(0xFF43E97B) : Colors.grey.withOpacity(0.5),
                      shape: BoxShape.circle,
                      border: Border.all(color: theme.gradient.colors.first, width: 2.5),
                    ),
                  ),
                ),
              ],
            ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            chat.matchedName ?? 'Unknown',
                            style: TextStyle(
                              color: theme.primaryTextColor,
                              fontWeight: hasUnread ? FontWeight.bold : FontWeight.w600,
                              fontSize: 15.5,
                            ),
                          ),
                        ),
                        if (chat.compatibilityScore != null && chat.compatibilityScore! > 0) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: _getScoreColor(chat.compatibilityScore!).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${chat.compatibilityScore}%',
                              style: TextStyle(
                                color: _getScoreColor(chat.compatibilityScore!),
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _buildMessagePreview(chat, isSentByMe),
                      style: TextStyle(
                        color: hasUnread
                            ? theme.primaryTextColor.withOpacity(0.9)
                            : theme.primaryTextColor.withOpacity(0.5),
                        fontWeight: hasUnread ? FontWeight.w500 : FontWeight.normal,
                        fontSize: 13.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    timeStr,
                    style: TextStyle(
                      color: hasUnread
                          ? const Color(0xFF60A5FA)
                          : theme.primaryTextColor.withOpacity(0.4),
                      fontSize: 11.5,
                      fontWeight: hasUnread ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                  if (hasUnread) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: const BoxDecoration(
                        color: Color(0xFF60A5FA),
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        chat.unreadCount > 99 ? '99+' : '${chat.unreadCount}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(String photoUrl, bool hasUnread) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: hasUnread
            ? Border.all(color: const Color(0xFF60A5FA), width: 2.5)
            : null,
      ),
      child: ClipOval(
        child: photoUrl.isNotEmpty
            ? Image.network(
                photoUrl,
                width: 52,
                height: 52,
                fit: BoxFit.cover,
                errorBuilder: (BuildContext context, Object error, StackTrace? stackTrace) => _buildFallbackAvatar(),
              )
            : _buildFallbackAvatar(),
      ),
    );
  }

  Widget _buildFallbackAvatar() {
    return Container(
      width: 52,
      height: 52,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [Color(0xFF6C63FF), Color(0xFF3B82F6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Icon(Icons.person, size: 26, color: Colors.white),
    );
  }

  Color _getScoreColor(int score) {
    if (score >= 80) return const Color(0xFF22C55E);
    if (score >= 60) return const Color(0xFF3B82F6);
    if (score >= 40) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }

  String _buildMessagePreview(ChatListItem chat, bool isSentByMe) {
    if (chat.lastMessage == null) return 'Say hello! 👋';
    if (isSentByMe) return 'You: ${chat.lastMessage}';
    return chat.lastMessage!;
  }

  String _formatTimestamp(DateTime? dt) {
    if (dt == null) return '';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDay = DateTime(dt.year, dt.month, dt.day);
    final diffDays = today.difference(messageDay).inDays;

    if (diffDays == 0) {
      return DateFormat('h:mm a').format(dt);
    }
    if (diffDays == 1) return 'Yesterday';
    if (diffDays < 7) {
      const days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
      return days[dt.weekday % 7];
    }
    if (dt.year == now.year) {
      return DateFormat('MMM d').format(dt);
    }
    return DateFormat('MM/dd/yy').format(dt);
  }

  Widget _buildEmptyState(BuildContext context, AppThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.08),
              ),
              child: Icon(Icons.chat_bubble_outline_rounded, size: 56, color: Colors.white.withOpacity(0.4)),
            ),
            const SizedBox(height: 24),
            Text(
              'No conversations yet',
              style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Match with someone to start chatting!',
              style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF60A5FA),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              ),
              onPressed: () => context.go('/discover'),
              child: const Text('Discover People'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, AppThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.08),
              ),
              child: Icon(Icons.error_outline, size: 56, color: Colors.white.withOpacity(0.4)),
            ),
            const SizedBox(height: 24),
            Text(
              'Something went wrong',
              style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Couldn\'t load your conversations. Please try again.',
              style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
