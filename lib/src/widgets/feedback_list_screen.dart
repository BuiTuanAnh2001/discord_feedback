import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../models/models.dart';
import '../services/discord_gateway.dart';
import '../services/discord_service.dart';
import 'feedback_detail_screen.dart';
import 'reaction_overlay.dart';

class FeedbackListScreen extends StatefulWidget {
  final DiscordService service;
  final String channelId;
  final String title;
  final Color accentColor;
  final List<String> quickEmojis;
  final bool enableImagePicker;

  /// Bật realtime qua Discord Gateway WebSocket.
  final bool enableRealtime;

  const FeedbackListScreen({
    super.key,
    required this.service,
    required this.channelId,
    this.title = 'Feedback',
    this.accentColor = const Color(0xFF5865F2),
    this.quickEmojis = const ['👍', '👎', '❤️', '🔥', '👀', '✅'],
    this.enableImagePicker = true,
    this.enableRealtime = false,
  });

  @override
  State<FeedbackListScreen> createState() => _FeedbackListScreenState();
}

class _FeedbackListScreenState extends State<FeedbackListScreen> {
  static const _dark = Color(0xFF2C2F33);
  final ScrollController _scrollCtrl = ScrollController();
  final TextEditingController _chatCtrl = TextEditingController();
  final FocusNode _chatFocus = FocusNode();

  final ImagePicker _imagePicker = ImagePicker();
  List<DiscordMessage> _messages = [];
  List<XFile> _pendingAttachments = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _isSending = false;
  String? _error;

  int? _replyingToIndex;
  Color get _accent => widget.accentColor;

