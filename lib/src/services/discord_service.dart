import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import '../models/models.dart';

class DiscordService {
  final String botToken;
  late final Dio _dio;

  static const String _baseUrl = 'https://discord.com/api/v10';

  DiscordService({required this.botToken}) {
    _dio = Dio(BaseOptions(
      baseUrl: _baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {
        'Authorization': 'Bot $botToken',
        'Content-Type': 'application/json',
      },
    ));
  }

  Future<List<DiscordMessage>> getMessages({
    required String channelId,
    int limit = 50,
    String? before,
    String? after,
  }) async {
    try {
      final response = await _dio.get(
        '/channels/$channelId/messages',
        queryParameters: <String, dynamic>{
          'limit': limit,
          if (before != null) 'before': before,
          if (after != null) 'after': after,
        },
      );

      if (response.data is List) {
        return (response.data as List)
            .map((json) =>
                DiscordMessage.fromJson(json as Map<String, dynamic>))
            .toList();
      }
      return [];
    } on DioException catch (e) {
      throw DiscordServiceException(
        'Failed to fetch messages: ${e.response?.data}',
        statusCode: e.response?.statusCode,
      );
    }
  }

  Future<void> addReaction({
    required String channelId,
    required String messageId,
    required String emoji,
  }) async {
    try {
      await _dio.put(
        '/channels/$channelId/messages/$messageId/reactions/${Uri.encodeComponent(emoji)}/@me',
      );
    } on DioException catch (e) {
      throw DiscordServiceException(
        'Failed to add reaction: ${e.response?.data}',
        statusCode: e.response?.statusCode,
      );
    }
  }

  Future<void> removeReaction({
    required String channelId,
    required String messageId,
    required String emoji,
  }) async {
    try {
      await _dio.delete(
        '/channels/$channelId/messages/$messageId/reactions/${Uri.encodeComponent(emoji)}/@me',
      );
    } on DioException catch (e) {
      throw DiscordServiceException(
        'Failed to remove reaction: ${e.response?.data}',
        statusCode: e.response?.statusCode,
      );
    }
  }

  Future<DiscordMessage> sendMessage({
    required String channelId,
    required String content,
    String? replyToMessageId,
    List<XFile>? attachments,
  }) async {
    try {
      if (attachments != null && attachments.isNotEmpty) {
        return _sendWithFiles(
          channelId: channelId,
          content: content,
          replyToMessageId: replyToMessageId,
          files: attachments,
        );
      }

      final response = await _dio.post(
        '/channels/$channelId/messages',
        data: <String, dynamic>{
          'content': content,
          if (replyToMessageId != null)
            'message_reference': {'message_id': replyToMessageId},
        },
      );
      return DiscordMessage.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw DiscordServiceException(
        'Failed to send message: ${e.response?.data}',
        statusCode: e.response?.statusCode,
      );
    }
  }

  Future<DiscordMessage> _sendWithFiles({
    required String channelId,
    required String content,
    String? replyToMessageId,
    required List<XFile> files,
  }) async {
    final payload = <String, dynamic>{
      'content': content,
      if (replyToMessageId != null)
        'message_reference': {'message_id': replyToMessageId},
    };

    final formData = FormData();
    formData.fields.add(MapEntry('payload_json', jsonEncode(payload)));

    for (int i = 0; i < files.length; i++) {
      final bytes = await files[i].readAsBytes();
      formData.files.add(MapEntry(
        'files[$i]',
        MultipartFile.fromBytes(bytes, filename: files[i].name),
      ));
    }

    final response = await _dio.post(
      '/channels/$channelId/messages',
      data: formData,
      options: Options(
        contentType: 'multipart/form-data',
        sendTimeout: const Duration(seconds: 30),
      ),
    );
    return DiscordMessage.fromJson(response.data as Map<String, dynamic>);
  }

  Future<DiscordUser> getCurrentBot() async {
    try {
      final response = await _dio.get('/users/@me');
      return DiscordUser.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw DiscordServiceException(
        'Failed to get bot info: ${e.response?.data}',
        statusCode: e.response?.statusCode,
      );
    }
  }
}
