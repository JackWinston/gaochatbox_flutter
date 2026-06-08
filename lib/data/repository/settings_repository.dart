import 'package:shared_preferences/shared_preferences.dart';

class AppSettingsData {
  final bool showCharCount;
  final bool showTokenCount;
  final bool showModelName;
  final bool showTimestamp;
  final bool webSearchEnabled;
  final int maxToolCallRounds;
  final String language;
  final String theme;

  const AppSettingsData({
    required this.showCharCount,
    required this.showTokenCount,
    required this.showModelName,
    required this.showTimestamp,
    required this.webSearchEnabled,
    required this.maxToolCallRounds,
    required this.language,
    required this.theme,
  });
}

class SettingsRepository {
  static const _keyShowCharCount = 'ui_show_char_count';
  static const _keyShowTokenCount = 'ui_show_token_count';
  static const _keyShowModelName = 'ui_show_model_name';
  static const _keyShowTimestamp = 'ui_show_timestamp';
  static const _keyWebSearchEnabled = 'capability_web_search';
  static const _keyMaxToolCallRounds = 'capability_max_tool_call_rounds';
  static const _keyLanguage = 'app_language';
  static const _keyTheme = 'app_theme';

  static const minMaxToolCallRounds = 1;
  static const maxMaxToolCallRounds = 32;
  static const defaultMaxToolCallRounds = 8;

  Future<AppSettingsData> load() async {
    final prefs = await SharedPreferences.getInstance();
    return AppSettingsData(
      showCharCount: prefs.getBool(_keyShowCharCount) ?? false,
      showTokenCount: prefs.getBool(_keyShowTokenCount) ?? false,
      showModelName: prefs.getBool(_keyShowModelName) ?? false,
      showTimestamp: prefs.getBool(_keyShowTimestamp) ?? false,
      webSearchEnabled: prefs.getBool(_keyWebSearchEnabled) ?? false,
      maxToolCallRounds:
          (prefs.getInt(_keyMaxToolCallRounds) ?? defaultMaxToolCallRounds)
              .clamp(minMaxToolCallRounds, maxMaxToolCallRounds),
      language: prefs.getString(_keyLanguage) ?? 'system',
      theme: prefs.getString(_keyTheme) ?? 'system',
    );
  }

  Future<void> setShowCharCount(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyShowCharCount, value);
  }

  Future<void> setShowTokenCount(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyShowTokenCount, value);
  }

  Future<void> setShowModelName(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyShowModelName, value);
  }

  Future<void> setShowTimestamp(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyShowTimestamp, value);
  }

  Future<void> setWebSearchEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyWebSearchEnabled, value);
  }

  Future<void> setMaxToolCallRounds(int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      _keyMaxToolCallRounds,
      value.clamp(minMaxToolCallRounds, maxMaxToolCallRounds),
    );
  }

  Future<void> setLanguage(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLanguage, value);
  }

  Future<void> setTheme(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyTheme, value);
  }
}
