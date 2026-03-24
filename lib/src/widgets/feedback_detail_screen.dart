import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import '../models/models.dart';
import '../services/discord_service.dart';

class FeedbackDetailScreen extends StatefulWidget {
  final DiscordMessage message;
  final DiscordService service;
  final Color accentColor;
  final List<String> quickEmojis;

  const FeedbackDetailScreen({
    super.key,
    required this.message,
    required this.service,
    this.accentColor = const Color(0xFF5865F2),
    this.quickEmojis = const [
      '👍', '👎', '❤️', '🔥', '👀', '✅', '❌', '🐛', '💡', '⭐',
    ],
  });

  @override
  State<FeedbackDetailScreen> createState() => _FeedbackDetailScreenState();
}

class _FeedbackDetailScreenState extends State<FeedbackDetailScreen> {
  final TextEditingController _replyCtrl = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  late List<DiscordReaction> _reactions;
  List<XFile> _pendingFiles = [];
  bool _isSending = false;

  Color get _accent => widget.accentColor;
  static const _dark = Color(0xFF2C2F33);

  @override
  void initState() {
    super.initState();
    _reactions = List.from(widget.message.reactions);
  }

  @override
  void dispose() {
    _replyCtrl.dispose();
    super.dispose();
  }

  Future<void> _toggleReaction(String emoji) async {
    final isReacted = _reactions.any((r) => r.emoji.name == emoji && r.me);
    try {
      if (isReacted) {
        await widget.service.removeReaction(
          channelId: widget.message.channelId,
          messageId: widget.message.id,
          emoji: emoji,
        );
        setState(() {
          final i =
              _reactions.indexWhere((r) => r.emoji.name == emoji && r.me);
          if (i != -1) {
            if (_reactions[i].count <= 1) {
              _reactions.removeAt(i);
            } else {
              _reactions[i] = DiscordReaction(
                  count: _reactions[i].count - 1,
                  me: false,
                  emoji: _reactions[i].emoji);
            }
          }
        });
      } else {
        await widget.service.addReaction(
          channelId: widget.message.channelId,
          messageId: widget.message.id,
          emoji: emoji,
        );
        setState(() {
          final i = _reactions.indexWhere((r) => r.emoji.name == emoji);
          if (i != -1) {
            _reactions[i] = DiscordReaction(
                count: _reactions[i].count + 1,
                me: true,
                emoji: _reactions[i].emoji);
          } else {
            _reactions.add(DiscordReaction(
                count: 1, me: true, emoji: DiscordEmoji(name: emoji)));
          }
        });
      }
    } catch (e) {
      _snack('$e', isError: true);
    }
  }

