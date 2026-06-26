import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:heycaby_ui/heycaby_ui.dart';
import 'dart:ui';

class SettingsState {
  static const supportedLanguageCodes = <String>{'nl', 'en', 'ar'};
  final String language;
  final String theme;
  final bool locationEnabled;
  final bool notificationsEnabled;
  final String? userName;

  const SettingsState({
    this.language = 'nl',
    this.theme = kRiderDefaultTheme,
    this.locationEnabled = true,
    this.notificationsEnabled = false,
    this.userName,
  });

  SettingsState copyWith({
    String? language,
    String? theme,
    bool? locationEnabled,
    bool? notificationsEnabled,
    String? userName,
  }) =>
      SettingsState(
        language: language ?? this.language,
        theme: theme ?? this.theme,
        locationEnabled: locationEnabled ?? this.locationEnabled,
        notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
        userName: userName ?? this.userName,
      );
}

class SettingsNotifier extends AsyncNotifier<SettingsState> {
  final _storage = const FlutterSecureStorage();

  @override
  Future<SettingsState> build() async {
    return _loadSettings();
  }

  Future<SettingsState> _loadSettings() async {
    final savedLanguage = await _storage.read(key: 'language');
    final deviceLanguage = PlatformDispatcher.instance.locale.languageCode.toLowerCase();
    final normalizedSaved = (savedLanguage ?? '').trim().toLowerCase();
    final language = SettingsState.supportedLanguageCodes.contains(normalizedSaved)
        ? normalizedSaved
        : (SettingsState.supportedLanguageCodes.contains(deviceLanguage)
            ? deviceLanguage
            : 'nl');
    var theme = await _storage.read(key: 'theme') ?? kRiderDefaultTheme;
    theme = migrateThemeId(theme);
    if (!kThemes.containsKey(theme)) theme = kRiderDefaultTheme;
    await _storage.write(key: 'theme', value: theme);
    final locationEnabled = await _storage.read(key: 'location_enabled') != 'false';
    final notificationsEnabled = await _storage.read(key: 'notifications_enabled') == 'true';
    final userName = await _storage.read(key: 'user_name');

    return SettingsState(
      language: language,
      theme: theme,
      locationEnabled: locationEnabled,
      notificationsEnabled: notificationsEnabled,
      userName: userName,
    );
  }

  Future<void> setLanguage(String language) async {
    await _storage.write(key: 'language', value: language);
    state = AsyncData(state.value!.copyWith(language: language));
  }

  Future<void> setTheme(String theme) async {
    final resolved = migrateThemeId(theme);
    final id = kThemes.containsKey(resolved) ? resolved : kRiderDefaultTheme;
    await _storage.write(key: 'theme', value: id);
    state = AsyncData(state.value!.copyWith(theme: id));
  }

  Future<void> setLocationEnabled(bool enabled) async {
    await _storage.write(key: 'location_enabled', value: enabled.toString());
    state = AsyncData(state.value!.copyWith(locationEnabled: enabled));
  }

  Future<void> setNotificationsEnabled(bool enabled) async {
    await _storage.write(key: 'notifications_enabled', value: enabled.toString());
    state = AsyncData(state.value!.copyWith(notificationsEnabled: enabled));
  }

  /// Aligns secure storage + in-memory state with actual OS permission grants.
  Future<void> syncDevicePermissions({
    required bool locationGranted,
    required bool notificationsGranted,
  }) async {
    await _storage.write(
        key: 'location_enabled', value: locationGranted.toString());
    await _storage.write(
        key: 'notifications_enabled', value: notificationsGranted.toString());
    final base = state.value ?? await _loadSettings();
    state = AsyncData(
      base.copyWith(
        locationEnabled: locationGranted,
        notificationsEnabled: notificationsGranted,
      ),
    );
  }

  Future<void> setUserName(String name) async {
    await _storage.write(key: 'user_name', value: name);
    state = AsyncData(state.value!.copyWith(userName: name));
  }

  Future<void> clearUserName() async {
    await _storage.delete(key: 'user_name');
    final base = state.value ?? await _loadSettings();
    state = AsyncData(base.copyWith(userName: ''));
  }
}

final settingsProvider = AsyncNotifierProvider<SettingsNotifier, SettingsState>(
  SettingsNotifier.new,
);
