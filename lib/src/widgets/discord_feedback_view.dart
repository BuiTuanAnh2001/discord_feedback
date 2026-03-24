import 'package:flutter/material.dart';
import '../services/discord_service.dart';
import 'feedback_list_screen.dart';

/// Drop-in widget hiển thị danh sách feedback từ một Discord channel.
///
/// ```dart
/// DiscordFeedbackView(
///   botToken: 'YOUR_BOT_TOKEN',
///   channelId: 'YOUR_CHANNEL_ID',
///   enableRealtime: true, // bật WebSocket realtime
/// )
/// ```
class DiscordFeedbackView extends StatefulWidget {
  /// Discord bot token (Bot xxxxxxxxxx).
  final String botToken;

  /// ID của channel muốn đọc feedback.
  final String channelId;

  /// Tiêu đề hiển thị trên app bar.
  final String title;

  /// Màu chủ đạo (mặc định Discord Blurple).
  final Color accentColor;

  /// Danh sách emoji cho quick-react.
  final List<String> quickEmojis;

  /// Cho phép chọn/chụp ảnh đính kèm.
  final bool enableImagePicker;

  /// Bật cập nhật realtime qua Discord Gateway WebSocket.
  final bool enableRealtime;

  const DiscordFeedbackView({
    super.key,
    required this.botToken,
    required this.channelId,
    this.title = 'Feedback',
    this.accentColor = const Color(0xFF5865F2),
    this.quickEmojis = const ['👍', '👎', '❤️', '🔥', '👀', '✅'],
    this.enableImagePicker = true,
    this.enableRealtime = false,
  });

  @override
  State<DiscordFeedbackView> createState() => _DiscordFeedbackViewState();
}

class _DiscordFeedbackViewState extends State<DiscordFeedbackView> {
  late final DiscordService _service;

  @override
  void initState() {
    super.initState();
    _service = DiscordService(botToken: widget.botToken);
  }

  @override
  Widget build(BuildContext context) {
    return FeedbackListScreen(
      service: _service,
      channelId: widget.channelId,
      title: widget.title,
      accentColor: widget.accentColor,
      quickEmojis: widget.quickEmojis,
      enableImagePicker: widget.enableImagePicker,
      enableRealtime: widget.enableRealtime,
    );
  }
}
