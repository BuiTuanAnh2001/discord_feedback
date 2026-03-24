class ForumTag {
  final String id;
  final String name;
  final bool moderated;
  final String? emojiId;
  final String? emojiName;

  const ForumTag({
    required this.id,
    required this.name,
    this.moderated = false,
    this.emojiId,
    this.emojiName,
  });

  factory ForumTag.fromJson(Map<String, dynamic> json) {
    return ForumTag(
      id: json['id'] as String,
      name: json['name'] as String,
      moderated: json['moderated'] as bool? ?? false,
      emojiId: json['emoji_id'] as String?,
      emojiName: json['emoji_name'] as String?,
    );
  }
}
