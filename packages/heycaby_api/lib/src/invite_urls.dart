import 'package:heycaby_api/src/app_public_links.dart';

/// Rider Grow / invite share & copy — server-driven ([AppPublicLinks.riderInviteShareUrl]).
String get riderInviteShareUrl => appPublicLinks.current.riderInviteShareUrl();

/// Driver Grow / invite share & copy — server-driven ([AppPublicLinks.driverInviteShareUrl]).
String get driverInviteShareUrl => appPublicLinks.current.driverInviteShareUrl();

/// QR payload for rider invite (same URL as share).
String get riderInviteQrUrl => riderInviteShareUrl;

/// QR payload for driver invite (same URL as share).
String get driverInviteQrUrl => driverInviteShareUrl;
