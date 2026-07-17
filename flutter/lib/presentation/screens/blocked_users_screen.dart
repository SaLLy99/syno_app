import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:syno_app/domain/entities/user.dart';
import 'package:syno_app/presentation/providers/block_provider.dart';
import 'package:syno_app/presentation/providers/auth_providers.dart';
import 'package:syno_app/presentation/providers/user_provider.dart';
import 'package:syno_app/presentation/widgets/cosmic_dialog.dart';
import 'package:syno_app/theme.dart';
import 'package:syno_app/presentation/providers/theme_provider.dart';

class BlockedUsersScreen extends ConsumerStatefulWidget {
  const BlockedUsersScreen({super.key});

  @override
  ConsumerState<BlockedUsersScreen> createState() => _BlockedUsersScreenState();
}

class _BlockedUsersScreenState extends ConsumerState<BlockedUsersScreen> {
  final TextEditingController _nameController = TextEditingController();
  bool _isProcessing = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _handleBlock() async {
    final String name = _nameController.text.trim();
    if (name.isEmpty) return;
    
    final AppThemeData theme = ref.read(themeProvider);

    setState(() => _isProcessing = true);
    try {
      // 1. Check if user exists first (The pre-check)
      final User? userToBlock = await ref.read(currentUserProvider.notifier).searchUserByName(name);
      final User? currentUser = ref.read(currentUserProvider).value;
      final List<User> blockedList = ref.read(blockedUsersProvider).value ?? <User>[];
      
      if (userToBlock == null) {
        if (mounted) setState(() => _isProcessing = false);
        showUserNotFoundDialog(context, theme);
        return;
      }

      // Prevent self-blocking
      if (userToBlock.userId == currentUser?.id) {
        if (mounted) setState(() => _isProcessing = false);
        showCosmicErrorDialog(
          context,
          'dialog.notice_title'.tr(),
          'profile.settings.blocked_users.error_self_block'.tr(),
          theme,
        );
        return;
      }

      // Check if user is already blocked
      final bool isAlreadyBlocked = blockedList.any((User u) => u.userId == userToBlock.userId);
      if (isAlreadyBlocked) {
        if (mounted) setState(() => _isProcessing = false);
        showCosmicErrorDialog(
          context,
          'dialog.notice_title'.tr(),
          'profile.settings.blocked_users.error_already_blocked'.tr(),
          theme,
        );
        return;
      }

      // Reset loading state before showing the confirmation dialog
      if (mounted) setState(() => _isProcessing = false);

      // 2. If user exists and is valid, show the blocking confirmation popup
      showCosmicConfirmDialog(
        context: context,
        title: 'match_details.block_sheet_title'.tr(),
        message: 'match_details.block_sheet_subtitle'.tr(),
        confirmText: 'match_details.block'.tr(),
        theme: theme,
        onConfirm: () => _executeBlock(name),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        showCosmicErrorDialog(context, 'profile.error'.tr(), 'profile.settings.blocked_users.error_generic'.tr(), theme);
      }
    }
  }

