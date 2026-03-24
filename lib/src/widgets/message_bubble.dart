import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/models.dart';
import '../theme/discord_feedback_theme.dart';

/// A single Discord-style message bubble with avatar, author, content, and attachments.
class MessageBubble extends StatelessWidget {
  final DiscordMessage message;
  final DiscordFeedbackTheme theme;
  final bool isFirst;

  const MessageBubble({
    super.key,
    required this.message,
    required this.theme,
    this.isFirst = false,
  });

  DiscordFeedbackTheme get t => theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _avatar(message.author, 36),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _header(),
                const SizedBox(height: 4),
                if (message.content.isNotEmpty)
                  SelectableText(message.content,
                      style: TextStyle(
                          fontSize: 14,
                          color: t.textSecondary,
                          height: 1.45)),
                if (message.hasImages) _imageAttachments(),
                if (message.hasAttachments && !message.hasImages)
                  _fileAttachments(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _header() {
    return Row(
      children: [
        Text(message.author.displayName,
            style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: t.textPrimary)),
        if (message.author.bot == true) ...[
          const SizedBox(width: 5),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
                color: t.accent, borderRadius: BorderRadius.circular(3)),
            child: const Text('APP',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w700)),
          ),
        ],
        const SizedBox(width: 6),
        Text(_relTime(message.timestamp),
            style: TextStyle(fontSize: 11, color: t.textMuted)),
      ],
    );
  }

  Widget _imageAttachments() {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        children: message.attachments
            .where((a) => a.isImage)
            .map((img) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 300),
                      child: CachedNetworkImage(
                        imageUrl: img.url,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        placeholder: (_, __) =>
                            Container(height: 160, color: t.bgTertiary),
                        errorWidget: (_, __, ___) => Container(
                          height: 80,
                          color: t.bgTertiary,
                          child: Center(
                              child: Icon(Icons.broken_image_rounded,
                                  color: t.textMuted, size: 32)),
                        ),
                      ),
                    ),
                  ),
                ))
            .toList(),
      ),
    );
  }

  Widget _fileAttachments() {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Column(
        children: message.attachments
            .where((a) => !a.isImage)
            .map((f) => Container(
                  margin: const EdgeInsets.only(bottom: 4),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: t.bgTertiary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(children: [
                    Icon(Icons.insert_drive_file_rounded,
                        color: t.accent, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(f.filename,
                              style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  fontSize: 13,
                                  color: t.textPrimary),
                              overflow: TextOverflow.ellipsis),
                          Text(f.formattedSize,
                              style: TextStyle(
                                  fontSize: 11, color: t.textMuted)),
                        ],
                      ),
                    ),
                  ]),
                ))
            .toList(),
      ),
    );
  }

  Widget _avatar(DiscordUser u, double size) {
    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: u.avatarUrl,
        width: size,
        height: size,
        fit: BoxFit.cover,
        placeholder: (_, __) => Container(
            width: size,
            height: size,
            color: t.bgTertiary,
            child: Icon(Icons.person_rounded,
                size: size * 0.5, color: t.textMuted)),
        errorWidget: (_, __, ___) => Container(
            width: size,
            height: size,
            color: t.bgTertiary,
            child: Icon(Icons.person_rounded,
                size: size * 0.5, color: t.textMuted)),
      ),
    );
  }

  String _relTime(DateTime time) {
    final d = DateTime.now().difference(time);
    if (d.inMinutes < 1) return 'Just now';
    if (d.inHours < 1) return '${d.inMinutes}m ago';
    if (d.inDays < 1) return '${d.inHours}h ago';
    if (d.inDays < 30) return '${d.inDays}d ago';
    return DateFormat('MMM d, yyyy').format(time);
  }
}