  DiscordGateway? _gateway;
  final List<StreamSubscription> _subscriptions = [];
  bool _realtimeConnected = false;

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            _buildAppBar(),
            Expanded(child: _buildBody()),
            if (_pendingAttachments.isNotEmpty) _buildAttachmentPreview(),
            _buildReplyBanner(),
            _buildChatBar(),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _gateway?.dispose();
    _scrollCtrl.dispose();
    _chatCtrl.dispose();
    _chatFocus.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _scrollCtrl.addListener(_onScroll);
    if (widget.enableRealtime) {
      _initGateway();
    }
  }

  void _initGateway() {
    _gateway = DiscordGateway(
      botToken: widget.service.botToken,
      channelId: widget.channelId,
    );

    _subscriptions.addAll([
      _gateway!.onConnectionChanged.listen((connected) {
        if (mounted) setState(() => _realtimeConnected = connected);
      }),
      _gateway!.onMessageCreate.listen((msg) {
        if (!mounted) return;
        // Không thêm tin nhắn do chính bot gửi (đã có trong _sendChat)
        if (msg.author.id == _gateway!.botUserId) return;
        setState(() => _messages.insert(0, msg));
      }),
      _gateway!.onMessageUpdate.listen((msg) {
        if (!mounted) return;
        setState(() {
          final i = _messages.indexWhere((m) => m.id == msg.id);
          if (i != -1) _messages[i] = msg;
        });
      }),
      _gateway!.onMessageDelete.listen((msgId) {
        if (!mounted) return;
        setState(() => _messages.removeWhere((m) => m.id == msgId));
      }),
      _gateway!.onReactionAdd.listen((event) {
        if (!mounted) return;
        // Bỏ qua reaction của chính bot (đã xử lý local)
        if (event.userId == _gateway!.botUserId) return;
        setState(() {
          final i = _messages.indexWhere((m) => m.id == event.messageId);
          if (i == -1) return;
          final msg = _messages[i];
          final rxs = List<DiscordReaction>.from(msg.reactions);
          final ri = rxs.indexWhere((r) => r.emoji.name == event.emoji.name);
          if (ri != -1) {
            rxs[ri] = DiscordReaction(
                count: rxs[ri].count + 1, me: rxs[ri].me, emoji: rxs[ri].emoji);
          } else {
            rxs.add(DiscordReaction(
                count: 1, me: false, emoji: event.emoji));
          }
          _messages[i] = msg.copyWith(reactions: rxs);
        });
      }),
      _gateway!.onReactionRemove.listen((event) {
        if (!mounted) return;
        if (event.userId == _gateway!.botUserId) return;
        setState(() {
          final i = _messages.indexWhere((m) => m.id == event.messageId);
          if (i == -1) return;
          final msg = _messages[i];
          final rxs = List<DiscordReaction>.from(msg.reactions);
          final ri = rxs.indexWhere((r) => r.emoji.name == event.emoji.name);
          if (ri != -1) {
            if (rxs[ri].count <= 1) {
              rxs.removeAt(ri);
            } else {
              rxs[ri] = DiscordReaction(
                  count: rxs[ri].count - 1, me: rxs[ri].me, emoji: rxs[ri].emoji);
            }
          }
          _messages[i] = msg.copyWith(reactions: rxs);
        });
      }),
    ]);

    _gateway!.connect();
  }

  // ── Reactions ─────────────────────────────────────────────────────────────

  Future<void> _addReaction(int idx, String emoji) async {
    final msg = _messages[idx];
    try {
      await widget.service.addReaction(channelId: msg.channelId, messageId: msg.id, emoji: emoji);
      setState(() {
        final rxs = List<DiscordReaction>.from(msg.reactions);
        final i = rxs.indexWhere((r) => r.emoji.name == emoji);
        if (i != -1) {
          rxs[i] = DiscordReaction(count: rxs[i].count + 1, me: true, emoji: rxs[i].emoji);
        } else {
          rxs.add(DiscordReaction(count: 1, me: true, emoji: DiscordEmoji(name: emoji)));
        }
        _messages[idx] = msg.copyWith(reactions: rxs);
      });
    } catch (e) {
      _showError('$e');
    }
  }

  Widget _appBarAction(IconData icon, VoidCallback onTap) {
    return Material(
      color: Colors.white.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(padding: const EdgeInsets.all(10), child: Icon(icon, color: Colors.white, size: 22)),
      ),
    );
  }

  // ── App bar ───────────────────────────────────────────────────────────────

  Widget _buildAppBar() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_accent, HSLColor.fromColor(_accent).withLightness(0.35).toColor()],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 12, 16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.tag, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.title, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: -0.5)),
                    if (!_isLoading && _messages.isNotEmpty)
                      Row(
                        children: [
                          Text('${_messages.length} tin nhắn', style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13)),
                          if (widget.enableRealtime) ...[
                            const SizedBox(width: 8),
                            Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _realtimeConnected ? const Color(0xFF57F287) : Colors.orange,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _realtimeConnected ? 'Live' : 'Đang kết nối...',
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 11),
                            ),
                          ],
                        ],
                      ),
                  ],
                ),
              ),
              _appBarAction(Icons.refresh_rounded, _loadMessages),
            ],
          ),
        ),
      ),
    );
  }

  // ── Bottom widgets ────────────────────────────────────────────────────────

  Widget _buildAttachmentPreview() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: Colors.grey.shade50,
      child: SizedBox(
        height: 72,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: _pendingAttachments.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (_, i) {
            final file = _pendingAttachments[i];
            return Stack(
              clipBehavior: Clip.none,
              children: [
                ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.file(File(file.path), width: 72, height: 72, fit: BoxFit.cover)),
                Positioned(
                  top: -4,
                  right: -4,
                  child: GestureDetector(
                    onTap: () => _removeAttachment(i),
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                      child: const Icon(Icons.close, size: 14, color: Colors.white),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildAvatar(DiscordUser author, double size) {
    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: author.avatarUrl,
        width: size,
        height: size,
        fit: BoxFit.cover,
        placeholder:
            (_, __) => Container(
              width: size,
              height: size,
              decoration: BoxDecoration(color: _accent.withValues(alpha: 0.15), shape: BoxShape.circle),
              child: Icon(Icons.person_rounded, size: size * 0.5, color: _accent.withValues(alpha: 0.5)),
            ),
        errorWidget:
            (_, __, ___) => Container(
              width: size,
              height: size,
              decoration: BoxDecoration(color: _accent.withValues(alpha: 0.15), shape: BoxShape.circle),
              child: Icon(Icons.person_rounded, size: size * 0.5, color: _accent.withValues(alpha: 0.5)),
            ),
      ),
    );
  }

  // ── Body states ───────────────────────────────────────────────────────────

  Widget _buildBody() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(width: 44, height: 44, child: CircularProgressIndicator(strokeWidth: 3, color: _accent.withValues(alpha: 0.6))),
            const SizedBox(height: 20),
            Text('Đang tải...', style: TextStyle(color: Colors.grey.shade500, fontSize: 15)),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: Colors.red.shade50, shape: BoxShape.circle),
                child: Icon(Icons.wifi_off_rounded, size: 40, color: Colors.red.shade400),
              ),
              const SizedBox(height: 20),
              const Text('Không thể kết nối', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: _dark)),
              const SizedBox(height: 8),
              Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade500, fontSize: 14)),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _loadMessages,
                icon: const Icon(Icons.refresh_rounded, size: 20),
                label: const Text('Thử lại'),
                style: FilledButton.styleFrom(
                  backgroundColor: _accent,
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: _accent.withValues(alpha: 0.06), shape: BoxShape.circle),
              child: Icon(Icons.forum_outlined, size: 48, color: _accent.withValues(alpha: 0.4)),
            ),
            const SizedBox(height: 20),
            const Text('Chưa có feedback', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: _dark)),
            const SizedBox(height: 6),
            Text('Gửi tin nhắn đầu tiên vào channel', style: TextStyle(color: Colors.grey.shade500, fontSize: 14)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadMessages,
      color: _accent,
      strokeWidth: 2.5,
      child: ListView.builder(
        controller: _scrollCtrl,
        padding: const EdgeInsets.symmetric(vertical: 6),
        itemCount: _messages.length + (_isLoadingMore ? 1 : 0),
        itemBuilder: (_, index) {
          if (index == _messages.length) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 2.5, color: _accent.withValues(alpha: 0.5))),
              ),
            );
          }
          return _buildMessageItem(index);
        },
      ),
    );
  }

  Widget _buildChatBar() {
    return Container(
      padding: EdgeInsets.only(left: 8, right: 8, top: 8, bottom: MediaQuery.of(context).padding.bottom + 8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, -2))],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (widget.enableImagePicker)
            Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(22),
              child: InkWell(
                borderRadius: BorderRadius.circular(22),
                onTap: _showAttachmentOptions,
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Icon(Icons.add_circle_outline_rounded, size: 26, color: _pendingAttachments.isNotEmpty ? _accent : Colors.grey.shade400),
                ),
              ),
            ),
          Expanded(
            child: Container(
              constraints: const BoxConstraints(maxHeight: 120),
              child: TextField(
                keyboardType: TextInputType.multiline,
                textInputAction: TextInputAction.done,
                controller: _chatCtrl,
                focusNode: _chatFocus,
                maxLines: null,
                decoration: InputDecoration(
                  hintText: _replyingToIndex != null ? 'Nhập phản hồi...' : 'Nhắn gì đó...',
                  hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 15),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: BorderSide(color: _accent.withValues(alpha: 0.5)),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          Material(
            color: _accent,
            borderRadius: BorderRadius.circular(22),
            child: InkWell(
              borderRadius: BorderRadius.circular(22),
              onTap: _isSending ? null : _sendChat,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child:
                    _isSending
                        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.send_rounded, color: Colors.white, size: 24),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Message card ──────────────────────────────────────────────────────────

  Widget _buildMessageItem(int index) {
    final msg = _messages[index];
    final category = _getCategoryLabel(msg.content);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: Builder(
        builder: (cardCtx) {
          return Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap:
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => FeedbackDetailScreen(message: msg, service: widget.service, accentColor: _accent)),
                  ).then((_) => _loadMessages()),
              onLongPress: () {
                final box = cardCtx.findRenderObject() as RenderBox;
                _showReactionOverlay(context, index, box.localToGlobal(Offset.zero), box.size);
              },
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _messageHeader(msg, category, index),
                    if (msg.content.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        msg.content,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 14, color: Color(0xFF4F545C), height: 1.45),
                      ),
                    ],
                    if (msg.hasImages) ...[const SizedBox(height: 10), _imageRow(msg.attachments)],
                    if (msg.hasAttachments && !msg.hasImages) ...[const SizedBox(height: 8), _fileIndicator(msg.attachments.length)],
                    if (msg.hasReactions) ...[const SizedBox(height: 10), _reactionsRow(index, msg.reactions)],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildReplyBanner() {
    if (_replyingToIndex == null || _replyingToIndex! >= _messages.length) {
      return const SizedBox.shrink();
    }
    final msg = _messages[_replyingToIndex!];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(color: _accent.withValues(alpha: 0.06), border: Border(top: BorderSide(color: _accent.withValues(alpha: 0.3)))),
      child: Row(
        children: [
          Icon(Icons.reply_rounded, size: 16, color: _accent),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              text: TextSpan(
                style: const TextStyle(fontSize: 13),
                children: [
                  TextSpan(text: 'Reply ', style: TextStyle(color: Colors.grey.shade500)),
                  TextSpan(text: msg.author.displayName, style: TextStyle(fontWeight: FontWeight.w600, color: _accent)),
                  if (msg.content.isNotEmpty) TextSpan(text: '  "${msg.content}"', style: TextStyle(color: Colors.grey.shade400)),
                ],
              ),
            ),
          ),
          GestureDetector(
            onTap: _cancelReply,
            child: Padding(padding: const EdgeInsets.all(4), child: Icon(Icons.close_rounded, size: 18, color: Colors.grey.shade400)),
          ),
        ],
      ),
    );
  }

  void _cancelReply() => setState(() => _replyingToIndex = null);

  Widget _fileIndicator(int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade200)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.attach_file_rounded, size: 15, color: Colors.grey.shade500),
          const SizedBox(width: 4),
          Text('$count file đính kèm', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
        ],
      ),
    );
  }

  String _formatTimestamp(DateTime ts) {
    final diff = DateTime.now().difference(ts);
    if (diff.inMinutes < 1) return 'Vừa xong';
    if (diff.inHours < 1) return '${diff.inMinutes}p';
    if (diff.inDays < 1) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return DateFormat('dd/MM').format(ts);
  }

  Color _getCategoryColor(String label) {
    switch (label) {
      case 'Bug':
        return const Color(0xFFED4245);
      case 'Feature':
        return const Color(0xFF3B82F6);
      case 'Improve':
        return const Color(0xFFF59E0B);
      default:
        return Colors.grey;
    }
  }

  String _getCategoryLabel(String content) {
    final l = content.toLowerCase();
    if (l.contains('bug') || l.contains('lỗi') || l.contains('error')) {
      return 'Bug';
    }
    if (l.contains('feature') || l.contains('tính năng') || l.contains('request')) {
      return 'Feature';
    }
    if (l.contains('improve') || l.contains('cải thiện') || l.contains('suggest')) {
      return 'Improve';
    }
    return '';
  }

  Widget _imageRow(List<DiscordAttachment> attachments) {
    final images = attachments.where((a) => a.isImage);
    return SizedBox(
      height: 80,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: images.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final img = images.elementAt(i);
          return ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: CachedNetworkImage(
              imageUrl: img.url,
              width: 100,
              height: 80,
              fit: BoxFit.cover,
              placeholder:
                  (_, __) => Container(
                    width: 100,
                    height: 80,
                    color: Colors.grey.shade100,
                    child: const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
                  ),
              errorWidget:
                  (_, __, ___) =>
                      Container(width: 100, height: 80, color: Colors.grey.shade100, child: const Icon(Icons.broken_image_rounded, size: 24)),
            ),
          );
        },
      ),
    );
  }

  Future<void> _loadMessages() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final msgs = await widget.service.getMessages(channelId: widget.channelId, limit: 25);
      if (mounted) {
        setState(() {
          _messages = msgs;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '$e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadMoreMessages() async {
    if (_messages.isEmpty) return;
    setState(() => _isLoadingMore = true);
    try {
      final more = await widget.service.getMessages(channelId: widget.channelId, limit: 25, before: _messages.last.id);
      if (mounted) {
        setState(() {
          _messages.addAll(more);
          _isLoadingMore = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  Widget _messageHeader(DiscordMessage msg, String category, int index) {
    return Row(
      children: [
        _buildAvatar(msg.author, 38),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      msg.author.displayName,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: _dark),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (msg.author.bot == true) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(color: _accent, borderRadius: BorderRadius.circular(3)),
                      child: const Text('BOT', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700)),
                    ),
                  ],
                  const SizedBox(width: 6),
                  Text(_formatTimestamp(msg.timestamp), style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
                ],
              ),
              if (category.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(color: _getCategoryColor(category).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                    child: Text(category, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: _getCategoryColor(category))),
                  ),
                ),
            ],
          ),
        ),
        GestureDetector(
          onTap: () => _setReplyTo(index),
          child: Padding(padding: const EdgeInsets.all(4), child: Icon(Icons.reply_rounded, size: 20, color: Colors.grey.shade400)),
        ),
      ],
    );
  }

  // ── Data ──────────────────────────────────────────────────────────────────

  void _onScroll() {
    if (_scrollCtrl.position.pixels >= _scrollCtrl.position.maxScrollExtent - 200 && !_isLoadingMore && _messages.isNotEmpty) {
      _loadMoreMessages();
    }
  }

  // ── Images ────────────────────────────────────────────────────────────────

  Future<void> _pickImages() async {
    try {
      final images = await _imagePicker.pickMultiImage(imageQuality: 85, maxWidth: 1920, maxHeight: 1920);
      if (images.isNotEmpty) {
        setState(() => _pendingAttachments.addAll(images));
      }
    } catch (e) {
      _showError('Không thể chọn ảnh: $e');
    }
  }

  Widget _reactionsRow(int msgIdx, List<DiscordReaction> reactions) {
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children:
          reactions.map((r) {
            return GestureDetector(
              onTap: () {
                if (r.emoji.name == null) return;
                r.me ? _removeReaction(msgIdx, r.emoji.name!) : _addReaction(msgIdx, r.emoji.name!);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: r.me ? _accent.withValues(alpha: 0.12) : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: r.me ? _accent : Colors.grey.shade200, width: r.me ? 1.5 : 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(r.emoji.name ?? '?', style: const TextStyle(fontSize: 13)),
                    const SizedBox(width: 4),
                    Text('${r.count}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: r.me ? _accent : Colors.grey.shade500)),
                  ],
                ),
              ),
            );
          }).toList(),
    );
  }

  void _removeAttachment(int idx) => setState(() => _pendingAttachments.removeAt(idx));

  Future<void> _removeReaction(int idx, String emoji) async {
    final msg = _messages[idx];
    try {
      await widget.service.removeReaction(channelId: msg.channelId, messageId: msg.id, emoji: emoji);
      setState(() {
        final rxs = List<DiscordReaction>.from(msg.reactions);
        final i = rxs.indexWhere((r) => r.emoji.name == emoji);
        if (i != -1) {
          if (rxs[i].count <= 1) {
            rxs.removeAt(i);
          } else {
            rxs[i] = DiscordReaction(count: rxs[i].count - 1, me: false, emoji: rxs[i].emoji);
          }
        }
        _messages[idx] = msg.copyWith(reactions: rxs);
      });
    } catch (e) {
      _showError('$e');
    }
  }

  Future<void> _sendChat() async {
    final text = _chatCtrl.text.trim();
    if ((text.isEmpty && _pendingAttachments.isEmpty) || _isSending) return;
    setState(() => _isSending = true);
    try {
      String? replyTo;
      if (_replyingToIndex != null && _replyingToIndex! < _messages.length) {
        replyTo = _messages[_replyingToIndex!].id;
      }
      await widget.service.sendMessage(
        channelId: widget.channelId,
        content: text,
        replyToMessageId: replyTo,
        attachments: _pendingAttachments.isNotEmpty ? _pendingAttachments : null,
      );
      _chatCtrl.clear();
      setState(() {
        _replyingToIndex = null;
        _pendingAttachments = [];
        _isSending = false;
      });
      _showSuccess(replyTo != null ? 'Đã phản hồi' : 'Đã gửi tin nhắn');
      await _loadMessages();
    } catch (e) {
      setState(() => _isSending = false);
      _showError('$e');
    }
  }

  // ── Chat ──────────────────────────────────────────────────────────────────

  void _setReplyTo(int idx) {
    setState(() => _replyingToIndex = idx);
    _chatFocus.requestFocus();
  }

  void _showAttachmentOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder:
          (ctx) => Container(
            decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 8),
                  Container(width: 36, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
                  const SizedBox(height: 16),
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: _accent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                      child: Icon(Icons.photo_library, color: _accent, size: 24),
                    ),
                    title: const Text('Chọn ảnh từ thư viện', style: TextStyle(fontWeight: FontWeight.w500)),
                    subtitle: Text('Chọn nhiều ảnh cùng lúc', style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
                    onTap: () {
                      Navigator.pop(ctx);
                      _pickImages();
                    },
                  ),
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                      child: const Icon(Icons.camera_alt, color: Colors.orange, size: 24),
                    ),
                    title: const Text('Chụp ảnh mới', style: TextStyle(fontWeight: FontWeight.w500)),
                    subtitle: Text('Sử dụng camera', style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
                    onTap: () {
                      Navigator.pop(ctx);
                      _takePhoto();
                    },
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(12),
      ),
    );
  }

  // ── Overlay ───────────────────────────────────────────────────────────────

  void _showReactionOverlay(BuildContext ctx, int idx, Offset pos, Size size) {
    HapticFeedback.mediumImpact();
    final overlay = Overlay.of(ctx);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder:
          (_) => ReactionOverlay(
            emojis: widget.quickEmojis,
            anchorPosition: pos,
            cardSize: size,
            onEmojiSelected: (emoji) {
              entry.remove();
              _addReaction(idx, emoji);
            },
            onReply: () {
              entry.remove();
              _setReplyTo(idx);
            },
            onDismiss: () => entry.remove(),
          ),
    );
    overlay.insert(entry);
  }

  void _showSuccess(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [const Icon(Icons.check_circle, color: Colors.white, size: 20), const SizedBox(width: 8), Flexible(child: Text(msg))]),
        backgroundColor: _accent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(12),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _takePhoto() async {
    try {
      final photo = await _imagePicker.pickImage(source: ImageSource.camera, imageQuality: 85, maxWidth: 1920, maxHeight: 1920);
      if (photo != null) setState(() => _pendingAttachments.add(photo));
    } catch (e) {
      _showError('Không thể chụp ảnh: $e');
    }
  }
}