  Future<void> _executeBlock(String name) async {
    final AppThemeData theme = ref.read(themeProvider);

    setState(() => _isProcessing = true);
    try {
      await ref.read(currentUserProvider.notifier).blockUserByName(name);
      _nameController.clear();
      if (mounted) {
        // Replaced SnackBar with a more prominent dialog for success
        showDialog(
          context: context,
          builder: (BuildContext dialogContext) {
            return AlertDialog(
              backgroundColor: theme.backgroundColor,
              title: Text(
                'profile.settings.blocked_users.success_title'.tr(), // New translation key
                style: TextStyle(color: theme.textColor),
              ),
              content: Text(
                'profile.settings.blocked_users.success_blocked'.tr(args: <String>[name]),
                style: TextStyle(color: theme.textColor.withOpacity(0.8)),
              ),
              actions: <Widget>[
                TextButton(
                  child: Text('dialog.ok'.tr(), style: TextStyle(color: theme.accentColor)),
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                  },
                ),
              ],
            );
          },
        );
        ref.invalidate(blockedUsersProvider);
      }
    } catch (e) {
      if (mounted) {
        // If it fails here, it's likely a server error, not "Not Found", 
        // because we already verified existence in _handleBlock.
        showCosmicErrorDialog(context, 'profile.error'.tr(), e.toString(), theme);
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _handleUnblock(int userId, String name) async {
    final AppThemeData theme = ref.read(themeProvider);

    showCosmicConfirmDialog(
      context: context,
      title: 'profile.settings.blocked_users.unblock_confirm_title'.tr(),
      message: 'profile.settings.blocked_users.unblock_confirm_message'.tr(args: <String>[name]),
      confirmText: 'profile.settings.blocked_users.unblock_button'.tr(),
      theme: theme,
      onConfirm: () async {
        try {
          await ref.read(currentUserProvider.notifier).unblockUser(userId);
          if (mounted) {
            // Replaced SnackBar with a more prominent dialog for success consistency
            showDialog(
              context: context,
              builder: (BuildContext dialogContext) {
                return AlertDialog(
                  backgroundColor: theme.backgroundColor,
                  title: Text(
                    'profile.settings.blocked_users.success_title'.tr(),
                    style: TextStyle(color: theme.textColor),
                  ),
                  content: Text(
                    'profile.settings.blocked_users.success_unblocked'.tr(args: <String>[name]),
                    style: TextStyle(color: theme.textColor.withOpacity(0.8)),
                  ),
                  actions: <Widget>[
                    TextButton(
                      child: Text('dialog.ok'.tr(), style: TextStyle(color: theme.accentColor)),
                      onPressed: () => Navigator.of(dialogContext).pop(),
                    ),
                  ],
                );
              },
            );
            ref.invalidate(blockedUsersProvider);
          }
        } catch (e) {
          if (mounted) showCosmicErrorDialog(context, 'profile.error'.tr(), e.toString(), theme);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final User? currentUser = ref.watch(currentUserProvider).value;
    if (currentUser == null) {
      return const Scaffold(body: Center(child: Text('Not logged in')));
    }

    final AsyncValue<List<User>> blockedAsync = ref.watch(blockedUsersProvider);
    final AppThemeData theme = ref.watch(themeProvider);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text('profile.settings.blocked_users.title'.tr()),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(gradient: theme.gradient),
        child: SafeArea(
          child: Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: TextField(
                        controller: _nameController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'profile.settings.blocked_users.input_placeholder'.tr(),
                          hintStyle: const TextStyle(color: Colors.white54),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.1),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      onPressed: _isProcessing ? null : _handleBlock,
                      icon: _isProcessing 
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) 
                        : const Icon(Icons.person_add_disabled),
                      style: IconButton.styleFrom(backgroundColor: theme.accentColor),
                    ),
                  ],
                ),
              ),
              const Divider(color: Colors.white24),
              Expanded(
                child: blockedAsync.when(
                  data: (List<User> list) {
                    if (list.isEmpty) {
                      return Center(child: Text('profile.settings.blocked_users.empty_list'.tr(), style: const TextStyle(color: Colors.white70)));
                    }
                    return ListView.builder(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      itemCount: list.length,
                      itemBuilder: (BuildContext context, int index) {
                        final User user = list[index];
                        final String displayName = '${user.name ?? ''} ${user.lastName ?? ''}'.trim();

                        return Card(
                          color: Colors.white.withOpacity(0.05),
                          margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: ListTile(
                            leading: _BlockedUserAvatar(user: user),
                            title: Text(displayName, style: const TextStyle(color: Colors.white)),
                            subtitle: Text(user.sex?.name ?? '', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)),
                            trailing: OutlinedButton(
                              onPressed: () => _handleUnblock(user.userId, displayName),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: theme.accentColor.withOpacity(0.5)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                              ),
                              child: Text(
                                'profile.settings.blocked_users.unblock_button'.tr(),
                                style: TextStyle(color: theme.accentColor, fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (_, __) => Center(child: Text('chat.error'.tr())),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BlockedUserAvatar extends ConsumerWidget {
  final User user;
  const _BlockedUserAvatar({required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String initial = (user.name?.isNotEmpty == true) ? user.name![0].toUpperCase() : "?";
    
    // Safety check for photos
    final Photo? primaryPhoto = user.photos.isEmpty 
        ? null 
        : user.photos.firstWhere((Photo p) => p.isPrimary == true, orElse: () => user.photos.first);

    // If you implement an authTokenProvider, watch it here. 
    // Otherwise, you can keep the StatefulWidget approach, 
    // but a provider is significantly cleaner.
    if (primaryPhoto == null) {
      return CircleAvatar(
        backgroundColor: Colors.white.withOpacity(0.1),
        child: Text(initial, style: const TextStyle(color: Colors.white70)),
      );
    }

    final String backendUrl = ref.watch(backendUrlProvider);
    // Note: If you don't use a provider for the token, 
    // you may need to keep the StatefulWidget to manage the token state.
    return CircleAvatar(
      backgroundImage: NetworkImage(
        '$backendUrl/api/photos/${primaryPhoto.id}',
        // headers: {'Authorization': 'Bearer $token'},
      ),
    );
  }
}