import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_discord_client/flutter_discord_client.dart';
import 'package:image_picker/image_picker.dart';
import '../models/models.dart';

class DiscordService {
  final String botToken;
  late final FlutterDiscordClient _client;
  late final DefaultApi _api;

  Dio get dio => _client.dio;

  /// Exposes the generated [DefaultApi] for advanced usage beyond
  /// the convenience methods provided by this class.
  DefaultApi get api => _api;

  ForumChannel? _cachedChannel;

  DiscordService({required this.botToken}) {
    _client = FlutterDiscordClient(
      dio: Dio(BaseOptions(
        baseUrl: FlutterDiscordClient.basePath,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        headers: {
          'Authorization': 'Bot $botToken',
          'Content-Type': 'application/json',
        },
      )),
    );
    _api = _client.getDefaultApi();
  }

  // ── Forum Channel ──────────────────────────────────────────────────────────

  Future<ForumChannel> getChannel(String channelId) async {
    if (_cachedChannel?.id == channelId) return _cachedChannel!;
    try {
      final response = await dio.get('/channels/$channelId');
      _cachedChannel =
          ForumChannel.fromJson(response.data as Map<String, dynamic>);
      return _cachedChannel!;
    } on DioException catch (e) {
      throw DiscordServiceException(
        'Failed to fetch channel: ${e.response?.data}',
        statusCode: e.response?.statusCode,
      );
    }
  }

  void invalidateChannelCache() => _cachedChannel = null;

  // ── Forum Threads ─────────────────────────────────────────────────────────

  Future<List<ForumThread>> getActiveThreads({
    required String channelId,
  }) async {
    try {
      final channel = await getChannel(channelId);
      final response =
          await dio.get('/guilds/${channel.guildId}/threads/active');
      final data = response.data as Map<String, dynamic>;
      final threads = (data['threads'] as List?) ?? [];
      return threads
          .map((t) => ForumThread.fromJson(t as Map<String, dynamic>))
          .where((t) => t.parentId == channelId)
          .toList();
    } on DioException catch (e) {
      throw DiscordServiceException(
        'Failed to fetch active threads: ${e.response?.data}',
        statusCode: e.response?.statusCode,
      );
    }
  }

