import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/driver_strings.dart';
import 'driver_nav_app_pref.dart';

export 'driver_nav_app_pref.dart';

/// Shared Waze / Google Maps launcher for driver trips and hotspots (Program 3D).
class DriverNavigationLauncher {
  const DriverNavigationLauncher._();

  static Uri googleNativeUri(double lat, double lng) => Uri.parse(
        'comgooglemaps://?daddr=$lat,$lng&directionsmode=driving',
      );

  static Uri googleWebUri(double lat, double lng) => Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving',
      );

  static Uri googleWebSearchUri(String destination) => Uri.https(
        'www.google.com',
        '/maps/dir/',
        {
          'api': '1',
          'destination': destination,
          'travelmode': 'driving',
        },
      );

  static Uri wazeWebSearchUri(String destination) => Uri.parse(
        'https://waze.com/ul?q=${Uri.encodeComponent(destination)}&navigate=yes',
      );

  static Uri wazeNativeUri(double lat, double lng) =>
      Uri.parse('waze://?ll=$lat,$lng&navigate=yes');

  static Uri wazeNativeAddressUri(
    String destination, {
    double? lat,
    double? lng,
  }) {
    final query = Uri.encodeComponent(destination.trim());
    if (lat != null && lng != null && coordsAreValid(lat, lng)) {
      return Uri.parse('waze://?q=$query&ll=$lat,$lng&navigate=yes');
    }
    return Uri.parse('waze://?q=$query&navigate=yes');
  }

  static Uri wazeWebUri(double lat, double lng) =>
      Uri.parse('https://waze.com/ul?ll=$lat,$lng&navigate=yes');

  static bool coordsAreValid(double? lat, double? lng) {
    if (lat == null || lng == null) return false;
    if (lat.abs() > 90 || lng.abs() > 180) return false;
    if (lat.abs() < 0.0001 && lng.abs() < 0.0001) return false;
    return true;
  }

  /// Opens navigation with address and/or coordinates (native → web fallback).
  static Future<bool> launchToDestination({
    required DriverNavApp app,
    double? lat,
    double? lng,
    String? address,
  }) async {
    final query = address?.trim() ?? '';
    final coordsOk = coordsAreValid(lat, lng);

    switch (app) {
      case DriverNavApp.waze:
        if (query.isNotEmpty) {
          final native = wazeNativeAddressUri(
            query,
            lat: coordsOk ? lat : null,
            lng: coordsOk ? lng : null,
          );
          if (await launchUrl(native, mode: LaunchMode.externalApplication)) {
            return true;
          }
          if (await launchUrl(
            wazeWebSearchUri(query),
            mode: LaunchMode.externalApplication,
          )) {
            return true;
          }
        }
        if (coordsOk) return _launchWaze(lat!, lng!);
        return false;
      case DriverNavApp.google:
        if (query.isNotEmpty) {
          final native = Uri.parse(
            'comgooglemaps://?daddr=${Uri.encodeComponent(query)}&directionsmode=driving',
          );
          if (await launchUrl(native, mode: LaunchMode.externalApplication)) {
            return true;
          }
          if (await launchUrl(
            googleWebSearchUri(query),
            mode: LaunchMode.externalApplication,
          )) {
            return true;
          }
        }
        if (coordsOk) return _launchGoogle(lat!, lng!);
        return false;
    }
  }

  /// Opens the preferred app with native → web fallback.
  static Future<bool> launchPreferred({
    required double lat,
    required double lng,
    required DriverNavApp app,
  }) async {
    return launchToDestination(app: app, lat: lat, lng: lng);
  }

  /// Address fallback for older rows that have labels but no stored coordinates.
  static Future<bool> launchAddress({
    required String destination,
    required DriverNavApp app,
  }) async {
    return launchToDestination(app: app, address: destination);
  }

  static Future<bool> _launchGoogle(double lat, double lng) async {
    final native = googleNativeUri(lat, lng);
    if (await launchUrl(native, mode: LaunchMode.externalApplication)) {
      return true;
    }
    return launchUrl(
      googleWebUri(lat, lng),
      mode: LaunchMode.externalApplication,
    );
  }

  static Future<bool> _launchWaze(double lat, double lng) async {
    final native = wazeNativeUri(lat, lng);
    if (await launchUrl(native, mode: LaunchMode.externalApplication)) {
      return true;
    }
    return launchUrl(
      wazeWebUri(lat, lng),
      mode: LaunchMode.externalApplication,
    );
  }

  /// Hotspots — let the driver pick Waze or Google for this destination.
  static Future<void> showChooser(
    BuildContext context, {
    required double lat,
    required double lng,
  }) async {
    final choice = await showModalBottomSheet<DriverNavApp>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) => SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.map_outlined),
              title: const Text(DriverStrings.hotspotsGoogleMaps),
              onTap: () => Navigator.pop(ctx, DriverNavApp.google),
            ),
            ListTile(
              leading: const Icon(Icons.navigation_outlined),
              title: const Text(DriverStrings.hotspotsWaze),
              onTap: () => Navigator.pop(ctx, DriverNavApp.waze),
            ),
          ],
        ),
      ),
    );
    if (choice == null) return;
    await launchPreferred(lat: lat, lng: lng, app: choice);
  }
}
