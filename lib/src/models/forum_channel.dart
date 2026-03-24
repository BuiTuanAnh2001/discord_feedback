import 'forum_tag.dart';

class ForumChannel {
  final String id;
  final String guildId;
  final String name;
  final int type;
  final List<ForumTag> availableTags;
  final int? defaultSortOrder;

  const ForumChannel({
    required this.id,
    required this.guildId,
    required this.name,
    required this.type,
    required this.availableTags,
    this.defaultSortOrder,
  });

  bool get isForum => type == 15;

  factory ForumChannel.fromJson(Map<String, dynamic> json) {
    return ForumChannel(
      id: json['id'] as String,
      guildId: json['guild_id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      type: json['type'] as int? ?? 0,
      availableTags: (json['available_tags'] as List?)
              ?.map((t) => ForumTag.fromJson(t as Map<String, dynamic>))
              .toList() ??
          [],
      defaultSortOrder: json['default_sort_order'] as int?,
    );
  }
}
