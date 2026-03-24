import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/models.dart';

enum GatewayEventType {
  messageCreate,
  messageUpdate,
  messageDelete,
  reactionAdd,
  reactionRemove,
  threadCreate,
  threadUpdate,
  threadDelete,
  ready,
}

class ReactionEventData {
  final String messageId;
  final String channelId;
  final String userId;
  final DiscordEmoji emoji;

  const ReactionEventData({
    required this.messageId,
    required this.channelId,
    required this.userId,
    required this.emoji,
  });

  factory ReactionEventData.fromJson(Map<String, dynamic> json) {
    return ReactionEventData(
      messageId: json['message_id'] as String,
      channelId: json['channel_id'] as String,
      userId: json['user_id'] as String,
      emoji: DiscordEmoji.fromJson(json['emoji'] as Map<String, dynamic>),
    );
  }
}

/// WebSocket connection to Discord Gateway for realtime events.
class DiscordGateway {
  final String botToken;
  final String channelId;

  WebSocketChannel? _channel;
  Timer? _heartbeatTimer;
  int? _lastSequence;
  String? _botUserId;
  bool _isConnected = false;
  bool _disposed = false;
  int _reconnectAttempts = 0;

  final _messageCreateCtrl = StreamController<DiscordMessage>.broadcast();
  final _messageUpdateCtrl = StreamController<DiscordMessage>.broadcast();
  final _messageDeleteCtrl = StreamController<String>.broadcast();
  final _reactionAddCtrl = StreamController<ReactionEventData>.broadcast();
  final _reactionRemoveCtrl = StreamController<ReactionEventData>.broadcast();
  final _threadCreateCtrl = StreamController<ForumThread>.broadcast();
  final _threadUpdateCtrl = StreamController<ForumThread>.broadcast();
  final _threadDeleteCtrl = StreamController<String>.broadcast();
  final _connectionCtrl = StreamController<bool>.broadcast();

  Stream<DiscordMessage> get onMessageCreate => _messageCreateCtrl.stream;
  Stream<DiscordMessage> get onMessageUpdate => _messageUpdateCtrl.stream;
  Stream<String> get onMessageDelete => _messageDeleteCtrl.stream;
  Stream<ReactionEventData> get onReactionAdd => _reactionAddCtrl.stream;
  Stream<ReactionEventData> get onReactionRemove => _reactionRemoveCtrl.stream;
  Stream<ForumThread> get onThreadCreate => _threadCreateCtrl.stream;
  Stream<ForumThread> get onThreadUpdate => _threadUpdateCtrl.stream;
  Stream<String> get onThreadDelete => _threadDeleteCtrl.stream;
  Stream<bool> get onConnectionChanged => _connectionCtrl.stream;

  String? get botUserId => _botUserId;
  bool get isConnected => _isConnected;

  static const _gatewayUrl =
      'wss://gateway.discord.gg/?v=10&encoding=json';

  // GUILDS (1) | GUILD_MESSAGES (512) | GUILD_MESSAGE_REACTIONS (1024) | MESSAGE_CONTENT (32768)
  static const _intents = 1 | 512 | 1024 | 32768;

  DiscordGateway({required this.botToken, required this.channelId});

  Future<void> connect() async {
    if (_disposed || _isConnected) return;

    try {
      _channel = WebSocketChannel.connect(Uri.parse(_gatewayUrl));
      await _channel!.ready;
      _isConnected = true;
      _reconnectAttempts = 0;
      _connectionCtrl.add(true);

      _channel!.stream.listen(
        _handleRawMessage,
        onError: (_) => _scheduleReconnect(),
        onDone: () => _scheduleReconnect(),
      );
    } catch (_) {
      _scheduleReconnect();
    }
  }

  void disconnect() {
    _heartbeatTimer?.cancel();
    _channel?.sink.close();
    _isConnected = false;
    _connectionCtrl.add(false);
  }

