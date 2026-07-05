import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tek_sensor_monitor/core/local_notifications.dart';

const _languageKey = 'tek_language';

enum AppLanguage {
  russian,
  english;

  Locale get locale => switch (this) {
        AppLanguage.russian => const Locale('ru'),
        AppLanguage.english => const Locale('en'),
      };

  String get storageValue => name;

  static AppLanguage fromStorage(String? value) {
    return AppLanguage.values.firstWhere(
      (e) => e.name == value,
      orElse: () => resolveSystemLanguage(),
    );
  }

  static AppLanguage resolveSystemLanguage() {
    try {
      final code = PlatformDispatcher.instance.locale.languageCode;
      if (code == 'ru') return AppLanguage.russian;
      return AppLanguage.english;
    } catch (_) {
      return AppLanguage.russian;
    }
  }
}

class LanguagePreferenceNotifier extends StateNotifier<AppLanguage> {
  LanguagePreferenceNotifier() : super(AppLanguage.resolveSystemLanguage()) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_languageKey);
    if (stored == null) {
      state = AppLanguage.resolveSystemLanguage();
    } else {
      state = AppLanguage.fromStorage(stored);
    }
    _syncNotificationChannel(state);
  }

  void _syncNotificationChannel(AppLanguage language) {
    LocalNotifications.updateChannelStrings(
      channelName: language == AppLanguage.russian
          ? 'Изменения прав'
          : 'Role changes',
      channelDescription: language == AppLanguage.russian
          ? 'Повышение и понижение пользователей'
          : 'User promotions and demotions',
    );
  }

  Future<void> setLanguage(AppLanguage language) async {
    state = language;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languageKey, language.storageValue);
    _syncNotificationChannel(language);
  }
}

final languagePreferenceProvider =
    StateNotifierProvider<LanguagePreferenceNotifier, AppLanguage>(
  (ref) => LanguagePreferenceNotifier(),
);
