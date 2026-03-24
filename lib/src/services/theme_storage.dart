import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/discord_feedback_theme.dart';

/// Persists [DiscordFeedbackTheme] to local storage via SharedPreferences.
class ThemeStorage {
  static const _key = 'discord_feedback_theme';

  const ThemeStorage._();

  static Future<DiscordFeedbackTheme?> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null) return null;
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return DiscordFeedbackTheme.fromJson(json);
    } catch (e) {
      debugPrint('[discord_feedback] ThemeStorage.load error: $e');
      return null;
    }
  }

  static Future<bool> save(DiscordFeedbackTheme theme) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = jsonEncode(theme.toJson());
      return prefs.setString(_key, json);
    } catch (e) {
      debugPrint('[discord_feedback] ThemeStorage.save error: $e');
      return false;
    }
  }

  static Future<bool> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.remove(_key);
    } catch (e) {
      debugPrint('[discord_feedback] ThemeStorage.clear error: $e');
      return false;
    }
  }
}
