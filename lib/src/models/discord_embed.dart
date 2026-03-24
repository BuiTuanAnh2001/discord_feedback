class DiscordEmbed {
  final String? type;
  final String? title;
  final String? description;
  final String? url;
  final int? color;
  final DateTime? timestamp;

  const DiscordEmbed({
    this.type,
    this.title,
    this.description,
    this.url,
    this.color,
    this.timestamp,
  });

  factory DiscordEmbed.fromJson(Map<String, dynamic> json) {
    return DiscordEmbed(
      type: json['type'] as String?,
      title: json['title'] as String?,
      description: json['description'] as String?,
      url: json['url'] as String?,
      color: json['color'] as int?,
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'] as String)
          : null,
    );
  }
}
