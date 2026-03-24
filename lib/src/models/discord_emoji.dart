class DiscordEmoji {
  final String? id;
  final String? name;
  final bool? animated;

  const DiscordEmoji({this.id, this.name, this.animated});

  factory DiscordEmoji.fromJson(Map<String, dynamic> json) {
    return DiscordEmoji(
      id: json['id']?.toString(),
      name: json['name'] as String?,
      animated: json['animated'] as bool?,
    );
  }
}
