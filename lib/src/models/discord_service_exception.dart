class DiscordServiceException implements Exception {
  final String message;
  final int? statusCode;

  const DiscordServiceException(this.message, {this.statusCode});

  @override
  String toString() => message;
}
