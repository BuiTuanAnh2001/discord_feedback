import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models/models.dart';
import '../theme/discord_feedback_theme.dart';

/// A single forum post card, matching Discord mobile forum style.
class ForumPostCard extends StatelessWidget {
  final ForumThread thread;
  final List<ForumTag> availableTags;
  final DiscordFeedbackTheme theme;
  final VoidCallback onTap;

  const ForumPostCard({
    super.key,
    required this.thread,
    required this.availableTags,
    required this.theme,
    required this.onTap,
  });

  DiscordFeedbackTheme get t => theme;

  @override
  Widget build(BuildContext context) {
    final tags = _resolvedTags();
    final extraTagCount =
        thread.appliedTags.length > 3 ? thread.appliedTags.length - 3 : 0;
    final shownTags = tags.take(3).toList();
    final starter = thread.starterMessage;
    final thumbnail = _firstImageUrl(starter);
    final preview = _previewText(starter);
    final authorName = starter?.author.displayName ?? 'Feedback Bot';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: Material(
        color: t.cardBg,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (shownTags.isNotEmpty) _tagRow(shownTags, extraTagCount),
                _authorRow(authorName),
                _contentRow(thumbnail, preview),
                const SizedBox(height: 10),
                _bottomRow(starter),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _tagRow(List<ForumTag> shownTags, int extra) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          ...shownTags.map((tag) => Padding(
                padding: const EdgeInsets.only(right: 6),
                child: _tagBadge(tag),
              )),
          if (extra > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: t.bgTertiary,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text('+$extra',
                  style: TextStyle(
                      fontSize: 11,
                      color: t.textMuted,
                      fontWeight: FontWeight.w600)),
            ),
        ],
      ),
    );
  }

  Widget _tagBadge(ForumTag tag) {
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
                  fontSize: 11, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }

  Widget _authorRow(String authorName) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Text(authorName,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: t.textSecondary)),
          const SizedBox(width: 6),
          Text(_formatTimestamp(thread.createdAt),
              style: TextStyle(fontSize: 12, color: t.textMuted)),
        ],
      ),
    );
  }

  Widget _contentRow(String? thumbnail, String? preview) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${_typeEmoji(thread.name)} ${thread.name}',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: t.textPrimary,
                    height: 1.35),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (preview != null) ...[
                const SizedBox(height: 4),
                Text(preview,
                    style: TextStyle(
                        fontSize: 13, color: t.textMuted, height: 1.3),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
              ],
            ],
          ),
        ),
        if (thumbnail != null) ...[
          const SizedBox(width: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: CachedNetworkImage(
              imageUrl: thumbnail,
              width: 80,
              height: 80,
              fit: BoxFit.cover,
              placeholder: (_, __) =>
                  Container(width: 80, height: 80, color: t.bgTertiary),
              errorWidget: (_, __, ___) => Container(
                width: 80,
                height: 80,
                color: t.bgTertiary,
                child: Icon(Icons.broken_image_rounded,
                    color: t.textMuted, size: 20),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _bottomRow(DiscordMessage? starter) {
    final upvotes = _upvoteCount(starter);
    return Row(
      children: [
        Icon(Icons.chat_bubble_outlined, size: 14, color: t.textMuted),
        const SizedBox(width: 4),
        Text('${thread.messageCount}',
            style: TextStyle(fontSize: 12, color: t.textMuted)),
        const Spacer(),
        if (upvotes > 0) _upvoteBadge(upvotes),
      ],
    );
  }

  Widget _upvoteBadge(int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: t.successColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.arrow_upward_rounded,
              size: 13, color: Colors.white),
          const SizedBox(width: 2),
          Text('$count',
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.white)),
        ],
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  List<ForumTag> _resolvedTags() {
    final tags = <ForumTag>[];
    for (final tagId in thread.appliedTags) {
      try {
        tags.add(availableTags.firstWhere((t) => t.id == tagId));
      } catch (_) {}
    }
    return tags;
  }

  String _formatTimestamp(DateTime ts) {
    final diff = DateTime.now().difference(ts);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    if (diff.inDays < 30) return '>${diff.inDays ~/ 7}w ago';
    return '>${diff.inDays ~/ 30}mo ago';
  }

  String _typeEmoji(String name) {
    final match = RegExp(r'^\[(\w+)\]').firstMatch(name);
    if (match == null) return '';
    switch (match.group(1)!.toLowerCase()) {
      case 'bug':
        return '\u26A0\uFE0F';
      case 'suggestion':
        return '\uD83D\uDCA1';
      case 'feature':
        return '\u2728';
      default:
        return '\uD83D\uDCAC';
    }
  }

  String? _firstImageUrl(DiscordMessage? msg) {
    if (msg == null) return null;
    final images = msg.attachments.where((a) => a.isImage);
    return images.isNotEmpty ? images.first.url : null;
  }

  String? _previewText(DiscordMessage? msg) {
    if (msg == null) return null;
    final content = msg.content;
    if (content.isEmpty) return null;
    final lines = content.split('\n').where((l) => l.trim().isNotEmpty);
    if (lines.isEmpty) return null;
    final preview = lines.take(2).join(' ').trim();
    return preview.length > 120 ? '${preview.substring(0, 117)}...' : preview;
  }

  int _upvoteCount(DiscordMessage? msg) {
    if (msg == null) return 0;
    for (final r in msg.reactions) {
      if (r.emoji.name == '👍' || r.emoji.name == '⬆️' || r.emoji.name == '🔼') {
        return r.count;
      }
    }
    return 0;
  }
}
