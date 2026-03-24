import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../models/models.dart';
import '../services/discord_service.dart';
import '../theme/discord_feedback_theme.dart';

class CreateFeedbackSheet extends StatefulWidget {
  final DiscordService service;
  final String channelId;
  final List<ForumTag> availableTags;
  final DiscordFeedbackTheme theme;
  final String? appName;
  final String? appVersion;
  final String? deviceInfo;

  const CreateFeedbackSheet({
    super.key,
    required this.service,
    required this.channelId,
    required this.availableTags,
    this.theme = DiscordFeedbackTheme.dark,
    this.appName,
    this.appVersion,
    this.deviceInfo,
  });

  @override
  State<CreateFeedbackSheet> createState() => _CreateFeedbackSheetState();
}

class _CreateFeedbackSheetState extends State<CreateFeedbackSheet> {
  final _messageCtrl = TextEditingController();
  final _picker = ImagePicker();

  final Set<String> _selectedTagIds = {};
  final List<XFile> _screenshots = [];
  bool _isSending = false;

  DiscordFeedbackTheme get t => widget.theme;

  @override
  void dispose() {
    _messageCtrl.dispose();
    super.dispose();
  }

  String _buildDeviceInfo() {
    if (widget.deviceInfo != null) return widget.deviceInfo!;
    try {
      return '[${Platform.operatingSystem}] ${Platform.operatingSystemVersion}';
    } catch (_) {
      return 'Unknown';
    }
  }

  String _titlePrefix() {
    for (final tagId in _selectedTagIds) {
      final tag = widget.availableTags
          .where((t) => t.id == tagId)
          .firstOrNull;
      if (tag != null) return '[${tag.name}]';
    }
    return '[Feedback]';
  }

  String _buildMessageContent(String userMessage) {
    final now =
        DateFormat('EEEE, MMMM d, yyyy - HH:mm').format(DateTime.now());
    final deviceInfo = _buildDeviceInfo();

    final buf = StringBuffer();
    if (widget.appName != null) {
      buf.writeln('New User Feedback for ${widget.appName!}');
      buf.writeln();
    }
    buf.writeln('💬 **Message:**');
    buf.writeln(userMessage);
    buf.writeln();
    buf.writeln('ℹ️ **Information:**');
    if (widget.appVersion != null) {
      buf.writeln('• Version: ${widget.appVersion}');
    }
    buf.writeln('• Info device: $deviceInfo');
    buf.writeln('• Submitted At: $now');
    if (_screenshots.isNotEmpty) {
      final totalSize = _screenshots.length;
      buf.writeln(
          '• Screenshot: Attached below ($totalSize file${totalSize > 1 ? 's' : ''})');
    }

    if (widget.appName != null) {
      buf.writeln();
      buf.writeln('---');
      buf.writeln(
          '_Automatically sent from "${widget.appName}" mobile app_');
    }

    return buf.toString();
  }

