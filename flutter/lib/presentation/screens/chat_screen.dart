import 'package:flutter/material.dart';
// ignore_for_file: deprecated_member_use
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:syno_app/domain/entities/chat_message.dart';
import 'package:syno_app/domain/entities/match.dart';
import 'package:syno_app/domain/entities/user.dart';
import 'package:syno_app/presentation/providers/chat_provider.dart';
import 'package:syno_app/presentation/providers/user_provider.dart';
import 'package:syno_app/presentation/providers/block_provider.dart';
import 'package:syno_app/presentation/providers/auth_providers.dart';
import 'package:syno_app/presentation/providers/websocket_provider.dart';
import 'package:syno_app/presentation/providers/match_provider.dart';
import 'package:syno_app/data/services/websocket_service.dart';
import 'package:syno_app/theme.dart';
import 'package:syno_app/presentation/providers/theme_provider.dart';
import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final Match match;

  const ChatScreen({super.key, required this.match});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _imagePicker = ImagePicker();
  StreamSubscription<WebSocketMessage>? _wsSubscription;
  bool _showEmojiPicker = false;
  ChatMessage? _replyToMessage;
  ChatMessage? _editingMessage;

  static const MethodChannel _channel = MethodChannel('com.syno/screenshot');

  @override
  void initState() {
    super.initState();
    _listenForNewMessages();
    _enableScreenshotProtection();
    _markAsRead();
  }

  void _markAsRead() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(chatActionsProvider).markAsRead(widget.match.backendMatchId.toString());
      ref.invalidate(chatsFromBackendProvider);
    });
  }

  void _enableScreenshotProtection() {
    try {
      _channel.invokeMethod('enableProtection');
    } catch (e) {
      debugPrint('[ChatScreen] Screenshot protection not available: $e');
    }
  }

  void _disableScreenshotProtection() {
    try {
      _channel.invokeMethod('disableProtection');
    } catch (e) {
      debugPrint('[ChatScreen] Screenshot protection not available: $e');
    }
  }

  void _listenForNewMessages() {
    _wsSubscription = ref.read(webSocketServiceProvider).messages.listen((WebSocketMessage msg) {
      if (msg.type == 'new_message') {
        ref.refresh(chatMessagesProvider(widget.match.backendMatchId.toString()));
        ref.invalidate(chatsFromBackendProvider);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _wsSubscription?.cancel();
    _disableScreenshotProtection();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage() async {
    if (_editingMessage != null) {
      if (_messageController.text.trim().isEmpty) return;
      await ref.read(chatActionsProvider).editMessage(
        widget.match.backendMatchId.toString(),
        _editingMessage!.id,
        _messageController.text.trim(),
      );
      setState(() {
        _editingMessage = null;
      });
    } else if (_replyToMessage != null) {
      final String content = _messageController.text.trim().isEmpty
          ? ''
          : _messageController.text.trim();
      final String replyPrefix = '> ${_replyToMessage!.content ?? "Media"}\n\n';
      await ref.read(chatActionsProvider).sendMessage(
        widget.match.backendMatchId.toString(),
        replyPrefix + content,
      );
      setState(() {
        _replyToMessage = null;
      });
    } else {
      if (_messageController.text.trim().isEmpty) return;
      await ref.read(chatActionsProvider).sendMessage(
        widget.match.backendMatchId.toString(),
        _messageController.text.trim(),
      );
    }

    _messageController.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _cancelReply() {
    setState(() {
      _replyToMessage = null;
      _editingMessage = null;
    });
  }

  void _showMessageActions(ChatMessage message, bool isMe) {
    final AppThemeData theme = ref.read(themeProvider);
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                margin: const EdgeInsets.only(top: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.primaryTextColor.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              if (message.content != null) ...<Widget>[
                ListTile(
                  leading: Icon(Icons.copy, color: theme.primaryTextColor),
                  title: Text('chat.copy'.tr(), style: TextStyle(color: theme.primaryTextColor)),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    Clipboard.setData(ClipboardData(text: message.content!));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('chat.copied'.tr())),
                    );
                  },
                ),
                if (isMe) ...<Widget>[
                  ListTile(
                    leading: Icon(Icons.edit, color: theme.primaryTextColor),
                    title: Text('chat.edit'.tr(), style: TextStyle(color: theme.primaryTextColor)),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      setState(() {
                        _editingMessage = message;
                        _messageController.text = message.content ?? '';
                      });
                    },
                  ),
                ],
              ],
              ListTile(
                leading: Icon(Icons.reply, color: theme.primaryTextColor),
                title: Text('chat.reply'.tr(), style: TextStyle(color: theme.primaryTextColor)),
                onTap: () {
                  Navigator.pop(sheetContext);
                  setState(() {
                    _replyToMessage = message;
                  });
                },
              ),
              ListTile(
                leading: Icon(Icons.forward, color: theme.primaryTextColor),
                title: Text('chat.forward'.tr(), style: TextStyle(color: theme.primaryTextColor)),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _showForwardDialog(message);
                },
              ),
              if (isMe) ...<Widget>[
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: Text('chat.delete_for_me'.tr(), style: const TextStyle(color: Colors.red)),
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    await ref.read(chatActionsProvider).deleteMessage(widget.match.backendMatchId.toString(), message.id);
                  },
                ),
              ],
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  void _showForwardDialog(ChatMessage message) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text('chat.forward_message'.tr()),
          content: Text('chat.select_chat'.tr()),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text('chat.cancel'.tr()),
            ),
          ],
        );
      },
    );
  }

  Future<void> _pickImage() async {
    final XFile? image = await _imagePicker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (image != null) {
      _showUploadDialog(File(image.path), 'image');
    }
  }

  Future<void> _pickVideo() async {
    final XFile? video = await _imagePicker.pickVideo(source: ImageSource.gallery, maxDuration: const Duration(seconds: 30));
    if (video != null) {
      _showUploadDialog(File(video.path), 'video');
    }
  }

  Future<void> _takePhoto() async {
    final XFile? photo = await _imagePicker.pickImage(source: ImageSource.camera, imageQuality: 80);
    if (photo != null) {
      _showUploadDialog(File(photo.path), 'image');
    }
  }

  void _showUploadDialog(File file, String type) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Theme.of(context).cardColor,
          title: Text(type == 'image' ? 'chat.send_image'.tr() : 'chat.send_video'.tr()),
          content: type == 'image'
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(file, height: 200, fit: BoxFit.cover),
                )
              : const Icon(Icons.videocam, size: 100, color: Colors.blue),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: Text('chat.cancel'.tr())),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _uploadAndSendMedia(file, type);
              },
              child: Text('chat.send'.tr()),
            ),
          ],
        );
      },
    );
  }

  Future<void> _uploadAndSendMedia(File file, String type) async {
    await ref.read(chatActionsProvider).uploadAndSendMedia(widget.match.backendMatchId.toString(), file, messageType: type);
  }

  void _showDeleteChatDialog(BuildContext context, AppThemeData theme) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: Theme.of(dialogContext).cardColor,
          title: Text('chat.delete_chat_confirm_title'.tr(), style: TextStyle(color: theme.primaryTextColor)),
          content: Text('chat.delete_chat_confirm_message'.tr(), style: TextStyle(color: theme.primaryTextColor.withOpacity(0.7))),
          actions: <Widget>[
            TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: Text('chat.cancel'.tr(), style: TextStyle(color: theme.primaryTextColor))),
            TextButton(
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                await _deleteChat();
              },
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteChat() async {
    try {
      final String? token = await _getToken();
      final String? baseUrl = await _getBackendUrl();
      if (token != null && baseUrl != null) {
        final Dio dio = Dio();
        await dio.delete(
          '$baseUrl/api/messages/${widget.match.backendMatchId}',
          options: Options(headers: {'Authorization': 'Bearer $token'}),
        );
        ref.invalidate(chatMessagesProvider(widget.match.backendMatchId.toString()));
        ref.invalidate(chatsFromBackendProvider);
        if (mounted) {
          context.pop();
        }
      }
    } catch (e) {
      debugPrint('[ChatScreen] Error deleting chat: $e');
    }
  }

  Future<String?> _getToken() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  Future<String?> _getBackendUrl() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('backend_url');
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<User?> currentUserAsync = ref.watch(currentUserProvider);
    final AppThemeData theme = ref.watch(themeProvider);
    final AsyncValue<List<ChatMessage>> messagesAsync = ref.watch(chatMessagesProvider(widget.match.backendMatchId.toString()));
    final AsyncValue<bool> isBlockedAsync = ref.watch(isUserBlockedProvider(widget.match.matchedUserId));

    return Scaffold(
      appBar: _buildAppBar(context, theme, isBlockedAsync),
      body: Container(
        decoration: BoxDecoration(
          color: theme.gradient.colors.last.withOpacity(0.3),
        ),
        child: Column(
          children: <Widget>[
            isBlockedAsync.when(
              data: (bool isBlocked) => isBlocked ? _buildBlockedBanner(context, theme) : const SizedBox.shrink(),
              loading: () => const SizedBox.shrink(),
              error: (Object e, _) => const SizedBox.shrink(),
            ),
            Expanded(
              child: currentUserAsync.when(
                data: (User? currentUser) {
                  if (currentUser == null) return Center(child: Text('chat.no_user'.tr()));
                  return messagesAsync.when(
                    data: (List<ChatMessage> messages) => _buildMessagesList(context, messages, currentUser.id.toString(), theme),
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (Object error, StackTrace stack) => Center(child: Text('chat.error'.tr(args: <String>[error.toString()]))),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (Object error, StackTrace stack) => Center(child: Text('chat.error'.tr(args: <String>[error.toString()]))),
              ),
            ),
            if (_replyToMessage != null || _editingMessage != null) _buildReplyBanner(theme),
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

  PreferredSizeWidget _buildAppBar(BuildContext context, AppThemeData theme, AsyncValue<bool> isBlockedAsync) {
    final chatsAsync = ref.watch(chatsFromBackendProvider);
    String statusText = 'Tap to see profile';
    Color statusColor = Colors.white54;
    bool isOnline = false;

    chatsAsync.whenData((chats) {
      final chat = chats.where((c) => c.matchedUserId.toString() == widget.match.matchedUserId).toList();
      if (chat.isNotEmpty) {
        final lastActive = chat.first.lastActiveAt;
        if (lastActive != null) {
          final diff = DateTime.now().difference(lastActive);
          if (diff.inMinutes < 5) {
            statusText = 'Active now';
            statusColor = const Color(0xFF43E97B);
            isOnline = true;
          } else if (diff.inMinutes < 60) {
            statusText = 'Active ${diff.inMinutes}m ago';
            statusColor = Colors.white54;
          } else if (diff.inHours < 24) {
            statusText = 'Active ${diff.inHours}h ago';
            statusColor = Colors.white54;
          } else {
            statusText = 'Active ${diff.inDays}d ago';
            statusColor = Colors.white54;
          }
        }
      }
    });

    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => context.pop(),
      ),
      title: GestureDetector(
        onTap: () => context.push('/match-details', extra: widget.match),
        child: Row(
          children: <Widget>[
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.network(
                    widget.match.matchedUser.photos.first.getFullUrl(ref.read(backendUrlProvider)),
                    width: 36,
                    height: 36,
                    fit: BoxFit.cover,
                    errorBuilder: (BuildContext context, Object error, StackTrace? stackTrace) => Container(
                      width: 36,
                      height: 36,
                      color: CosmicColors.cosmicPurple,
                      child: const Icon(Icons.person, size: 18, color: Colors.white),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: isOnline ? const Color(0xFF43E97B) : Colors.grey,
                      shape: BoxShape.circle,
                      border: Border.all(color: CosmicColors.cosmicPurple, width: 1.5),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    widget.match.matchedUser.name.toString(),
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  Text(
                    statusText,
                    style: TextStyle(fontSize: 11, color: statusColor),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: Colors.white),
          onSelected: (String value) {
            if (value == 'block') {
              _showBlockDialog(theme);
            } else if (value == 'delete_chat') {
              _showDeleteChatDialog(context, theme);
            }
          },
          itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
            PopupMenuItem<String>(
              value: 'block',
              child: ListTile(
                leading: const Icon(Icons.block, color: Colors.red),
                title: Text('chat.block_user'.tr(namedArgs: <String, String>{'name': widget.match.matchedUser.name.toString()}), style: const TextStyle(color: Colors.red)),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            PopupMenuItem<String>(
              value: 'delete_chat',
              child: ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.orange),
                title: Text('chat.delete_chat'.tr(), style: const TextStyle(color: Colors.orange)),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
      ],
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [CosmicColors.cosmicPurple, CosmicColors.deepSpace],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      ),
    );
  }

  void _showBlockDialog(AppThemeData theme) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: Theme.of(dialogContext).cardColor,
          title: Text('chat.block_user'.tr(namedArgs: <String, String>{'name': widget.match.matchedUser.name.toString()}), style: TextStyle(color: theme.primaryTextColor)),
          content: Text('chat.block_subtitle'.tr(), style: TextStyle(color: theme.primaryTextColor.withOpacity(0.7))),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text('chat.cancel'.tr())),
            TextButton(
              onPressed: () async {
                Navigator.pop(dialogContext);
                await ref.read(blockActionsProvider).block(widget.match.matchedUserId);
                if (mounted) {
                  _showBlockConfirmation(theme);
                }
              },
              child: const Text('Block', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  void _showBlockConfirmation(AppThemeData theme) {
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'Block confirmation',
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (BuildContext ctx, Animation<double> animation, Animation<double> secondaryAnimation) {
        return Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: 300,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
              margin: const EdgeInsets.symmetric(horizontal: 32),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E2E),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.4),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.block, color: Colors.red, size: 28),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.match.matchedUser.name.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'has been blocked',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'They can no longer see your profile or message you',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.35),
                      fontSize: 12,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  GestureDetector(
                    onTap: () {
                      Navigator.pop(ctx);
                      context.pop();
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(
                        child: Text(
                          'OK',
                          style: TextStyle(
                            color: Colors.red,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
      transitionBuilder: (BuildContext ctx, Animation<double> animation, Animation<double> secondaryAnimation, Widget child) {
        return FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: ScaleTransition(
            scale: CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
            child: child,
          ),
        );
      },
    );
  }

  Widget _buildBlockedBanner(BuildContext context, AppThemeData theme) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withOpacity(0.4)),
      ),
      child: Row(
        children: <Widget>[
          const Icon(Icons.block, color: Colors.red, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'chat.blocked_banner'.tr(),
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBlockedFooter(BuildContext context, AppThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: theme.backgroundColor,
        border: Border(top: BorderSide(color: theme.primaryTextColor.withOpacity(0.1))),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  'chat.blocked_footer'.tr(),
                  style: TextStyle(color: theme.primaryTextColor.withOpacity(0.7), fontSize: 13),
                ),
              ),
              TextButton.icon(
                onPressed: () async {
                  await ref.read(blockActionsProvider).unblock(widget.match.matchedUserId);
                },
                icon: Icon(Icons.lock_open, color: theme.primaryTextColor, size: 18),
                label: Text('chat.unblock_button'.tr(), style: TextStyle(color: theme.primaryTextColor)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReplyBanner(AppThemeData theme) {
    final bool isEditing = _editingMessage != null;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: CosmicColors.cosmicPurple.withOpacity(0.2),
        border: Border(
          left: BorderSide(color: CosmicColors.cosmicPurple, width: 3),
        ),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            isEditing ? Icons.edit : Icons.reply,
            color: CosmicColors.cosmicPurple,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  isEditing ? 'chat.editing'.tr() : 'chat.replying_to'.tr(namedArgs: <String, String>{'name': widget.match.matchedUser.name.toString()}),
                  style: TextStyle(
                    color: CosmicColors.cosmicPurple,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  (isEditing ? _editingMessage : _replyToMessage)?.content ?? 'Media',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: theme.primaryTextColor.withOpacity(0.7), fontSize: 13),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.close, color: theme.primaryTextColor, size: 20),
            onPressed: _cancelReply,
          ),
        ],
      ),
    );
  }

  Widget _buildMessagesList(BuildContext context, List<ChatMessage> messages, String currentUserId, AppThemeData theme) {
    if (messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.06),
              ),
              child: Icon(Icons.chat_bubble_rounded, size: 56, color: Colors.white.withOpacity(0.15)),
            ),
            const SizedBox(height: 20),
            Text(
              'chat.start_conversation'.tr(),
              style: TextStyle(color: theme.primaryTextColor, fontSize: 17, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              'chat.say_hello'.tr(namedArgs: <String, String>{'name': widget.match.matchedUser.name.toString()}),
              style: TextStyle(color: theme.primaryTextColor.withOpacity(0.4), fontSize: 13),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      itemCount: messages.length,
      itemBuilder: (BuildContext context, int index) {
        final ChatMessage message = messages[index];
        final bool isMe = message.senderId == currentUserId;
        final bool isLast = index == messages.length - 1;
        final bool isFirst = index == 0;
        final bool showDivider = isFirst || (index > 0 && _shouldShowDivider(messages[index - 1].timestamp, message.timestamp));
        final bool isGrouped = !showDivider && !isLast && index < messages.length - 1 && messages[index + 1].senderId == message.senderId;

        return Column(
          children: <Widget>[
            if (showDivider) _buildTimeDivider(message.timestamp, theme),
            _buildMessengerBubble(context, message, isMe, isLast, isGrouped, theme),
          ],
        );
      },
    );
  }

  bool _shouldShowDivider(DateTime prev, DateTime current) {
    return current.difference(prev).inMinutes > 5 ||
        prev.day != current.day ||
        prev.month != current.month ||
        prev.year != current.year;
  }

  String _formatDividerDate(DateTime time) {
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    final DateTime messageDay = DateTime(time.year, time.month, time.day);
    final int diffDays = today.difference(messageDay).inDays;

    if (diffDays == 0) return 'Today';
    if (diffDays == 1) return 'Yesterday';
    if (diffDays < 7) {
      const List<String> days = <String>['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
      return days[time.weekday % 7];
    }
    if (time.year == now.year) {
      return DateFormat('MMMM d').format(time);
    }
    return DateFormat('MMMM d, yyyy').format(time);
  }

  String _formatFullTimestamp(DateTime time) {
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    final DateTime messageDay = DateTime(time.year, time.month, time.day);
    final int diffDays = today.difference(messageDay).inDays;

    final String timeStr = DateFormat('h:mm a').format(time);
    if (diffDays == 0) return 'Today at $timeStr';
    if (diffDays == 1) return 'Yesterday at $timeStr';
    if (diffDays < 7) {
      const List<String> days = <String>['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
      return '${days[time.weekday % 7]} at $timeStr';
    }
    return '${DateFormat('MMM d, yyyy').format(time)} at $timeStr';
  }

  Widget _buildTimeDivider(DateTime time, AppThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.25),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            _formatDividerDate(time),
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  void _showFullTimestamp(BuildContext context, ChatMessage message) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E2E),
            borderRadius: BorderRadius.circular(16),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                Icon(
                  Icons.access_time_rounded,
                  color: Colors.white.withOpacity(0.5),
                  size: 28,
                ),
                const SizedBox(height: 10),
                Text(
                  _formatFullTimestamp(message.timestamp),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat('EEEE, MMMM d, yyyy').format(message.timestamp),
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat('HH:mm:ss').format(message.timestamp),
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.4),
                    fontSize: 12,
                    fontFamily: 'monospace',
                  ),
                ),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(
                      child: Text(
                        'Close',
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMessengerBubble(BuildContext context, ChatMessage message, bool isMe, bool isLast, bool isGrouped, AppThemeData theme) {
    return GestureDetector(
      onLongPress: () => _showMessageActions(message, isMe),
      onTap: () => _showFullTimestamp(context, message),
      child: Padding(
        padding: EdgeInsets.only(bottom: isGrouped ? 1 : 6),
        child: Row(
          mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            if (!isMe && isLast) ...<Widget>[
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.network(
                  widget.match.matchedUser.photos.first.getFullUrl(ref.read(backendUrlProvider)),
                  width: 26,
                  height: 26,
                  fit: BoxFit.cover,
                  errorBuilder: (BuildContext context, Object error, StackTrace? stackTrace) => Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [CosmicColors.cosmicPurple, CosmicColors.cosmicPink]),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.person, size: 14, color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(width: 6),
            ],
            if (!isMe && !isLast) const SizedBox(width: 32),
            Flexible(
              child: Column(
                crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: <Widget>[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isMe
                          ? const Color(0xFF6C63FF)
                          : const Color(0xFF2A2A3E),
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(18),
                        topRight: const Radius.circular(18),
                        bottomLeft: Radius.circular(isMe ? 18 : 4),
                        bottomRight: Radius.circular(isMe ? 4 : 18),
                      ),
                    ),
                    child: _buildBubbleContent(context, message, isMe, theme),
                  ),
                  if (!isGrouped || isLast) ...<Widget>[
                    const SizedBox(height: 3),
                    _buildMessageTimestampRow(message, isMe, theme),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageTimestampRow(ChatMessage message, bool isMe, AppThemeData theme) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (message.isEdited)
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Text(
              'edited',
              style: TextStyle(
                color: Colors.white.withOpacity(0.4),
                fontSize: 10,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        Text(
          DateFormat('h:mm a').format(message.timestamp),
          style: TextStyle(
            color: Colors.white.withOpacity(0.4),
            fontSize: 10,
          ),
        ),
        if (isMe) ...<Widget>[
          const SizedBox(width: 4),
          Icon(
            message.isRead ? Icons.done_all : Icons.done,
            size: 14,
            color: message.isRead ? const Color(0xFF53BDED) : Colors.white.withOpacity(0.4),
          ),
        ],
      ],
    );
  }

  Widget _buildBubbleContent(BuildContext context, ChatMessage message, bool isMe, AppThemeData theme) {
    if (message.imageUrl != null) {
      return _buildImageContent(context, message, isMe, theme);
    }
    if (message.videoUrl != null) {
      return _buildVideoContent(context, message, isMe, theme);
    }
    if (message.gifUrl != null) {
      return _buildGifContent(context, message, isMe, theme);
    }
    return _buildTextContent(context, message, isMe, theme);
  }

  Widget _buildTextContent(BuildContext context, ChatMessage message, bool isMe, AppThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (message.content != null && message.content!.startsWith('> '))
          Container(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              message.content!.split('\n\n').first.replaceAll('> ', ''),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: (isMe ? Colors.white : theme.primaryTextColor).withOpacity(0.6),
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        Text(
          message.content?.replaceAll(RegExp(r'^> .+\n\n'), '') ?? '',
          style: TextStyle(
            color: isMe ? Colors.white : theme.primaryTextColor,
            fontSize: 14.5,
            height: 1.3,
          ),
        ),
      ],
    );
  }

  Widget _buildImageContent(BuildContext context, ChatMessage message, bool isMe, AppThemeData theme) {
    final String? baseUrl = ref.read(backendUrlProvider);
    final String imageUrl = message.imageUrl!.startsWith('http')
        ? message.imageUrl!
        : '$baseUrl${message.imageUrl!}';

    return GestureDetector(
      onTap: () => _showFullScreenImage(context, imageUrl),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          imageUrl,
          width: 200,
          height: 200,
          fit: BoxFit.cover,
          loadingBuilder: (BuildContext context, Widget child, ImageChunkEvent? loadingProgress) {
            if (loadingProgress == null) return child;
            return SizedBox(
              width: 200,
              height: 200,
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            );
          },
          errorBuilder: (BuildContext context, Object error, StackTrace? stackTrace) => Container(
            width: 200,
            height: 200,
            color: Colors.grey[800],
            child: const Icon(Icons.broken_image, size: 40, color: Colors.white54),
          ),
        ),
      ),
    );
  }

  Widget _buildVideoContent(BuildContext context, ChatMessage message, bool isMe, AppThemeData theme) {
    return GestureDetector(
      onTap: () => _playVideo(context, message.videoUrl!),
      child: Container(
        width: 220,
        height: 160,
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(Icons.play_circle_fill, size: 48, color: Colors.white),
              SizedBox(height: 8),
              Text('Tap to play', style: TextStyle(color: Colors.white70, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGifContent(BuildContext context, ChatMessage message, bool isMe, AppThemeData theme) {
    final String? baseUrl = ref.read(backendUrlProvider);
    final String gifUrl = message.gifUrl!.startsWith('http')
        ? message.gifUrl!
        : '$baseUrl${message.gifUrl!}';

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.network(
        gifUrl,
        width: 180,
        height: 180,
        fit: BoxFit.cover,
        errorBuilder: (BuildContext context, Object error, StackTrace? stackTrace) => Container(
          width: 180,
          height: 180,
          color: Colors.grey[800],
          child: const Icon(Icons.broken_image, size: 40, color: Colors.white54),
        ),
      ),
    );
  }

  void _showFullScreenImage(BuildContext context, String imageUrl) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (BuildContext context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(backgroundColor: Colors.black, iconTheme: const IconThemeData(color: Colors.white)),
          body: Center(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: Image.network(imageUrl, fit: BoxFit.contain),
            ),
          ),
        ),
      ),
    );
  }

  void _playVideo(BuildContext context, String videoUrl) {
    final String? baseUrl = ref.read(backendUrlProvider);
    final String fullUrl = videoUrl.startsWith('http') ? videoUrl : '$baseUrl$videoUrl';
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (BuildContext context) => VideoPlayerScreen(videoUrl: fullUrl),
      ),
    );
  }

  Widget _buildMessageInput(BuildContext context, AppThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: theme.backgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: <Widget>[
            if (_showEmojiPicker)
              SizedBox(
                height: 250,
                child: _buildEmojiPicker(theme),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  IconButton(
                    icon: Icon(Icons.add_circle_outline, color: CosmicColors.cosmicPurple, size: 26),
                    onPressed: () => _showMediaPickerSheet(context, theme),
                  ),
                  Expanded(
                    child: Container(
                      constraints: const BoxConstraints(maxHeight: 120),
                      decoration: BoxDecoration(
                        color: theme.primaryTextColor.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: TextField(
                        controller: _messageController,
                        maxLines: null,
                        keyboardType: TextInputType.multiline,
                        style: TextStyle(color: theme.primaryTextColor, fontSize: 15),
                        decoration: InputDecoration(
                          hintText: _editingMessage != null ? 'chat.edit_hint'.tr() : 'chat.message_hint'.tr(),
                          hintStyle: TextStyle(color: theme.primaryTextColor.withOpacity(0.4)),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _showEmojiPicker ? Icons.keyboard : Icons.emoji_emotions_outlined,
                              color: CosmicColors.cosmicPurple,
                              size: 22,
                            ),
                            onPressed: () {
                              setState(() {
                                _showEmojiPicker = !_showEmojiPicker;
                              });
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: _sendMessage,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        gradient: CosmicColors.cosmicGradient,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.send, color: Colors.white, size: 18),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmojiPicker(AppThemeData theme) {
    final List<String> emojis = [
      '😀', '😂', '😍', '🥰', '😘', '😎', '🤩', '🥳', '😏', '😊',
      '😉', '🤔', '😴', '🤗', '😈', '👻', '💀', '🤡', '👽', '❤️',
      '🧡', '💛', '💚', '💙', '💜', '🖤', '💔', '💕', '💞', '💓',
      '💗', '💖', '💘', '💝', '✨', '⭐', '🌟', '💫', '🔥', '💥',
      '🎉', '🎊', '🎈', '🎵', '🎶', '🎸', '🎤', '💃', '🕺', '🌹',
    ];

    return Container(
      color: theme.backgroundColor,
      child: GridView.builder(
        padding: const EdgeInsets.all(8),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 8,
          mainAxisSpacing: 4,
          crossAxisSpacing: 4,
        ),
        itemCount: emojis.length,
        itemBuilder: (BuildContext context, int index) {
          return GestureDetector(
            onTap: () {
              _messageController.text += emojis[index];
            },
            child: Center(
              child: Text(emojis[index], style: const TextStyle(fontSize: 24)),
            ),
          );
        },
      ),
    );
  }

  void _showMediaPickerSheet(BuildContext context, AppThemeData theme) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.primaryTextColor.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.photo_library, color: Colors.blue),
                  ),
                  title: Text('chat.gallery'.tr()),
                  onTap: () { Navigator.pop(context); _pickImage(); },
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.camera_alt, color: Colors.green),
                  ),
                  title: Text('chat.camera'.tr()),
                  onTap: () { Navigator.pop(context); _takePhoto(); },
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.videocam, color: Colors.orange),
                  ),
                  title: Text('chat.video'.tr()),
                  onTap: () { Navigator.pop(context); _pickVideo(); },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class VideoPlayerScreen extends StatefulWidget {
  final String videoUrl;
  const VideoPlayerScreen({super.key, required this.videoUrl});

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl))
      ..initialize().then((_) {
        setState(() { _isInitialized = true; });
        _controller.play();
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, iconTheme: const IconThemeData(color: Colors.white)),
      body: Center(
        child: _isInitialized
            ? AspectRatio(aspectRatio: _controller.value.aspectRatio, child: VideoPlayer(_controller))
            : const CircularProgressIndicator(),
      ),
      floatingActionButton: _isInitialized
          ? FloatingActionButton(
              backgroundColor: CosmicColors.cosmicPurple,
              onPressed: () {
                setState(() {
                  _controller.value.isPlaying ? _controller.pause() : _controller.play();
                });
              },
              child: Icon(_controller.value.isPlaying ? Icons.pause : Icons.play_arrow, color: Colors.white),
            )
          : null,
    );
  }
}
