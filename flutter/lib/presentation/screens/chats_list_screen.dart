import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:go_router/go_router.dart';
import 'package:syno_app/domain/entities/match.dart';
import 'package:syno_app/domain/entities/synastry_data.dart';
import 'package:syno_app/domain/entities/user.dart';
import 'package:syno_app/presentation/providers/match_provider.dart';
import 'package:syno_app/presentation/providers/auth_providers.dart';
import 'package:syno_app/theme.dart';
import 'package:syno_app/presentation/providers/theme_provider.dart';

class ChatsListScreen extends ConsumerWidget {
  const ChatsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<ChatListItem>> chatsAsync = ref.watch(chatsFromBackendProvider);
    final AppThemeData theme = ref.watch(themeProvider);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: theme.gradient),
        child: SafeArea(
          child: Column(
            children: <Widget>[
              _buildAppBar(context, theme),
              Expanded(
                child: chatsAsync.when(
                  data: (List<ChatListItem> chats) {
                    if (chats.isEmpty) {
                      return _buildEmptyState(context, theme);
                    }
                    return ListView.builder(
                      padding: AppSpacing.paddingMd,
                      itemCount: chats.length,
                      itemBuilder: (BuildContext context, int index) {
                        final chat = chats[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.md),
                          child: _buildChatCard(context, chat, theme, ref),
                        );
                      },
                    );
                  },
                  loading: () => Center(child: Text('chats_list.loading'.tr(), style: const TextStyle(color: Colors.white70))),
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
    return Padding(
      padding: AppSpacing.paddingMd,
      child: Row(
        children: <Widget>[
          IconButton(
            icon: Icon(Icons.arrow_back_ios_new, color: theme.primaryTextColor),
            onPressed: () => context.go('/discover'),
          ),
          Expanded(
            child: Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: SizedBox(
                      width: 30,
                      height: 30,
                      child: ClipOval(
                        child: Image.asset(
                          'assets/icons/dreamflow_icon.jpg',
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    'chats_list.title'.tr(),
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: theme.primaryTextColor,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatCard(BuildContext context, ChatListItem chat, AppThemeData theme, WidgetRef ref) {
    final String? baseUrl = ref.read(backendUrlProvider);
    final String photoUrl = chat.matchedPhotoUrl != null && baseUrl != null
        ? '$baseUrl${chat.matchedPhotoUrl}'
        : '';

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
      finalScore: 0,
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

    return GestureDetector(
      onTap: () => context.push('/chat', extra: matchObj),
      child: Container(
        padding: AppSpacing.paddingMd,
        decoration: BoxDecoration(
          color: theme.primaryTextColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: Row(
          children: <Widget>[
            ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: photoUrl.isNotEmpty
                  ? Image.network(
                      photoUrl,
                      width: 60,
                      height: 60,
                      fit: BoxFit.cover,
                      errorBuilder: (BuildContext context, Object error, StackTrace? stackTrace) => Container(
                        width: 60,
                        height: 60,
                        color: CosmicColors.cosmicPurple,
                        child: const Icon(Icons.person, size: 30, color: Colors.white),
                      ),
                    )
                  : Container(
                      width: 60,
                      height: 60,
                      color: CosmicColors.cosmicPurple,
                      child: const Icon(Icons.person, size: 30, color: Colors.white),
                    ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    chat.matchedName ?? 'Unknown',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: theme.primaryTextColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    chat.lastMessage ?? 'chats_list.start_conversation'.tr(),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: theme.primaryTextColor.withOpacity(0.6),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (!chat.isRead)
              Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, AppThemeData theme) {
    return Center(
      child: Padding(
        padding: AppSpacing.paddingXl,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.primaryTextColor.withOpacity(0.1),
              ),
              child: Icon(Icons.chat_bubble_outline, size: 64, color: theme.primaryTextColor),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text(
              'chats_list.no_chats_title'.tr(),
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: theme.primaryTextColor,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'chats_list.no_chats_subtitle'.tr(),
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: theme.primaryTextColor.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, AppThemeData theme) {
    return Center(
      child: Padding(
        padding: AppSpacing.paddingXl,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.primaryTextColor.withOpacity(0.1),
              ),
              child: Icon(Icons.error_outline, size: 64, color: theme.primaryTextColor),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text(
              'chats_list.error_title'.tr(),
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: theme.primaryTextColor, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'chats_list.error_subtitle'.tr(),
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: theme.primaryTextColor.withOpacity(0.7)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
