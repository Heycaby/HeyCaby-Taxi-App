import 'package:flutter/widgets.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

/// Lucide-based icons for a consistent, modern stroke UI across the driver app.
/// Prefer importing symbols from here instead of raw [Icons.*] where possible.
abstract final class AppIcons {
  // —— Bottom navigation ——
  static const IconData navHome = LucideIcons.mapPin;
  static const IconData navWork = LucideIcons.briefcase;
  static const IconData navCommunity = LucideIcons.messagesSquare;
  /// Distinct from [navProfile]; reads as “share / invite” in the bottom bar.
  static const IconData navTellFriend = LucideIcons.usersRound;
  static const IconData navProfile = LucideIcons.userRound;

  // —— Shell / drawer ——
  static const IconData menuProfile = LucideIcons.userRound;
  static const IconData menuDocuments = LucideIcons.fileText;
  static const IconData menuSupport = LucideIcons.lifeBuoy;
  static const IconData menuSettings = LucideIcons.settings2;
  static const IconData menuLogout = LucideIcons.logOut;

  // —— Map & hub ——
  static const IconData mapRecenter = LucideIcons.locateFixed;
  static const IconData hubGrid = LucideIcons.layoutGrid;

  // —— Home sheet ——
  static const IconData calendar = LucideIcons.calendar;
  static const IconData chevronRight = LucideIcons.chevronRight;
  static const IconData chevronLeft = LucideIcons.chevronLeft;
  static const IconData arrowBack = LucideIcons.arrowLeft;
  static const IconData star = LucideIcons.star;
  static const IconData starOff = LucideIcons.starOff;

  // —— Community ——
  static const IconData megaphone = LucideIcons.megaphone;
  static const IconData messages = LucideIcons.messagesSquare;
  static const IconData swapHorizontal = LucideIcons.arrowLeftRight;
  static const IconData editPost = LucideIcons.squarePen;

  // —— Profile / settings rows ——
  static const IconData carFront = LucideIcons.carFront;
  static const IconData carOutline = LucideIcons.car;
  static const IconData tune = LucideIcons.slidersHorizontal;
  static const IconData chat = LucideIcons.messageCircle;
  static const IconData article = LucideIcons.newspaper;
  static const IconData verified = LucideIcons.badgeCheck;
  static const IconData person = LucideIcons.userRound;

  // —— Hub ——
  static const IconData emergency = LucideIcons.siren;
  static const IconData share = LucideIcons.share2;
  static const IconData audio = LucideIcons.audioLines;
  static const IconData bolt = LucideIcons.zap;
  static const IconData groups = LucideIcons.usersRound;

  // —— Misc ——
  static const IconData bellRing = LucideIcons.bellRing;
  static const IconData circle = LucideIcons.circle;

  // —— Preferences ——
  static const IconData backIos = LucideIcons.chevronLeft;
  static const IconData radar = LucideIcons.radar;
  static const IconData payments = LucideIcons.banknote;
  static const IconData wallet = LucideIcons.wallet;
  static const IconData dog = LucideIcons.dog;
  static const IconData accessibility = LucideIcons.accessibility;
  static const IconData globe = LucideIcons.globe;
  static const IconData palette = LucideIcons.palette;
  static const IconData checkCircle = LucideIcons.circleCheck;
  static const IconData check = LucideIcons.check;
  static const IconData mapPinOff = LucideIcons.mapPinOff;
}