  Future<void> _sendReply() async {
    final text = _replyCtrl.text.trim();
    if (text.isEmpty && _pendingFiles.isEmpty) return;
    setState(() => _isSending = true);
    try {
      await widget.service.sendMessage(
        channelId: widget.message.channelId,
        content: text,
        replyToMessageId: widget.message.id,
        attachments: _pendingFiles.isNotEmpty ? _pendingFiles : null,
      );
      _replyCtrl.clear();
      setState(() {
        _pendingFiles = [];
        _isSending = false;
      });
      _snack('Đã gửi phản hồi');
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
        Flexible(child: Text(msg)),
      ]),
      backgroundColor: isError ? Colors.red.shade600 : _accent,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(12),
    ));
  }

  String _fmtTime(DateTime t) => DateFormat('dd/MM/yyyy • HH:mm').format(t);

  String _relTime(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'Vừa xong';
    if (d.inHours < 1) return '${d.inMinutes} phút trước';
    if (d.inDays < 1) return '${d.inHours} giờ trước';
    if (d.inDays < 30) return '${d.inDays} ngày trước';
    return '${d.inDays ~/ 30} tháng trước';
  }

  @override
  Widget build(BuildContext context) {
    final msg = widget.message;
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      body: Column(
        children: [
          _buildHeader(msg),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (msg.content.isNotEmpty) _contentCard(msg.content),
                  if (msg.hasAttachments) ...[
                    const SizedBox(height: 16),
                    _attachmentsSection(msg.attachments),
                  ],
                  if (msg.hasEmbeds) ...[
                    const SizedBox(height: 16),
                    _embedsSection(msg.embeds),
                  ],
                  const SizedBox(height: 20),
                  _quickReactSection(),
                  if (_reactions.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _reactionsWrap(),
                  ],
                  const SizedBox(height: 20),
                  _infoSection(msg),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
          if (_pendingFiles.isNotEmpty) _filePreview(),
          _replyBar(),
        ],
      ),
    );
  }

  Widget _buildHeader(DiscordMessage msg) {
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
          padding: const EdgeInsets.fromLTRB(4, 4, 12, 20),
          child: Column(children: [
            Row(children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: Colors.white, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
              const Spacer(),
              _headerBtn(Icons.copy_rounded, () {
                Clipboard.setData(ClipboardData(text: msg.content));
                _snack('Đã sao chép');
              }),
            ]),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(children: [
                _avatar(msg.author, 48),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Flexible(
                          child: Text(msg.author.displayName,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700),
                              overflow: TextOverflow.ellipsis),
                        ),
                        if (msg.author.bot == true) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text('BOT',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ]),
                      const SizedBox(height: 4),
                      Text(_relTime(msg.timestamp),
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.65),
                              fontSize: 13)),
                    ],
                  ),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _headerBtn(IconData icon, VoidCallback onTap) {
    return Material(
      color: Colors.white.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    );
  }

  Widget _avatar(DiscordUser u, double size) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border:
            Border.all(color: Colors.white.withValues(alpha: 0.3), width: 2),
      ),
      child: ClipOval(
        child: CachedNetworkImage(
          imageUrl: u.avatarUrl,
          width: size,
          height: size,
          fit: BoxFit.cover,
          placeholder: (_, __) => Container(
              width: size,
              height: size,
              color: Colors.white.withValues(alpha: 0.1),
              child: const Icon(Icons.person, color: Colors.white)),
          errorWidget: (_, __, ___) => Container(
              width: size,
              height: size,
              color: Colors.white.withValues(alpha: 0.1),
              child: const Icon(Icons.person, color: Colors.white)),
        ),
      ),
    );
  }

  Widget _contentCard(String content) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: SelectableText(content,
          style: const TextStyle(fontSize: 15, color: _dark, height: 1.55)),
    );
  }

  Widget _attachmentsSection(List<DiscordAttachment> attachments) {
    final images = attachments.where((a) => a.isImage).toList();
    final files = attachments.where((a) => !a.isImage).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _label(Icons.image_rounded, 'Ảnh & File', count: attachments.length),
      const SizedBox(height: 10),
      ...images.map((img) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: CachedNetworkImage(
                imageUrl: img.url,
                fit: BoxFit.cover,
                width: double.infinity,
                placeholder: (_, __) => Container(
                    height: 200,
                    color: Colors.grey.shade100,
                    child: Center(
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: _accent))),
                errorWidget: (_, __, ___) => Container(
                    height: 100,
                    color: Colors.grey.shade100,
                    child: const Center(
                        child: Icon(Icons.broken_image_rounded, size: 40))),
              ),
            ),
          )),
      ...files.map((f) => Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: _accent.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8)),
                child: Icon(Icons.insert_drive_file_rounded,
                    color: _accent, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(f.filename,
                          style: const TextStyle(
                              fontWeight: FontWeight.w500, fontSize: 14),
                          overflow: TextOverflow.ellipsis),
                      Text(f.formattedSize,
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey.shade500)),
                    ]),
              ),
            ]),
          )),
    ]);
  }

  Widget _embedsSection(List<DiscordEmbed> embeds) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _label(Icons.link_rounded, 'Embeds', count: embeds.length),
      const SizedBox(height: 10),
      ...embeds.map((embed) => Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border(
                  left: BorderSide(
                      color: embed.color != null
                          ? Color(embed.color! | 0xFF000000)
                          : _accent,
                      width: 4)),
            ),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (embed.title != null)
                    Text(embed.title!,
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                            color: _accent)),
                  if (embed.description != null) ...[
                    if (embed.title != null) const SizedBox(height: 6),
                    Text(embed.description!,
                        style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF4F545C),
                            height: 1.4)),
                  ],
                ]),
          )),
    ]);
  }

  Widget _quickReactSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _label(Icons.add_reaction_outlined, 'Thả React'),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: widget.quickEmojis.map((e) {
            final reacted = _reactions.any((r) => r.emoji.name == e && r.me);
            return GestureDetector(
              onTap: () => _toggleReaction(e),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: reacted
                      ? _accent.withValues(alpha: 0.12)
                      : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: reacted ? _accent : Colors.grey.shade200,
                      width: reacted ? 2 : 1),
                ),
                child: Text(e, style: const TextStyle(fontSize: 22)),
              ),
            );
          }).toList(),
        ),
      ]),
    );
  }

  Widget _reactionsWrap() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _reactions.map((r) {
        return GestureDetector(
          onTap: () {
            if (r.emoji.name != null) _toggleReaction(r.emoji.name!);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color:
                  r.me ? _accent.withValues(alpha: 0.12) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: r.me ? _accent : Colors.grey.shade200,
                  width: r.me ? 2 : 1),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(r.emoji.name ?? '?', style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 5),
              Text('${r.count}',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: r.me ? _accent : Colors.grey.shade500)),
            ]),
          ),
        );
      }).toList(),
    );
  }

  Widget _infoSection(DiscordMessage msg) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _label(Icons.info_outline_rounded, 'Chi tiết'),
        const SizedBox(height: 12),
        _infoRow('ID', msg.id),
        _infoRow('Thời gian', _fmtTime(msg.timestamp)),
        if (msg.editedTimestamp != null)
          _infoRow('Chỉnh sửa', _fmtTime(msg.editedTimestamp!)),
        _infoRow('Ghim', msg.pinned ? 'Có' : 'Không'),
        _infoRow('Channel', msg.channelId),
      ]),
    );
  }

  Widget _label(IconData icon, String text, {int? count}) {
    return Row(children: [
      Icon(icon, size: 16, color: Colors.grey.shade500),
      const SizedBox(width: 6),
      Text(count != null ? '$text ($count)' : text,
          style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade500)),
    ]);
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          width: 80,
          child: Text(label,
              style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade400,
                  fontWeight: FontWeight.w500)),
        ),
        Expanded(
          child: SelectableText(value,
              style: const TextStyle(fontSize: 13, color: _dark)),
        ),
      ]),
    );
  }

  Widget _filePreview() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: Colors.grey.shade50,
      child: SizedBox(
        height: 68,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: _pendingFiles.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (_, i) => Stack(clipBehavior: Clip.none, children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
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
                  decoration: const BoxDecoration(
                      color: Colors.red, shape: BoxShape.circle),
                  child: const Icon(Icons.close, size: 14, color: Colors.white),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _replyBar() {
    return Container(
      padding: EdgeInsets.only(
          left: 8,
          right: 8,
          top: 8,
          bottom: MediaQuery.of(context).padding.bottom + 8),
      decoration: BoxDecoration(color: Colors.white, boxShadow: [
        BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, -2)),
      ]),
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        PopupMenuButton<String>(
          icon: Icon(Icons.add_circle_outline_rounded,
              size: 26, color: Colors.grey.shade400),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          offset: const Offset(0, -120),
          itemBuilder: (_) => [
            PopupMenuItem(
                value: 'gallery',
                child: Row(children: [
                  Icon(Icons.photo_library_rounded, color: _accent, size: 20),
                  const SizedBox(width: 10),
                  const Text('Thư viện ảnh'),
                ])),
            const PopupMenuItem(
                value: 'camera',
                child: Row(children: [
                  Icon(Icons.camera_alt_rounded,
                      color: Colors.orange, size: 20),
                  SizedBox(width: 10),
                  Text('Chụp ảnh'),
                ])),
          ],
          onSelected: (v) {
            if (v == 'gallery') _pickImages();
            if (v == 'camera') _takePhoto();
          },
        ),
        Expanded(
          child: Container(
            constraints: const BoxConstraints(maxHeight: 120),
            child: TextField(
              controller: _replyCtrl,
              maxLines: null,
              decoration: InputDecoration(
                hintText: 'Phản hồi...',
                hintStyle:
                    TextStyle(color: Colors.grey.shade400, fontSize: 15),
                filled: true,
                fillColor: Colors.grey.shade50,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide:
                        BorderSide(color: _accent.withValues(alpha: 0.5))),
              ),
              textInputAction: TextInputAction.newline,
            ),
          ),
        ),
        const SizedBox(width: 4),
        Material(
          color: _accent,
          borderRadius: BorderRadius.circular(22),
          child: InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: _isSending ? null : _sendReply,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: _isSending
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.send_rounded,
                      color: Colors.white, size: 24),
            ),
          ),
        ),
      ]),
    );
  }
}
