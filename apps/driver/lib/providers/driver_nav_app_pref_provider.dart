import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/driver_nav_app_pref.dart';

/// Loads/saves [DriverNavApp] from SharedPreferences (`nav_app_pref`).
class DriverNavAppPrefRepository {
  Future<DriverNavApp> load() async {
    final prefs = await SharedPreferences.getInstance();
    return DriverNavApp.fromStored(prefs.getString(DriverNavApp.prefKey));
  }

  Future<void> save(DriverNavApp app) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(DriverNavApp.prefKey, app.storageValue);
  }
}

class DriverNavAppPrefNotifier extends AsyncNotifier<DriverNavApp> {
  @override
  Future<DriverNavApp> build() =>
      ref.read(driverNavAppPrefRepositoryProvider).load();

  Future<void> setApp(DriverNavApp app) async {
    await ref.read(driverNavAppPrefRepositoryProvider).save(app);
    state = AsyncData(app);
  }
}

final driverNavAppPrefRepositoryProvider =
    Provider<DriverNavAppPrefRepository>((_) => DriverNavAppPrefRepository());

final driverNavAppPrefProvider =
    AsyncNotifierProvider<DriverNavAppPrefNotifier, DriverNavApp>(
  DriverNavAppPrefNotifier.new,
);
