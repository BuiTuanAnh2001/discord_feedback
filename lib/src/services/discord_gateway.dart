import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/models.dart';

/// Loại sự kiện từ Discord Gateway.
enum GatewayEventType {
  messageCreate,
  messageUpdate,
  messageDelete,
  reactionAdd,
  reactionRemove,
  ready,
}

/// Dữ liệu reaction event (add/remove).
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

/// Kết nối WebSocket tới Discord Gateway để nhận events realtime.
///
/// ```dart
/// final gateway = DiscordGateway(
///   botToken: 'YOUR_TOKEN',
///   channelId: 'YOUR_CHANNEL_ID',
/// );
/// await gateway.connect();
///
/// gateway.onMessageCreate.listen((msg) {
///   print('New message: ${msg.content}');
/// });
/// ```
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
  final _connectionCtrl = StreamController<bool>.broadcast();

  /// Stream tin nhắn mới.
  Stream<DiscordMessage> get onMessageCreate => _messageCreateCtrl.stream;

  /// Stream tin nhắn được chỉnh sửa.
  Stream<DiscordMessage> get onMessageUpdate => _messageUpdateCtrl.stream;

  /// Stream ID tin nhắn bị xóa.
  Stream<String> get onMessageDelete => _messageDeleteCtrl.stream;

  /// Stream reaction được thêm.
  Stream<ReactionEventData> get onReactionAdd => _reactionAddCtrl.stream;

  /// Stream reaction bị gỡ.
  Stream<ReactionEventData> get onReactionRemove => _reactionRemoveCtrl.stream;

  /// Stream trạng thái kết nối (true = connected, false = disconnected).
  Stream<bool> get onConnectionChanged => _connectionCtrl.stream;

  /// ID user của bot (có sau khi nhận READY event).
  String? get botUserId => _botUserId;

  /// Trạng thái kết nối.
  bool get isConnected => _isConnected;

  static const _gatewayUrl =
      'wss://gateway.discord.gg/?v=10&encoding=json';

  // GUILD_MESSAGES (512) | GUILD_MESSAGE_REACTIONS (1024) | MESSAGE_CONTENT (32768)
  static const _intents = 512 | 1024 | 32768;

  DiscordGateway({required this.botToken, required this.channelId});

  /// Kết nối tới Discord Gateway.
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

  /// Ngắt kết nối.
  void disconnect() {
    _heartbeatTimer?.cancel();
    _channel?.sink.close();
    _isConnected = false;
    _connectionCtrl.add(false);
  }

  /// Giải phóng tài nguyên. Sau khi gọi dispose() không thể dùng lại.
  void dispose() {
    _disposed = true;
    disconnect();
    _messageCreateCtrl.close();
    _messageUpdateCtrl.close();
    _messageDeleteCtrl.close();
    _reactionAddCtrl.close();
    _reactionRemoveCtrl.close();
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
      case 10: // Hello
        final interval =
            (data as Map<String, dynamic>)['heartbeat_interval'] as int;
        _startHeartbeat(interval);
        _sendIdentify();
        break;
      case 11: // Heartbeat ACK — no action needed
        break;
      case 0: // Dispatch
        if (eventName != null && data is Map<String, dynamic>) {
          _handleDispatch(eventName, data);
        }
        break;
      case 7: // Reconnect requested
        _scheduleReconnect();
        break;
      case 9: // Invalid session
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
    // Gửi heartbeat đầu tiên sau khoảng random (theo spec Discord)
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

      case 'MESSAGE_CREATE':
        if (data['channel_id'] != channelId) return;
        _messageCreateCtrl.add(DiscordMessage.fromJson(data));
        break;

      case 'MESSAGE_UPDATE':
        if (data['channel_id'] != channelId) return;
        // MESSAGE_UPDATE có thể chỉ chứa partial data
        if (data.containsKey('author')) {
          _messageUpdateCtrl.add(DiscordMessage.fromJson(data));
        }
        break;

      case 'MESSAGE_DELETE':
        if (data['channel_id'] != channelId) return;
        _messageDeleteCtrl.add(data['id'] as String);
        break;

      case 'MESSAGE_REACTION_ADD':
        if (data['channel_id'] != channelId) return;
        _reactionAddCtrl.add(ReactionEventData.fromJson(data));
        break;

      case 'MESSAGE_REACTION_REMOVE':
        if (data['channel_id'] != channelId) return;
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
    // Exponential backoff: 1s, 2s, 4s, 8s, max 30s
    final delay = Duration(
      seconds: (_reconnectAttempts * 2).clamp(1, 30),
    );
    Future.delayed(delay, () {
      if (!_disposed) connect();
    });
  }
}
