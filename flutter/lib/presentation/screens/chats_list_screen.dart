import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:go_router/go_router.dart';
import 'package:syno_app/domain/entities/match.dart';
import 'package:syno_app/domain/entities/user.dart';
import 'package:syno_app/presentation/providers/match_provider.dart';
import 'package:syno_app/presentation/providers/user_provider.dart';
import 'package:syno_app/presentation/providers/block_provider.dart';
import 'package:syno_app/theme.dart';
import 'package:syno_app/presentation/providers/auth_providers.dart'; // Import auth_providers to access currentUserProvider
import 'package:syno_app/presentation/providers/theme_provider.dart';

class ChatsListScreen extends ConsumerWidget {
  const ChatsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<User?> currentUserAsync = ref.watch(currentUserProvider);
    final theme = ref.watch(themeProvider);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: theme.gradient),
        child: SafeArea(
          child: Column(
            children: [
              _buildAppBar(context, theme),
              Expanded(
                child: currentUserAsync.when(
                  data: (User? user) {
                    if (user == null) {
                      return Center(child: Text('chat.no_user'.tr()));
                    }
                    final AsyncValue<List<Match>> acceptedMatchesAsync = ref.watch(acceptedMatchesProvider(user.id.toString()));
                    final AsyncValue<List<User>> blockedUsersAsync = ref.watch(blockedUsersProvider);
                    return acceptedMatchesAsync.when(
                      data: (List<Match> matches) {
                        final Set<String> blocked = blockedUsersAsync.maybeWhen(
                          data: (List<User> list) => list.map((u) => u.userId.toString()).toSet(), 
                          orElse: () => <String>{},
                        );
                        final List<Match> visible = matches.where((Match m) => !blocked.contains(m.matchedUserId)).toList();
                        if (visible.isEmpty) {
                          return _buildEmptyState(context, theme);
                        }
                        return ListView.builder(
                          padding: AppSpacing.paddingMd,
                          itemCount: visible.length,
                          itemBuilder: (BuildContext context, int index) {
                            final Match match = visible[index];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: AppSpacing.md),
                          child: _buildChatCard(context, match, theme, ref),
                            );
                          },
                        );
                      },
                      loading: () => Center(child: Text('chats_list.loading'.tr(), style: const TextStyle(color: Colors.white70))),
                      error: (Object error, StackTrace stack) => _buildErrorState(context, theme),
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
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back_ios_new, color: theme.primaryTextColor),
            onPressed: () => context.go('/discover'),
          ),
          Expanded(
            child: Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
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

  Widget _buildChatCard(BuildContext context, Match match, AppThemeData theme, WidgetRef ref) {
    // Assuming currentUserProvider is an AsyncNotifierProvider and its notifier has an 'authToken' getter.
    // This 'authToken' would be the JWT token obtained during login and stored by the AuthNotifier.
    final String? authToken = ref.read(currentUserProvider.notifier).authToken;

    return GestureDetector(
      onTap: () => context.push('/chat', extra: match),
      child: Container(
        padding: AppSpacing.paddingMd,
        decoration: BoxDecoration(
          color: theme.primaryTextColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: Image.network(
                match.matchedUser.photos.first.url,
                headers: authToken != null ? {'Authorization': 'Bearer $authToken'} : null,
                width: 60,
                height: 60,
                fit: BoxFit.cover,
                errorBuilder: (BuildContext context, Object error, StackTrace? stackTrace) => Container(
                  width: 60,
                  height: 60,
                  color: CosmicColors.cosmicPurple,
                  child: const Icon(Icons.person, size: 30, color: Colors.white),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    match.matchedUser.name.toString(),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: theme.primaryTextColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'chats_list.start_conversation'.tr(),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: theme.primaryTextColor.withOpacity(0.6),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                gradient: CosmicColors.cosmicGradient,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Text(
                '${match.finalScore.toStringAsFixed(0)}%',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
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
          children: [
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
          children: [
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
