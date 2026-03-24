import 'discord_user.dart';
import 'discord_attachment.dart';
import 'discord_embed.dart';
import 'discord_reaction.dart';

class DiscordMessage {
  final String id;
  final String channelId;
  final String content;
  final DateTime timestamp;
  final DateTime? editedTimestamp;
  final bool pinned;
  final bool tts;
  final bool mentionEveryone;
  final DiscordUser author;
  final List<DiscordAttachment> attachments;
  final List<DiscordEmbed> embeds;
  final List<DiscordReaction> reactions;

  const DiscordMessage({
    required this.id,
    required this.channelId,
    required this.content,
    required this.timestamp,
    this.editedTimestamp,
    required this.pinned,
    required this.tts,
    required this.mentionEveryone,
    required this.author,
    required this.attachments,
    required this.embeds,
    required this.reactions,
  });

  bool get hasImages => attachments.any((a) => a.isImage);
  bool get hasReactions => reactions.isNotEmpty;
  bool get hasAttachments => attachments.isNotEmpty;
  bool get hasEmbeds => embeds.isNotEmpty;

  DiscordMessage copyWith({List<DiscordReaction>? reactions}) {
    return DiscordMessage(
      id: id,
      channelId: channelId,
      content: content,
      timestamp: timestamp,
      editedTimestamp: editedTimestamp,
      pinned: pinned,
      tts: tts,
      mentionEveryone: mentionEveryone,
      author: author,
      attachments: attachments,
      embeds: embeds,
      reactions: reactions ?? this.reactions,
    );
  }

  factory DiscordMessage.fromJson(Map<String, dynamic> json) {
    return DiscordMessage(
      id: json['id'] as String,
      channelId: json['channel_id'] as String,
      content: json['content'] as String? ?? '',
      timestamp: DateTime.parse(json['timestamp'] as String),
      editedTimestamp: json['edited_timestamp'] != null
          ? DateTime.parse(json['edited_timestamp'] as String)
          : null,
      pinned: json['pinned'] as bool? ?? false,
      tts: json['tts'] as bool? ?? false,
      mentionEveryone: json['mention_everyone'] as bool? ?? false,
      author: DiscordUser.fromJson(json['author'] as Map<String, dynamic>),
      attachments: (json['attachments'] as List?)
              ?.map((a) =>
                  DiscordAttachment.fromJson(a as Map<String, dynamic>))
              .toList() ??
          [],
      embeds: (json['embeds'] as List?)
              ?.map((e) => DiscordEmbed.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      reactions: (json['reactions'] as List?)
              ?.map(
                  (r) => DiscordReaction.fromJson(r as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}
