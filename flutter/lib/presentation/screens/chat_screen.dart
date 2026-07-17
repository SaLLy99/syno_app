import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:go_router/go_router.dart';
import 'package:syno_app/domain/entities/chat_message.dart';
import 'package:syno_app/domain/entities/match.dart';
import 'package:syno_app/domain/entities/user.dart';
import 'package:syno_app/presentation/providers/chat_provider.dart';
import 'package:syno_app/presentation/providers/user_provider.dart';
import 'package:syno_app/presentation/providers/block_provider.dart';
import 'package:syno_app/presentation/providers/auth_providers.dart';
import 'package:syno_app/presentation/widgets/match_score_badge.dart';
import 'package:syno_app/theme.dart';
import 'package:syno_app/presentation/providers/theme_provider.dart';


class ChatScreen extends ConsumerStatefulWidget {
  final Match match;

  const ChatScreen({super.key, required this.match});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    final String content = _messageController.text.trim();
    _messageController.clear();

    await ref.read(chatActionsProvider).sendMessage(widget.match.id, content);

    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<User?> currentUserAsync = ref.watch(currentUserProvider);
    final AppThemeData theme = ref.watch(themeProvider);
    final AsyncValue<List<ChatMessage>> messagesAsync = ref.watch(chatMessagesProvider(widget.match.id));
    final AsyncValue<bool> isBlockedAsync = ref.watch(isUserBlockedProvider(widget.match.matchedUserId));

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: theme.gradient),
        child: Column(
          children: <Widget>[
            _buildHeader(context, theme),
            Expanded(
              child: currentUserAsync.when(
                data: (User? currentUser) { // currentUser is User?
                  if (currentUser == null) return Center(child: Text('chat.no_user'.tr()));
                  return Column(
                    children: <Widget>[
                      isBlockedAsync.when(
                        data: (bool isBlocked) => isBlocked ? _buildBlockedBanner(context, theme) : const SizedBox.shrink(),
                        loading: () => const SizedBox.shrink(),
                        error: (Object e, _) => const SizedBox.shrink(),
                      ),
                      Expanded(
                        child: messagesAsync.when(
                          data: (List<ChatMessage> messages) => _buildMessagesList(context, messages, currentUser.id.toString(), theme),
                          loading: () => const Center(child: CircularProgressIndicator()),
                          error: (Object error, StackTrace stack) => Center(child: Text('chat.error'.tr(args: <String>[error.toString()]))),
                        ),
                      ),
                    ],
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (Object error, StackTrace stack) => Center(child: Text('chat.error'.tr(args: <String>[error.toString()]))),
              ),
            ),
            isBlockedAsync.when(
              data: (bool isBlocked) => isBlocked ? _buildBlockedFooter(context, theme) : _buildMessageInput(context, theme),
              loading: () => _buildMessageInput(context, theme),
              error: (Object e, _) => _buildMessageInput(context, theme),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, AppThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.transparent,
        border: Border(bottom: BorderSide(color: theme.primaryTextColor.withOpacity(0.1))),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: <Widget>[
            Padding(
              padding: AppSpacing.paddingMd,
              child: Row(
                children: <Widget>[
                  IconButton(
                    icon: Icon(Icons.arrow_back, color: theme.primaryTextColor),
                    onPressed: () => context.pop(),
                  ),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image.network(
                      widget.match.matchedUser.photos.first.getFullUrl(ref.read(backendUrlProvider)),
                      width: 40,
                      height: 40,
                      fit: BoxFit.cover,
                      errorBuilder: (BuildContext context, Object error, StackTrace? stackTrace) => Container(
                        width: 40,
                        height: 40,
                        color: CosmicColors.cosmicPurple,
                        child: const Icon(Icons.person, size: 20, color: Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          widget.match.matchedUser.name.toString(),
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: theme.primaryTextColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'match_details.match_percentage'.tr(args: <String>[widget.match.finalScore.toStringAsFixed(0)]),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: theme.primaryTextColor.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                  MatchScoreBadge(score: widget.match.finalScore, size: 40),
                  const SizedBox(width: 4),
                  _buildOverflowMenu(context, theme),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverflowMenu(BuildContext context, AppThemeData theme) {
    final AsyncValue<bool> isBlockedAsync = ref.watch(isUserBlockedProvider(widget.match.matchedUserId));
    return isBlockedAsync.when(
      data: (bool isBlocked) => IconButton(
        icon: Icon(Icons.more_vert, color: theme.primaryTextColor),
        onPressed: () => _showActionsSheet(context, isBlocked, theme),
      ),
      loading: () => const SizedBox.shrink(),
      error: (Object e, _) => IconButton(
        icon: Icon(Icons.more_vert, color: theme.primaryTextColor),
        onPressed: () => _showActionsSheet(context, false, theme),
      ),
    );
  }

  Future<void> _showActionsSheet(BuildContext context, bool isBlocked, AppThemeData theme) async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Padding(
            padding: AppSpacing.paddingLg,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Icon(Icons.security, color: theme.primaryTextColor),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      'chat.safety_options'.tr(),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: theme.primaryTextColor,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    isBlocked ? Icons.lock_open : Icons.block,
                    color: isBlocked ? theme.primaryTextColor : Colors.red,
                  ),
                  title: Text(
                    isBlocked ? 'chat.unblock_user'.tr(namedArgs: <String, String>{'name': widget.match.matchedUser.name.toString()}) : 'chat.block_user'.tr(namedArgs: <String, String>{'name': widget.match.matchedUser.name.toString()}),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: isBlocked ? theme.primaryTextColor : Colors.red,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  subtitle: Text(
                    isBlocked ?
                        'chat.unblock_subtitle'.tr() :
                        'chat.block_subtitle'.tr(),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: theme.primaryTextColor.withOpacity(0.7),
                        ),
                  ),
                  onTap: () async {
                    Navigator.of(context).pop();
                    if (isBlocked) {
                      await ref.read(blockActionsProvider).unblock(widget.match.matchedUserId);
                    } else {
                      await ref.read(blockActionsProvider).block(widget.match.matchedUserId);
                    }
                    if (mounted) setState(() {});
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                TextButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(Icons.close, color: theme.primaryTextColor),
                  label: Text('chat.close'.tr(), style: TextStyle(color: theme.primaryTextColor)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBlockedBanner(BuildContext context, AppThemeData theme) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: AppSpacing.md, left: AppSpacing.md, right: AppSpacing.md),
      padding: AppSpacing.paddingMd,
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.15),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: Colors.red.withOpacity(0.4), width: 1),
      ),
      child: Row(
        children: <Widget>[
          const Icon(Icons.block, color: Colors.red),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'chat.blocked_banner'.tr(),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBlockedFooter(BuildContext context, AppThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.transparent,
        border: Border(top: BorderSide(color: theme.primaryTextColor.withOpacity(0.1))),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: AppSpacing.paddingMd,
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  'chat.blocked_footer'.tr(),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: theme.primaryTextColor.withOpacity(0.7)),
                ),
              ),
              TextButton.icon(
                onPressed: () async {
                  await ref.read(blockActionsProvider).unblock(widget.match.matchedUserId);
                  if (mounted) setState(() {});
                },
                icon: Icon(Icons.lock_open, color: theme.primaryTextColor),
                label: Text('chat.unblock_button'.tr(), style: TextStyle(color: theme.primaryTextColor)),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMessagesList(BuildContext context, List<ChatMessage> messages, String currentUserId, AppThemeData theme) {
    if (messages.isEmpty) {
      return Center(
        child: Padding(
          padding: AppSpacing.paddingXl,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(Icons.chat_bubble_outline, size: 64, color: theme.primaryTextColor),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'chat.start_conversation'.tr(),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: theme.primaryTextColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'chat.say_hello'.tr(namedArgs: <String, String>{'name': widget.match.matchedUser.name.toString()}),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: theme.primaryTextColor.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: AppSpacing.paddingMd,
      itemCount: messages.length,
      itemBuilder: (BuildContext context, int index) {
        final ChatMessage message = messages[index];
        final bool isMe = message.senderId == currentUserId;
        return _buildMessageBubble(context, message, isMe, theme);
      },
    );
  }

  Widget _buildMessageBubble(BuildContext context, ChatMessage message, bool isMe, AppThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: <Widget>[
          if (!isMe) ...<Widget>[
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(
                widget.match.matchedUser.photos.first.getFullUrl(ref.read(backendUrlProvider)),
                width: 32,
                height: 32,
                fit: BoxFit.cover,
                errorBuilder: (BuildContext context, Object error, StackTrace? stackTrace) => Container(
                  width: 32,
                  height: 32,
                  color: CosmicColors.cosmicPurple,
                  child: const Icon(Icons.person, size: 16, color: Colors.white),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
          ],
          Flexible(
            child: Container(
              padding: AppSpacing.paddingMd,
              decoration: BoxDecoration(
                gradient: isMe
                    ? CosmicColors.cosmicGradient
                    : null,
                color: isMe ? null : theme.primaryTextColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    message.content,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: isMe ? Colors.white : theme.primaryTextColor,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    DateFormat('h:mm a').format(message.timestamp),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: (isMe ? Colors.white : theme.primaryTextColor).withOpacity(0.6),
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

  Widget _buildMessageInput(BuildContext context, AppThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.transparent,
        border: Border(top: BorderSide(color: theme.primaryTextColor.withOpacity(0.1))),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: AppSpacing.paddingMd,
          child: Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: _messageController,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: theme.primaryTextColor,
                  ),
                  decoration: InputDecoration(
                    hintText: 'chat.message_hint'.tr(),
                    hintStyle: TextStyle(
                      color: theme.primaryTextColor.withOpacity(0.5),
                    ),
                    filled: true,
                    fillColor: theme.primaryTextColor.withOpacity(0.1),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: AppSpacing.paddingMd,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Container(
                decoration: const BoxDecoration(
                  gradient: CosmicColors.cosmicGradient,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(Icons.send, color: Colors.white),
                  onPressed: _sendMessage,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
