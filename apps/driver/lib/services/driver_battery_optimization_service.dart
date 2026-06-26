import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Android battery optimization exemption (Program 3E).
class DriverBatteryOptimizationService {
  const DriverBatteryOptimizationService();

  static const _prefKeyDismissed = 'driver_battery_opt_prompt_dismissed_v1';

  bool get isSupported => !kIsWeb && Platform.isAndroid;

  Future<bool> isExempt() async {
    if (!isSupported) return true;
    return Permission.ignoreBatteryOptimizations.isGranted;
  }

  Future<bool> shouldPrompt() async {
    if (!isSupported) return false;
    if (await isExempt()) return false;
    final prefs = await SharedPreferences.getInstance();
    return !(prefs.getBool(_prefKeyDismissed) ?? false);
  }

  Future<void> markPromptDismissed() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKeyDismissed, true);
  }

  Future<void> requestExemption() async {
    if (!isSupported) return;
    await Permission.ignoreBatteryOptimizations.request();
  }
}
