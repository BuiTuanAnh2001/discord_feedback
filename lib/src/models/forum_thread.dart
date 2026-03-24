import 'discord_message.dart';

class ThreadMetadata {
  final bool archived;
  final int autoArchiveDuration;
  final DateTime archiveTimestamp;
  final bool locked;
  final DateTime? createTimestamp;

  const ThreadMetadata({
    required this.archived,
    required this.autoArchiveDuration,
    required this.archiveTimestamp,
    required this.locked,
    this.createTimestamp,
  });

  factory ThreadMetadata.fromJson(Map<String, dynamic> json) {
    return ThreadMetadata(
      archived: json['archived'] as bool? ?? false,
      autoArchiveDuration: json['auto_archive_duration'] as int? ?? 4320,
      archiveTimestamp:
          DateTime.parse(json['archive_timestamp'] as String),
      locked: json['locked'] as bool? ?? false,
      createTimestamp: json['create_timestamp'] != null
          ? DateTime.tryParse(json['create_timestamp'] as String)
          : null,
    );
  }
}

class ForumThread {
  final String id;
  final String? guildId;
  final String parentId;
  final String name;
  final String? ownerId;
  final int messageCount;
  final int memberCount;
  final List<String> appliedTags;
  final ThreadMetadata? threadMetadata;
  final int? totalMessageSent;
  final DateTime createdAt;

  /// Starter message (first message in thread), loaded separately.
  final DiscordMessage? starterMessage;

  const ForumThread({
    required this.id,
    this.guildId,
    required this.parentId,
    required this.name,
    this.ownerId,
    this.messageCount = 0,
    this.memberCount = 0,
    this.appliedTags = const [],
    this.threadMetadata,
    this.totalMessageSent,
    required this.createdAt,
    this.starterMessage,
  });

  bool get isArchived => threadMetadata?.archived ?? false;
  bool get isLocked => threadMetadata?.locked ?? false;

  ForumThread copyWith({
    DiscordMessage? starterMessage,
    List<String>? appliedTags,
  }) {
    return ForumThread(
      id: id,
      guildId: guildId,
      parentId: parentId,
      name: name,
      ownerId: ownerId,
      messageCount: messageCount,
      memberCount: memberCount,
      appliedTags: appliedTags ?? this.appliedTags,
      threadMetadata: threadMetadata,
      totalMessageSent: totalMessageSent,
      createdAt: createdAt,
      starterMessage: starterMessage ?? this.starterMessage,
    );
  }

  factory ForumThread.fromJson(Map<String, dynamic> json) {
    final metadata = json['thread_metadata'] as Map<String, dynamic>?;
    final createTs = metadata?['create_timestamp'] as String?;

    return ForumThread(
      id: json['id'] as String,
      guildId: json['guild_id'] as String?,
      parentId: json['parent_id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      ownerId: json['owner_id'] as String?,
      messageCount: json['message_count'] as int? ?? 0,
      memberCount: json['member_count'] as int? ?? 0,
      appliedTags: (json['applied_tags'] as List?)
              ?.map((t) => t as String)
              .toList() ??
          [],
      threadMetadata:
          metadata != null ? ThreadMetadata.fromJson(metadata) : null,
      totalMessageSent: json['total_message_sent'] as int?,
      createdAt: createTs != null
          ? DateTime.parse(createTs)
          : DateTime.now(),
    );
  }
}