  Future<List<ForumThread>> getArchivedThreads({
    required String channelId,
    int limit = 25,
    String? before,
  }) async {
    try {
      final response = await dio.get(
        '/channels/$channelId/threads/archived/public',
        queryParameters: <String, dynamic>{
          'limit': limit,
          if (before != null) 'before': before,
        },
      );
      final data = response.data as Map<String, dynamic>;
      final threads = (data['threads'] as List?) ?? [];
      return threads
          .map((t) => ForumThread.fromJson(t as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw DiscordServiceException(
        'Failed to fetch archived threads: ${e.response?.data}',
        statusCode: e.response?.statusCode,
      );
    }
  }

  /// Returns all forum posts (active + archived), sorted newest first.
  Future<List<ForumThread>> getForumPosts({
    required String channelId,
  }) async {
    final results = await Future.wait([
      getActiveThreads(channelId: channelId),
      getArchivedThreads(channelId: channelId),
    ]);
    final all = [...results[0], ...results[1]];
    all.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return all;
  }

  // ── Thread Messages ────────────────────────────────────────────────────────

  Future<List<DiscordMessage>> getThreadMessages({
    required String threadId,
    int limit = 50,
    String? before,
    String? after,
  }) async {
    try {
      final response = await dio.get(
        '/channels/$threadId/messages',
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
        'Failed to fetch thread messages: ${e.response?.data}',
        statusCode: e.response?.statusCode,
      );
    }
  }

  /// Fetches the first (starter) message of a thread.
  Future<DiscordMessage?> getStarterMessage(String threadId) async {
    try {
      final msgs = await getThreadMessages(
        threadId: threadId,
        limit: 1,
        after: '0',
      );
      return msgs.isNotEmpty ? msgs.first : null;
    } catch (_) {
      return null;
    }
  }

  // ── Create Forum Post ──────────────────────────────────────────────────────

  Future<ForumThread> createForumPost({
    required String channelId,
    required String title,
    required String content,
    List<String>? appliedTags,
    List<XFile>? attachments,
  }) async {
    try {
      if (attachments != null && attachments.isNotEmpty) {
        return _createForumPostWithFiles(
          channelId: channelId,
          title: title,
          content: content,
          appliedTags: appliedTags,
          files: attachments,
        );
      }

      final response = await dio.post(
        '/channels/$channelId/threads',
        data: <String, dynamic>{
          'name': title,
          'message': {'content': content},
          if (appliedTags != null && appliedTags.isNotEmpty)
            'applied_tags': appliedTags,
        },
      );
      return ForumThread.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw DiscordServiceException(
        'Failed to create forum post: ${e.response?.data}',
        statusCode: e.response?.statusCode,
      );
    }
  }

  Future<ForumThread> _createForumPostWithFiles({
    required String channelId,
    required String title,
    required String content,
    List<String>? appliedTags,
    required List<XFile> files,
  }) async {
    final attachmentRefs = <Map<String, dynamic>>[];
    for (int i = 0; i < files.length; i++) {
      attachmentRefs.add({'id': i, 'filename': files[i].name});
    }

    final payload = <String, dynamic>{
      'name': title,
      'message': {
        'content': content,
        'attachments': attachmentRefs,
      },
      if (appliedTags != null && appliedTags.isNotEmpty)
        'applied_tags': appliedTags,
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

    final response = await dio.post(
      '/channels/$channelId/threads',
      data: formData,
      options: Options(
        contentType: 'multipart/form-data',
        sendTimeout: const Duration(seconds: 30),
      ),
    );
    return ForumThread.fromJson(response.data as Map<String, dynamic>);
  }

  // ── Send message to thread ─────────────────────────────────────────────────

  Future<DiscordMessage> sendThreadMessage({
    required String threadId,
    required String content,
    String? replyToMessageId,
    List<XFile>? attachments,
  }) async {
    try {
      if (attachments != null && attachments.isNotEmpty) {
        return _sendThreadMessageWithFiles(
          threadId: threadId,
          content: content,
          replyToMessageId: replyToMessageId,
          files: attachments,
        );
      }

      final response = await dio.post(
        '/channels/$threadId/messages',
        data: <String, dynamic>{
          'content': content,
          if (replyToMessageId != null)
            'message_reference': {'message_id': replyToMessageId},
        },
      );
      return DiscordMessage.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw DiscordServiceException(
        'Failed to send thread message: ${e.response?.data}',
        statusCode: e.response?.statusCode,
      );
    }
  }

  Future<DiscordMessage> _sendThreadMessageWithFiles({
    required String threadId,
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

    final response = await dio.post(
      '/channels/$threadId/messages',
      data: formData,
      options: Options(
        contentType: 'multipart/form-data',
        sendTimeout: const Duration(seconds: 30),
      ),
    );
    return DiscordMessage.fromJson(response.data as Map<String, dynamic>);
  }

  // ── Reactions ──────────────────────────────────────────────────────────────

  Future<void> addReaction({
    required String channelId,
    required String messageId,
    required String emoji,
  }) async {
    try {
      await dio.put(
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
      await dio.delete(
        '/channels/$channelId/messages/$messageId/reactions/${Uri.encodeComponent(emoji)}/@me',
      );
    } on DioException catch (e) {
      throw DiscordServiceException(
        'Failed to remove reaction: ${e.response?.data}',
        statusCode: e.response?.statusCode,
      );
    }
  }

  // ── Bot Info ───────────────────────────────────────────────────────────────

  Future<DiscordUser> getCurrentBot() async {
    try {
      final response = await dio.get('/users/@me');
      return DiscordUser.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw DiscordServiceException(
        'Failed to get bot info: ${e.response?.data}',
        statusCode: e.response?.statusCode,
      );
    }
  }
}
