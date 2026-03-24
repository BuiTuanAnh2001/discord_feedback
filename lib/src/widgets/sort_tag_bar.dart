import 'package:flutter/material.dart';

import '../models/models.dart';
import '../theme/discord_feedback_theme.dart';

enum SortBy { creationTime, lastMessageTime }

enum SortOrder { newest, oldest }

/// Discord-style Sort & View + Tags filter bar.
class SortTagBar extends StatelessWidget {
  final DiscordFeedbackTheme theme;
  final SortBy sortBy;
  final SortOrder sortOrder;
  final Set<String> selectedTagIds;
  final List<ForumTag> availableTags;
  final ValueChanged<SortBy> onSortByChanged;
  final ValueChanged<SortOrder> onSortOrderChanged;
  final ValueChanged<Set<String>> onTagsChanged;

  const SortTagBar({
    super.key,
    required this.theme,
    required this.sortBy,
    required this.sortOrder,
    required this.selectedTagIds,
    required this.availableTags,
    required this.onSortByChanged,
    required this.onSortOrderChanged,
    required this.onTagsChanged,
  });

  DiscordFeedbackTheme get t => theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: t.bgSecondary,
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
      child: Row(
        children: [
          _sortButton(context),
          const Spacer(),
          _tagsButton(context),
        ],
      ),
    );
  }

  Widget _sortButton(BuildContext context) {
    return GestureDetector(
      onTap: () => _showSortSheet(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: t.bgTertiary,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.swap_vert_rounded, size: 16, color: t.textSecondary),
            const SizedBox(width: 6),
            Text('Sort & View',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: t.textSecondary)),
            const SizedBox(width: 4),
            Icon(Icons.keyboard_arrow_down_rounded,
                size: 16, color: t.textMuted),
          ],
        ),
      ),
    );
  }

  Widget _tagsButton(BuildContext context) {
    final hasFilter = selectedTagIds.isNotEmpty;
    return GestureDetector(
      onTap: () => _showTagsSheet(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: hasFilter ? t.accent.withValues(alpha: 0.2) : t.bgTertiary,
          borderRadius: BorderRadius.circular(6),
          border: hasFilter
              ? Border.all(color: t.accent.withValues(alpha: 0.5), width: 1)
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              hasFilter ? 'Tags (${selectedTagIds.length})' : 'Tags',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: hasFilter ? t.accent : t.textSecondary),
            ),
            const SizedBox(width: 4),
            Icon(Icons.keyboard_arrow_down_rounded,
                size: 16, color: hasFilter ? t.accent : t.textMuted),
          ],
        ),
      ),
    );
  }

  void _showSortSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: t.bgSecondary,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(0, 8, 0, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _handle(),
              const SizedBox(height: 16),
              _sectionLabel('SORT BY'),
              const SizedBox(height: 8),
              _sortTile(ctx, 'Creation time', Icons.schedule_rounded,
                  sortBy == SortBy.creationTime, () {
                onSortByChanged(SortBy.creationTime);
                Navigator.pop(ctx);
              }),
              _sortTile(ctx, 'Last message time', Icons.chat_rounded,
                  sortBy == SortBy.lastMessageTime, () {
                onSortByChanged(SortBy.lastMessageTime);
                Navigator.pop(ctx);
              }),
              Divider(
                  color: t.dividerColor,
                  height: 24,
                  indent: 16,
                  endIndent: 16),
              _sectionLabel('ORDER'),
              const SizedBox(height: 8),
              _sortTile(ctx, 'Newest first', Icons.arrow_downward_rounded,
                  sortOrder == SortOrder.newest, () {
                onSortOrderChanged(SortOrder.newest);
                Navigator.pop(ctx);
              }),
              _sortTile(ctx, 'Oldest first', Icons.arrow_upward_rounded,
                  sortOrder == SortOrder.oldest, () {
                onSortOrderChanged(SortOrder.oldest);
                Navigator.pop(ctx);
              }),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  void _showTagsSheet(BuildContext context) {
    var tags = Set<String>.from(selectedTagIds);
    showModalBottomSheet(
      context: context,
      backgroundColor: t.bgSecondary,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(0, 8, 0, 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _handle(),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      _sectionLabel('FILTER BY TAGS'),
                      const Spacer(),
                      if (tags.isNotEmpty)
                        GestureDetector(
                          onTap: () {
                            setSheet(() => tags = {});
                            onTagsChanged({});
                          },
                          child: Text('Clear',
                              style: TextStyle(
                                  fontSize: 13,
                                  color: t.accent,
                                  fontWeight: FontWeight.w600)),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                ...availableTags.map((tag) {
                  final selected = tags.contains(tag.id);
                  final color = t.tagColor(tag.name);
                  return ListTile(
                    dense: true,
                    leading: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Center(
                        child: tag.emojiName != null
                            ? Text(tag.emojiName!,
                                style: const TextStyle(fontSize: 13))
                            : Icon(Icons.label_rounded,
                                size: 14, color: color),
                      ),
                    ),
                    title: Text(tag.name,
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight:
                                selected ? FontWeight.w600 : FontWeight.w400,
                            color: selected ? color : t.textPrimary)),
                    trailing: Checkbox(
                      value: selected,
                      onChanged: (_) {
                        setSheet(() {
                          selected ? tags.remove(tag.id) : tags.add(tag.id);
                        });
                        onTagsChanged(Set.from(tags));
                      },
                      activeColor: t.accent,
                      side: BorderSide(color: t.textMuted),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4)),
                    ),
                    onTap: () {
                      setSheet(() {
                        selected ? tags.remove(tag.id) : tags.add(tag.id);
                      });
                      onTagsChanged(Set.from(tags));
                    },
                  );
                }),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _handle() {
    return Center(
      child: Container(
        width: 36,
        height: 4,
        decoration: BoxDecoration(
          color: t.textMuted.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _sectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Text(label,
          style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: t.textMuted,
              letterSpacing: 0.5)),
    );
  }

  Widget _sortTile(BuildContext ctx, String label, IconData icon,
      bool selected, VoidCallback onTap) {
    return ListTile(
      dense: true,
      leading:
          Icon(icon, size: 20, color: selected ? t.accent : t.textMuted),
      title: Text(label,
          style: TextStyle(
              fontSize: 14,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              color: selected ? t.accent : t.textPrimary)),
      trailing: selected
          ? Icon(Icons.check_rounded, size: 20, color: t.accent)
          : null,
      onTap: onTap,
    );
  }
}
