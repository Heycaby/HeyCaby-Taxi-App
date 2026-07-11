import 'dart:io' show Platform;

import 'package:url_launcher/url_launcher.dart';

final kTikkieAppUri = Uri.parse('tikkie://');
const kTikkieIosStoreUrl =
    'https://apps.apple.com/nl/app/tikkie/id1090997487';
const kTikkieAndroidStoreUrl =
    'https://play.google.com/store/apps/details?id=com.abnamro.nl.tikkie';

/// Deep link to Tikkie app, or store if not installed.
Future<bool> openTikkieApp() async {
  if (await canLaunchUrl(kTikkieAppUri)) {
    return launchUrl(kTikkieAppUri, mode: LaunchMode.externalApplication);
  }
  final storeUrl = Uri.parse(
    Platform.isIOS ? kTikkieIosStoreUrl : kTikkieAndroidStoreUrl,
  );
  return launchUrl(storeUrl, mode: LaunchMode.externalApplication);
}

Future<bool> isTikkieAppInstalled() => canLaunchUrl(kTikkieAppUri);
