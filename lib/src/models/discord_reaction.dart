import 'discord_emoji.dart';

class DiscordReaction {
  final int count;
  final bool me;
  final DiscordEmoji emoji;

  const DiscordReaction({
    required this.count,
    required this.me,
    required this.emoji,
  });

  factory DiscordReaction.fromJson(Map<String, dynamic> json) {
    return DiscordReaction(
      count: json['count'] as int,
      me: json['me'] as bool? ?? false,
      emoji: DiscordEmoji.fromJson(json['emoji'] as Map<String, dynamic>),
    );
  }
}
