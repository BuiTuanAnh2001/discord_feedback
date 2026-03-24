import 'package:flutter/material.dart';

import '../theme/discord_feedback_theme.dart';

/// Discord mobile-style header with channel name, icon, and action buttons.
class DiscordHeader extends StatelessWidget {
  final DiscordFeedbackTheme theme;
  final String title;
  final bool realtimeConnected;
  final bool showRealtimeIndicator;
  final Widget? leading;
  final Widget? channelIcon;
  final String? channelEmoji;
  final VoidCallback? onBack;
  final VoidCallback? onThemeTap;
  final VoidCallback? onSearchTap;

  const DiscordHeader({
    super.key,
    required this.theme,
    required this.title,
    this.realtimeConnected = false,
    this.showRealtimeIndicator = false,
    this.leading,
    this.channelIcon,
    this.channelEmoji,
    this.onBack,
    this.onThemeTap,
    this.onSearchTap,
  });

  DiscordFeedbackTheme get t => theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: t.bgSecondary,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 6, 8, 10),
          child: Row(
            children: [
              if (leading != null)
                leading!
              else
                _iconBtn(Icons.arrow_back_rounded,
                    onBack ?? () => Navigator.maybePop(context)),
              const SizedBox(width: 4),
              _channelIcon(),
              Expanded(child: _channelName()),
              if (showRealtimeIndicator) _realtimeDot(),
              if (onThemeTap != null)
                _iconBtn(Icons.palette_rounded, onThemeTap!),
              _iconBtn(Icons.search_rounded, onSearchTap ?? () {}),
            ],
          ),
        ),
      ),
    );
  }

  Widget _channelIcon() {
    if (channelIcon != null) {
      return Padding(
        padding: const EdgeInsets.only(right: 6),
        child: channelIcon!,
      );
    }
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: t.bgTertiary,
          shape: BoxShape.circle,
        ),
        child: Icon(Icons.forum_rounded, size: 15, color: t.textMuted),
      ),
    );
  }

  Widget _channelName() {
    return Row(
      children: [
        Text(' · ',
            style: TextStyle(
                color: t.textMuted,
                fontSize: 16,
                fontWeight: FontWeight.w300)),
        Flexible(
          child: Text(
            title,
            style: TextStyle(
              color: t.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Text(' · ',
            style: TextStyle(
                color: t.textMuted,
                fontSize: 16,
                fontWeight: FontWeight.w300)),
        if (channelEmoji != null)
          Padding(
            padding: const EdgeInsets.only(right: 2),
            child: Text(channelEmoji!, style: const TextStyle(fontSize: 16)),
          ),
        Icon(Icons.chevron_right_rounded, size: 20, color: t.textMuted),
      ],
    );
  }

  Widget _realtimeDot() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: realtimeConnected ? t.successColor : t.warningColor,
        ),
      ),
    );
  }

  Widget _iconBtn(IconData icon, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, color: t.textSecondary, size: 22),
        ),
      ),
    );
  }
}
