class DiscordUser {
  final String id;
  final String username;
  final String discriminator;
  final String? avatar;
  final bool? bot;
  final String? globalName;

  const DiscordUser({
    required this.id,
    required this.username,
    required this.discriminator,
    this.avatar,
    this.bot,
    this.globalName,
  });

  String get displayName => globalName ?? username;

  String get avatarUrl {
    if (avatar != null && avatar!.isNotEmpty) {
      return 'https://cdn.discordapp.com/avatars/$id/$avatar.png?size=128';
    }
    final d = int.tryParse(discriminator) ?? 0;
    return 'https://cdn.discordapp.com/embed/avatars/${d % 5}.png';
  }

  factory DiscordUser.fromJson(Map<String, dynamic> json) {
    return DiscordUser(
      id: json['id'] as String,
      username: json['username'] as String,
      discriminator: json['discriminator'] as String? ?? '0',
      avatar: json['avatar'] as String?,
      bot: json['bot'] as bool?,
      globalName: json['global_name'] as String?,
    );
  }
}
