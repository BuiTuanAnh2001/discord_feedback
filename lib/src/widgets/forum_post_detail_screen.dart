import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../models/models.dart';
import '../services/discord_gateway.dart';
import '../services/discord_service.dart';
import '../theme/discord_feedback_theme.dart';
import 'message_bubble.dart';

class ForumPostDetailScreen extends StatefulWidget {
  final DiscordService service;
  final ForumThread thread;
  final List<ForumTag> availableTags;
  final DiscordFeedbackTheme theme;
  final DiscordGateway? gateway;

  const ForumPostDetailScreen({
    super.key,
    required this.service,
    required this.thread,
    required this.availableTags,
    this.theme = DiscordFeedbackTheme.dark,
    this.gateway,
  });

  @override
  State<ForumPostDetailScreen> createState() => _ForumPostDetailScreenState();
}

class _ForumPostDetailScreenState extends State<ForumPostDetailScreen> {
  final _replyCtrl = TextEditingController();
  final _picker = ImagePicker();
  final _scrollCtrl = ScrollController();

  List<DiscordMessage> _messages = [];
  List<XFile> _pendingFiles = [];
  bool _isLoading = true;
  bool _isSending = false;
  String? _error;

  final List<StreamSubscription> _subs = [];

  DiscordFeedbackTheme get t => widget.theme;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _initRealtime();
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _replyCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _initRealtime() {
    final gw = widget.gateway;
    if (gw == null) return;
    final threadId = widget.thread.id;

    _subs.addAll([
      gw.onMessageCreate.listen((msg) {
        if (!mounted || msg.channelId != threadId) return;
        if (msg.author.id == gw.botUserId) return;
        setState(() => _messages.add(msg));
        _scrollToBottom();
      }),
      gw.onMessageUpdate.listen((msg) {
        if (!mounted || msg.channelId != threadId) return;
        setState(() {
          final i = _messages.indexWhere((m) => m.id == msg.id);
          if (i != -1) _messages[i] = msg;
        });
      }),
      gw.onMessageDelete.listen((id) {
        if (!mounted) return;
        setState(() => _messages.removeWhere((m) => m.id == id));
      }),
    ]);
  }

