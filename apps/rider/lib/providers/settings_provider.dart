import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../utils/rider_locale_utils.dart';

class SettingsState {
  static const supportedLanguageCodes = kRiderSupportedLanguageCodes;
  final bool languageFollowsDevice;
  final String language;
  final String theme;
  final bool locationEnabled;
  final bool notificationsEnabled;
  final String? userName;

  const SettingsState({
    this.languageFollowsDevice = true,
    this.language = 'en',
    this.theme = kRiderDefaultTheme,
    this.locationEnabled = true,
    this.notificationsEnabled = false,
    this.userName,
  });

  SettingsState copyWith({
    bool? languageFollowsDevice,
    String? language,
    String? theme,
    bool? locationEnabled,
    bool? notificationsEnabled,
    String? userName,
  }) =>
      SettingsState(
        languageFollowsDevice:
            languageFollowsDevice ?? this.languageFollowsDevice,
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
    final followsRaw = await _storage.read(key: 'language_follows_device');
    final savedLanguage = await _storage.read(key: 'language');
    final deviceLanguage = resolveRiderDeviceLocale().languageCode;

    final bool followsDevice;
    if (followsRaw != null) {
      followsDevice = followsRaw != 'false';
    } else if (savedLanguage != null && savedLanguage.trim().isNotEmpty) {
      // Existing installs: keep explicit language until user picks "device".
      followsDevice = false;
    } else {
      followsDevice = true;
    }

    final normalizedSaved = (savedLanguage ?? '').trim().toLowerCase();
    final overrideLanguage =
        SettingsState.supportedLanguageCodes.contains(normalizedSaved)
            ? normalizedSaved
            : deviceLanguage;
    final language = followsDevice ? deviceLanguage : overrideLanguage;
    const theme = kRiderDefaultTheme;
    await _storage.write(key: 'theme', value: theme);
    final locationEnabled =
        await _storage.read(key: 'location_enabled') != 'false';
    final notificationsEnabled =
        await _storage.read(key: 'notifications_enabled') == 'true';
    final userName = await _storage.read(key: 'user_name');

    return SettingsState(
      languageFollowsDevice: followsDevice,
      language: language,
      theme: theme,
      locationEnabled: locationEnabled,
      notificationsEnabled: notificationsEnabled,
      userName: userName,
    );
  }

  Future<void> setLanguage(String language) async {
    final code = language.trim().toLowerCase();
    if (!SettingsState.supportedLanguageCodes.contains(code)) return;
    await _storage.write(key: 'language', value: code);
    await _storage.write(key: 'language_follows_device', value: 'false');
    state = AsyncData(
      state.value!.copyWith(
        languageFollowsDevice: false,
        language: code,
      ),
    );
  }

  Future<void> setFollowDeviceLanguage() async {
    final deviceLanguage = resolveRiderDeviceLocale().languageCode;
    await _storage.write(key: 'language_follows_device', value: 'true');
    state = AsyncData(
      state.value!.copyWith(
        languageFollowsDevice: true,
        language: deviceLanguage,
      ),
    );
  }

  Future<void> setTheme(String theme) async {
    await _storage.write(key: 'theme', value: kRiderDefaultTheme);
    state = AsyncData(state.value!.copyWith(theme: kRiderDefaultTheme));
  }

  Future<void> setLocationEnabled(bool enabled) async {
    await _storage.write(key: 'location_enabled', value: enabled.toString());
    state = AsyncData(state.value!.copyWith(locationEnabled: enabled));
  }

  Future<void> setNotificationsEnabled(bool enabled) async {
    await _storage.write(
        key: 'notifications_enabled', value: enabled.toString());
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
