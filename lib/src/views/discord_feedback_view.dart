import 'package:flutter/material.dart';

import '../services/discord_service.dart';
import '../services/theme_storage.dart';
import '../theme/discord_feedback_theme.dart';
import 'forum_post_list_screen.dart';

/// Drop-in widget to display and submit feedback via a Discord Forum Channel.
///
/// Themes are **automatically persisted** to local storage. When the user
/// customizes the theme via the built-in theme picker, it is saved and
/// restored on the next launch.
///
/// ```dart
/// DiscordFeedbackView(
///   botToken: 'YOUR_BOT_TOKEN',
///   channelId: 'YOUR_FORUM_CHANNEL_ID',
///   enableRealtime: true,
///   appName: 'My App',
///   theme: DiscordFeedbackTheme.dark,
/// )
/// ```
class DiscordFeedbackView extends StatefulWidget {
  final String botToken;
  final String channelId;
  final String title;

  /// Initial theme. If a saved theme exists in local storage, it takes priority.
  final DiscordFeedbackTheme theme;

  final bool enableRealtime;
  final String? appName;
  final String? appVersion;
  final String? deviceInfo;
  final Widget? leading;
  final Widget? channelIcon;
  final String? channelEmoji;

  /// Called when the user changes the theme. The theme is also auto-saved.
  final ValueChanged<DiscordFeedbackTheme>? onThemeChanged;

  /// If false, the theme is NOT persisted to local storage.
  final bool persistTheme;

  /// Whether to show the floating action button for creating new feedback posts.
  final bool showCreateButton;

  const DiscordFeedbackView({
    super.key,
    required this.botToken,
    required this.channelId,
    this.title = 'bug-and-suggestions',
    this.theme = DiscordFeedbackTheme.dark,
    this.enableRealtime = false,
    this.appName,
    this.appVersion,
    this.deviceInfo,
    this.leading,
    this.channelIcon,
    this.channelEmoji,
    this.onThemeChanged,
    this.persistTheme = true,
    this.showCreateButton = true,
  });

  @override
  State<DiscordFeedbackView> createState() => _DiscordFeedbackViewState();
}

class _DiscordFeedbackViewState extends State<DiscordFeedbackView> {
  late final DiscordService _service;
  late DiscordFeedbackTheme _theme;

  @override
  void initState() {
    super.initState();
    _service = DiscordService(botToken: widget.botToken);
    _theme = widget.theme;
    if (widget.persistTheme) _loadSavedTheme();
  }

  Future<void> _loadSavedTheme() async {
    final saved = await ThemeStorage.load();
    if (saved != null && mounted) {
      setState(() => _theme = saved);
    }
  }

  void _handleThemeChanged(DiscordFeedbackTheme newTheme) {
    setState(() => _theme = newTheme);
    widget.onThemeChanged?.call(newTheme);
    if (widget.persistTheme) {
      ThemeStorage.save(newTheme);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ForumPostListScreen(
      service: _service,
      channelId: widget.channelId,
      title: widget.title,
      enableRealtime: widget.enableRealtime,
      appName: widget.appName,
      theme: _theme,
      onThemeChanged: _handleThemeChanged,
      leading: widget.leading,
      channelIcon: widget.channelIcon,
      channelEmoji: widget.channelEmoji,
      showCreateButton: widget.showCreateButton,
    );
  }
}