  void dispose() {
    _disposed = true;
    disconnect();
    _messageCreateCtrl.close();
    _messageUpdateCtrl.close();
    _messageDeleteCtrl.close();
    _reactionAddCtrl.close();
    _reactionRemoveCtrl.close();
    _threadCreateCtrl.close();
    _threadUpdateCtrl.close();
    _threadDeleteCtrl.close();
    _connectionCtrl.close();
  }

  void _handleRawMessage(dynamic raw) {
    final json = jsonDecode(raw as String) as Map<String, dynamic>;
    final op = json['op'] as int;
    final seq = json['s'] as int?;
    final eventName = json['t'] as String?;
    final data = json['d'];

    if (seq != null) _lastSequence = seq;

    switch (op) {
      case 10:
        final interval =
            (data as Map<String, dynamic>)['heartbeat_interval'] as int;
        _startHeartbeat(interval);
        _sendIdentify();
        break;
      case 11:
        break;
      case 0:
        if (eventName != null && data is Map<String, dynamic>) {
          _handleDispatch(eventName, data);
        }
        break;
      case 7:
      case 9:
        _scheduleReconnect();
        break;
    }
  }

  void _sendIdentify() {
    _send({
      'op': 2,
      'd': {
        'token': botToken,
        'intents': _intents,
        'properties': {
          'os': 'flutter',
          'browser': 'discord_feedback',
          'device': 'discord_feedback',
        },
      },
    });
  }

  void _startHeartbeat(int intervalMs) {
    _heartbeatTimer?.cancel();
    Future.delayed(
      Duration(milliseconds: (intervalMs * 0.5).toInt()),
      () {
        if (!_disposed && _isConnected) {
          _send({'op': 1, 'd': _lastSequence});
        }
      },
    );
    _heartbeatTimer = Timer.periodic(
      Duration(milliseconds: intervalMs),
      (_) => _send({'op': 1, 'd': _lastSequence}),
    );
  }

  void _handleDispatch(String type, Map<String, dynamic> data) {
    switch (type) {
      case 'READY':
        final user = data['user'] as Map<String, dynamic>?;
        _botUserId = user?['id'] as String?;
        break;

      // Thread events — filter by parent_id (the forum channel)
      case 'THREAD_CREATE':
        if (data['parent_id'] != channelId) return;
        _threadCreateCtrl.add(ForumThread.fromJson(data));
        break;

      case 'THREAD_UPDATE':
        if (data['parent_id'] != channelId) return;
        _threadUpdateCtrl.add(ForumThread.fromJson(data));
        break;

      case 'THREAD_DELETE':
        if (data['parent_id'] != channelId) return;
        _threadDeleteCtrl.add(data['id'] as String);
        break;

      // Message events — channel_id is the thread id for messages inside threads
      case 'MESSAGE_CREATE':
        _messageCreateCtrl.add(DiscordMessage.fromJson(data));
        break;

      case 'MESSAGE_UPDATE':
        if (data.containsKey('author')) {
          _messageUpdateCtrl.add(DiscordMessage.fromJson(data));
        }
        break;

      case 'MESSAGE_DELETE':
        _messageDeleteCtrl.add(data['id'] as String);
        break;

      case 'MESSAGE_REACTION_ADD':
        _reactionAddCtrl.add(ReactionEventData.fromJson(data));
        break;

      case 'MESSAGE_REACTION_REMOVE':
        _reactionRemoveCtrl.add(ReactionEventData.fromJson(data));
        break;
    }
  }

  void _send(Map<String, dynamic> data) {
    if (_isConnected && _channel != null) {
      _channel!.sink.add(jsonEncode(data));
    }
  }

  void _scheduleReconnect() {
    if (_disposed) return;
    disconnect();
    _reconnectAttempts++;
    final delay = Duration(
      seconds: (_reconnectAttempts * 2).clamp(1, 30),
    );
    Future.delayed(delay, () {
      if (!_disposed) connect();
    });
  }
}