  Future<void> _loadMessages() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final msgs = await widget.service
          .getThreadMessages(threadId: widget.thread.id, limit: 50);
      if (!mounted) return;
      setState(() {
        _messages = msgs.reversed.toList();
        _isLoading = false;
      });
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _isLoading = false;
      });
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut);
      }
    });
  }

  Future<void> _sendReply() async {
    final text = _replyCtrl.text.trim();
    if (text.isEmpty && _pendingFiles.isEmpty) return;
    setState(() => _isSending = true);
    try {
      final msg = await widget.service.sendThreadMessage(
        threadId: widget.thread.id,
        content: text,
        attachments: _pendingFiles.isNotEmpty ? _pendingFiles : null,
      );
      _replyCtrl.clear();
      setState(() {
        _messages.add(msg);
        _pendingFiles = [];
        _isSending = false;
      });
      _scrollToBottom();
    } catch (e) {
      setState(() => _isSending = false);
      _snack('$e', isError: true);
    }
  }

  Future<void> _pickImages() async {
    final images = await _picker.pickMultiImage(
        imageQuality: 85, maxWidth: 1920, maxHeight: 1920);
    if (images.isNotEmpty) setState(() => _pendingFiles.addAll(images));
  }

  Future<void> _takePhoto() async {
    final photo = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        maxWidth: 1920,
        maxHeight: 1920);
    if (photo != null) setState(() => _pendingFiles.add(photo));
  }

  void _snack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        Icon(isError ? Icons.error_outline : Icons.check_circle,
            color: Colors.white, size: 20),
        const SizedBox(width: 8),
        Flexible(
            child: Text(msg, style: const TextStyle(color: Colors.white))),
      ]),
      backgroundColor: isError ? t.dangerColor : t.accent,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      margin: const EdgeInsets.all(12),
    ));
  }

  ForumTag? _findTag(String tagId) {
    try {
      return widget.availableTags.firstWhere((tag) => tag.id == tagId);
    } catch (_) {
      return null;
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: t.bgPrimary,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(child: _buildBody()),
          if (_pendingFiles.isNotEmpty) _filePreview(),
          _replyBar(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final thread = widget.thread;
    final tags = thread.appliedTags
        .map(_findTag)
        .whereType<ForumTag>()
        .map(_headerTag)
        .toList();

    return Container(
      color: t.bgSecondary,
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 12, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back_ios_new_rounded,
                        color: t.textSecondary, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Spacer(),
                  if (widget.gateway != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: widget.gateway!.isConnected
                              ? t.successColor
                              : t.warningColor,
                        ),
                      ),
                    ),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: thread.name));
                        _snack('Đã sao chép tiêu đề');
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Icon(Icons.copy_rounded,
                            color: t.textSecondary, size: 20),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(thread.name,
                      style: TextStyle(
                          color: t.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          height: 1.3),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis),
                  if (tags.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(spacing: 6, runSpacing: 4, children: tags),
                  ],
                  const SizedBox(height: 6),
                  Text(
                    '${_messages.isEmpty ? thread.messageCount : _messages.length} messages · ${DateFormat('MMM d, yyyy').format(thread.createdAt)}',
                    style: TextStyle(fontSize: 12, color: t.textMuted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _headerTag(ForumTag tag) {
    final color = t.tagColor(tag.name);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (tag.emojiName != null) ...[
            Text(tag.emojiName!, style: const TextStyle(fontSize: 11)),
            const SizedBox(width: 3),
          ],
          Text(tag.name,
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(
          child: CircularProgressIndicator(
              strokeWidth: 3, color: t.accent.withValues(alpha: 0.7)));
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline_rounded, size: 48, color: t.textMuted),
              const SizedBox(height: 16),
              Text(_error!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: t.textMuted)),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _loadMessages,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Thử lại'),
                style: FilledButton.styleFrom(backgroundColor: t.accent),
              ),
            ],
          ),
        ),
      );
    }
    if (_messages.isEmpty) {
      return Center(
          child: Text('Không có tin nhắn',
              style: TextStyle(color: t.textMuted, fontSize: 14)));
    }

    return ListView.builder(
      controller: _scrollCtrl,
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 8),
      itemCount: _messages.length,
      itemBuilder: (_, i) => MessageBubble(
        message: _messages[i],
        theme: t,
        isFirst: i == 0,
      ),
    );
  }

  // ── Bottom bar ─────────────────────────────────────────────────────────────

  Widget _filePreview() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: t.bgSecondary,
      child: SizedBox(
        height: 68,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: _pendingFiles.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (_, i) => Stack(
            clipBehavior: Clip.none,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(File(_pendingFiles[i].path),
                    width: 68, height: 68, fit: BoxFit.cover),
              ),
              Positioned(
                top: -4,
                right: -4,
                child: GestureDetector(
                  onTap: () => setState(() => _pendingFiles.removeAt(i)),
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                        color: t.dangerColor, shape: BoxShape.circle),
                    child: const Icon(Icons.close,
                        size: 14, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _replyBar() {
    return Container(
      padding: EdgeInsets.only(
          left: 12,
          right: 12,
          top: 8,
          bottom: MediaQuery.of(context).padding.bottom + 8),
      color: t.bgSecondary,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: _showAttachmentOptions,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Icon(Icons.add_circle_outline_rounded,
                    size: 24,
                    color:
                        _pendingFiles.isNotEmpty ? t.accent : t.textMuted),
              ),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Container(
              constraints: const BoxConstraints(maxHeight: 120),
              child: TextField(
                controller: _replyCtrl,
                maxLines: null,
                style: TextStyle(color: t.textPrimary, fontSize: 15),
                decoration: InputDecoration(
                  hintText: 'Message...',
                  hintStyle: TextStyle(color: t.textMuted, fontSize: 15),
                  filled: true,
                  fillColor: t.inputBg,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide.none),
                ),
                textInputAction: TextInputAction.newline,
              ),
            ),
          ),
          const SizedBox(width: 4),
          Material(
            color: t.accent,
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: _isSending ? null : _sendReply,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: _isSending
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.send_rounded,
                        color: Colors.white, size: 22),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAttachmentOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: t.bgSecondary,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                  color: t.textMuted.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: Icon(Icons.photo_library_rounded,
                  color: t.accent, size: 22),
              title:
                  Text('Gallery', style: TextStyle(color: t.textPrimary)),
              onTap: () {
                Navigator.pop(ctx);
                _pickImages();
              },
            ),
            ListTile(
              leading: Icon(Icons.camera_alt_rounded,
                  color: t.warningColor, size: 22),
              title:
                  Text('Camera', style: TextStyle(color: t.textPrimary)),
              onTap: () {
                Navigator.pop(ctx);
                _takePhoto();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
