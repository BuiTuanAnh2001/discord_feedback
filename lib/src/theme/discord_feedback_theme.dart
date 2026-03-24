import 'package:flutter/material.dart';

class DiscordFeedbackTheme {
  final Color bgPrimary;
  final Color bgSecondary;
  final Color bgTertiary;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color accent;
  final Color inputBg;
  final Color dividerColor;
  final Color cardBg;
  final Color dangerColor;
  final Color successColor;
  final Color warningColor;
  final Brightness brightness;

  const DiscordFeedbackTheme({
    required this.bgPrimary,
    required this.bgSecondary,
    required this.bgTertiary,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.accent,
    required this.inputBg,
    required this.dividerColor,
    required this.cardBg,
    required this.dangerColor,
    required this.successColor,
    required this.warningColor,
    required this.brightness,
  });

  static const dark = DiscordFeedbackTheme(
    bgPrimary: Color(0xFF1E1F22),
    bgSecondary: Color(0xFF2B2D31),
    bgTertiary: Color(0xFF313338),
    textPrimary: Color(0xFFF2F3F5),
    textSecondary: Color(0xFFB5BAC1),
    textMuted: Color(0xFF949BA4),
    accent: Color(0xFF5865F2),
    inputBg: Color(0xFF383A40),
    dividerColor: Color(0xFF3F4147),
    cardBg: Color(0xFF2B2D31),
    dangerColor: Color(0xFFED4245),
    successColor: Color(0xFF23A55A),
    warningColor: Color(0xFFF0B232),
    brightness: Brightness.dark,
  );

  static const light = DiscordFeedbackTheme(
    bgPrimary: Color(0xFFFFFFFF),
    bgSecondary: Color(0xFFF2F3F5),
    bgTertiary: Color(0xFFE3E5E8),
    textPrimary: Color(0xFF060607),
    textSecondary: Color(0xFF4E5058),
    textMuted: Color(0xFF80848E),
    accent: Color(0xFF5865F2),
    inputBg: Color(0xFFE3E5E8),
    dividerColor: Color(0xFFE1E2E4),
    cardBg: Color(0xFFFFFFFF),
    dangerColor: Color(0xFFDA373C),
    successColor: Color(0xFF248046),
    warningColor: Color(0xFFE0A400),
    brightness: Brightness.light,
  );

  static const midnight = DiscordFeedbackTheme(
    bgPrimary: Color(0xFF000000),
    bgSecondary: Color(0xFF111214),
    bgTertiary: Color(0xFF1A1B1E),
    textPrimary: Color(0xFFDBDEE1),
    textSecondary: Color(0xFF949BA4),
    textMuted: Color(0xFF6D6F78),
    accent: Color(0xFF5865F2),
    inputBg: Color(0xFF1A1B1E),
    dividerColor: Color(0xFF2E2F34),
    cardBg: Color(0xFF111214),
    dangerColor: Color(0xFFED4245),
    successColor: Color(0xFF23A55A),
    warningColor: Color(0xFFF0B232),
    brightness: Brightness.dark,
  );

  DiscordFeedbackTheme copyWith({
    Color? bgPrimary,
    Color? bgSecondary,
    Color? bgTertiary,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? accent,
    Color? inputBg,
    Color? dividerColor,
    Color? cardBg,
    Color? dangerColor,
    Color? successColor,
    Color? warningColor,
    Brightness? brightness,
  }) {
    return DiscordFeedbackTheme(
      bgPrimary: bgPrimary ?? this.bgPrimary,
      bgSecondary: bgSecondary ?? this.bgSecondary,
      bgTertiary: bgTertiary ?? this.bgTertiary,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      accent: accent ?? this.accent,
      inputBg: inputBg ?? this.inputBg,
      dividerColor: dividerColor ?? this.dividerColor,
      cardBg: cardBg ?? this.cardBg,
      dangerColor: dangerColor ?? this.dangerColor,
      successColor: successColor ?? this.successColor,
      warningColor: warningColor ?? this.warningColor,
      brightness: brightness ?? this.brightness,
    );
  }

  Color tagColor(String name) {
    final n = name.toLowerCase();
    if (n.contains('bug')) return dangerColor;
    if (n.contains('suggestion')) return warningColor;
    if (n.contains('feature')) return accent;
    if (n.contains('submitted')) return successColor;
    if (n.contains('in review') || n.contains('review')) {
      return const Color(0xFF9B59B6);
    }
    if (n.contains('verified')) return successColor;
    if (n.contains('fix in progress') || n.contains('progress')) {
      return const Color(0xFFE67E22);
    }
    if (n.contains('closed') || n.contains('resolved')) return textMuted;
    return accent;
  }

  Map<String, dynamic> toJson() => {
        'bgPrimary': bgPrimary.toARGB32(),
        'bgSecondary': bgSecondary.toARGB32(),
        'bgTertiary': bgTertiary.toARGB32(),
        'textPrimary': textPrimary.toARGB32(),
        'textSecondary': textSecondary.toARGB32(),
        'textMuted': textMuted.toARGB32(),
        'accent': accent.toARGB32(),
        'inputBg': inputBg.toARGB32(),
        'dividerColor': dividerColor.toARGB32(),
        'cardBg': cardBg.toARGB32(),
        'dangerColor': dangerColor.toARGB32(),
        'successColor': successColor.toARGB32(),
        'warningColor': warningColor.toARGB32(),
        'brightness': brightness == Brightness.dark ? 'dark' : 'light',
      };

  factory DiscordFeedbackTheme.fromJson(Map<String, dynamic> json) {
    return DiscordFeedbackTheme(
      bgPrimary: _colorFromARGB32(json['bgPrimary'] as int),
      bgSecondary: _colorFromARGB32(json['bgSecondary'] as int),
      bgTertiary: _colorFromARGB32(json['bgTertiary'] as int),
      textPrimary: _colorFromARGB32(json['textPrimary'] as int),
      textSecondary: _colorFromARGB32(json['textSecondary'] as int),
      textMuted: _colorFromARGB32(json['textMuted'] as int),
      accent: _colorFromARGB32(json['accent'] as int),
      inputBg: _colorFromARGB32(json['inputBg'] as int),
      dividerColor: _colorFromARGB32(json['dividerColor'] as int),
      cardBg: _colorFromARGB32(json['cardBg'] as int),
      dangerColor: _colorFromARGB32(json['dangerColor'] as int),
      successColor: _colorFromARGB32(json['successColor'] as int),
      warningColor: _colorFromARGB32(json['warningColor'] as int),
      brightness:
          json['brightness'] == 'dark' ? Brightness.dark : Brightness.light,
    );
  }

  static Color _colorFromARGB32(int value) {
    return Color.fromARGB(
      (value >> 24) & 0xFF,
      (value >> 16) & 0xFF,
      (value >> 8) & 0xFF,
      value & 0xFF,
    );
  }
}
