import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'data/repository/settings_repository.dart';

class AppSettingsService extends GetxService {
  final SettingsRepository _repository = SettingsRepository();

  final RxString currentTheme = 'system'.obs;
  final RxString currentLanguage = 'system'.obs;

  Future<AppSettingsService> init() async {
    final settings = await _repository.load();
    currentTheme.value = settings.theme;
    currentLanguage.value = settings.language;
    return this;
  }

  Future<void> setTheme(String theme) async {
    currentTheme.value = theme;
    await _repository.setTheme(theme);
  }

  Future<void> setLanguage(String language) async {
    currentLanguage.value = language;
    await _repository.setLanguage(language);
    await Get.updateLocale(resolvedLocale);
  }

  ThemeMode get themeMode {
    switch (currentTheme.value) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  Locale? get locale {
    switch (currentLanguage.value) {
      case 'zh':
        return const Locale('zh');
      case 'en':
        return const Locale('en');
      default:
        return null;
    }
  }

  Locale get resolvedLocale {
    final configured = locale;
    if (configured != null) {
      return configured;
    }

    final device = Get.deviceLocale;
    if (device == null) {
      return const Locale('zh');
    }

    return device.languageCode == 'en'
        ? const Locale('en')
        : const Locale('zh');
  }

  SettingsRepository get repository => _repository;
}
