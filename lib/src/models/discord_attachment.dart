class DiscordAttachment {
  final String id;
  final String filename;
  final int size;
  final String url;
  final String proxyUrl;
  final String? contentType;
  final int? width;
  final int? height;

  const DiscordAttachment({
    required this.id,
    required this.filename,
    required this.size,
    required this.url,
    required this.proxyUrl,
    this.contentType,
    this.width,
    this.height,
  });

  bool get isImage => (contentType ?? '').startsWith('image/');

  String get formattedSize {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  factory DiscordAttachment.fromJson(Map<String, dynamic> json) {
    return DiscordAttachment(
      id: json['id'] as String,
      filename: json['filename'] as String,
      size: json['size'] as int,
      url: json['url'] as String,
      proxyUrl: json['proxy_url'] as String,
      contentType: json['content_type'] as String?,
      width: json['width'] as int?,
      height: json['height'] as int?,
    );
  }
}