  Future<void> _submit() async {
    final message = _messageCtrl.text.trim();
    if (message.isEmpty) {
      _snack('Vui lòng nhập nội dung feedback', isError: true);
      return;
    }
    if (_selectedTagIds.isEmpty && widget.availableTags.isNotEmpty) {
      _snack('Vui lòng chọn ít nhất 1 tag', isError: true);
      return;
    }

    setState(() => _isSending = true);
    try {
      final title = '${_titlePrefix()} $message';
      final truncatedTitle =
          title.length > 100 ? '${title.substring(0, 97)}...' : title;
      final content = _buildMessageContent(message);

      await widget.service.createForumPost(
        channelId: widget.channelId,
        title: truncatedTitle,
        content: content,
        appliedTags:
            _selectedTagIds.isNotEmpty ? _selectedTagIds.toList() : null,
        attachments: _screenshots.isNotEmpty ? _screenshots : null,
      );

      if (!mounted) return;
      _snack('Đã gửi feedback thành công!');
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSending = false);
      _snack('$e', isError: true);
    }
  }

  Future<void> _pickImages() async {
    try {
      final images = await _picker.pickMultiImage(
          imageQuality: 85, maxWidth: 1920, maxHeight: 1920);
      if (images.isNotEmpty) setState(() => _screenshots.addAll(images));
    } catch (e) {
      _snack('Không thể chọn ảnh: $e', isError: true);
    }
  }

  Future<void> _takePhoto() async {
    try {
      final photo = await _picker.pickImage(
          source: ImageSource.camera,
          imageQuality: 85,
          maxWidth: 1920,
          maxHeight: 1920);
      if (photo != null) setState(() => _screenshots.add(photo));
    } catch (e) {
      _snack('Không thể chụp ảnh: $e', isError: true);
    }
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

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: BoxDecoration(
        color: t.bgSecondary,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: t.textMuted.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Icon(Icons.edit_note_rounded, color: t.accent, size: 24),
                  const SizedBox(width: 8),
                  Text(
                    'New Post',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: t.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDynamicTagSelector(),
                    const SizedBox(height: 20),
                    _buildMessageInput(),
                    const SizedBox(height: 16),
                    _buildScreenshotSection(),
                    const SizedBox(height: 24),
                    _buildSubmitButton(),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Dynamic Tag Selector ───────────────────────────────────────────────────

  Widget _buildDynamicTagSelector() {
    if (widget.availableTags.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'TAGS',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: t.textMuted,
                  letterSpacing: 0.5),
            ),
            const SizedBox(width: 6),
            Text(
              '(select at least 1)',
              style: TextStyle(fontSize: 11, color: t.textMuted),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: widget.availableTags.map((tag) {
            final selected = _selectedTagIds.contains(tag.id);
            final color = t.tagColor(tag.name);
            return GestureDetector(
              onTap: () {
                setState(() {
                  if (selected) {
                    _selectedTagIds.remove(tag.id);
                  } else {
                    _selectedTagIds.add(tag.id);
                  }
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color:
                      selected ? color.withValues(alpha: 0.2) : t.bgTertiary,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: selected
                        ? color.withValues(alpha: 0.6)
                        : Colors.transparent,
                    width: 1.5,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (tag.emojiName != null) ...[
                      Text(tag.emojiName!,
                          style: const TextStyle(fontSize: 14)),
                      const SizedBox(width: 6),
                    ] else ...[
                      Icon(Icons.label_rounded, size: 16, color: color),
                      const SizedBox(width: 6),
                    ],
                    Text(
                      tag.name,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: selected ? color : t.textSecondary,
                      ),
                    ),
                    if (selected) ...[
                      const SizedBox(width: 6),
                      Icon(Icons.check_rounded, size: 14, color: color),
                    ],
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildMessageInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'MESSAGE',
          style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: t.textMuted,
              letterSpacing: 0.5),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _messageCtrl,
          maxLines: 5,
          minLines: 3,
          style: TextStyle(color: t.textPrimary, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Describe your feedback...',
            hintStyle: TextStyle(color: t.textMuted, fontSize: 14),
            filled: true,
            fillColor: t.inputBg,
            contentPadding: const EdgeInsets.all(14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                  color: t.accent.withValues(alpha: 0.6), width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildScreenshotSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'SCREENSHOT (OPTIONAL)',
          style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: t.textMuted,
              letterSpacing: 0.5),
        ),
        const SizedBox(height: 10),
        if (_screenshots.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: SizedBox(
              height: 80,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _screenshots.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) => Stack(
                  clipBehavior: Clip.none,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(File(_screenshots[i].path),
                          width: 80, height: 80, fit: BoxFit.cover),
                    ),
                    Positioned(
                      top: -6,
                      right: -6,
                      child: GestureDetector(
                        onTap: () =>
                            setState(() => _screenshots.removeAt(i)),
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                              color: t.dangerColor,
                              shape: BoxShape.circle),
                          child: const Icon(Icons.close,
                              size: 14, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        Row(
          children: [
            _actionBtn(
              Icons.photo_library_rounded,
              'Gallery',
              t.accent,
              _pickImages,
            ),
            const SizedBox(width: 10),
            _actionBtn(
              Icons.camera_alt_rounded,
              'Camera',
              t.warningColor,
              _takePhoto,
            ),
          ],
        ),
      ],
    );
  }

  Widget _actionBtn(
      IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: t.bgTertiary,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: color)),
          ],
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 46,
      child: FilledButton(
        onPressed: _isSending ? null : _submit,
        style: FilledButton.styleFrom(
          backgroundColor: t.accent,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          disabledBackgroundColor: t.accent.withValues(alpha: 0.4),
        ),
        child: _isSending
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                    strokeWidth: 2.5, color: Colors.white),
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.send_rounded, size: 18),
                  SizedBox(width: 8),
                  Text('Post',
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600)),
                ],
              ),
      ),
    );
  }
}
