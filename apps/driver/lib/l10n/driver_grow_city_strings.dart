import 'package:flutter/material.dart';

/// Grow Your City hub copy — driver app (invite fellow drivers, transparency stats).
class DriverGrowCityStrings {
  const DriverGrowCityStrings({
    required this.screenTitle,
    required this.heroTitle,
    required this.heroBody1,
    required this.heroBody2,
    required this.heroMission,
    required this.communityTitle,
    required this.driversLabel,
    required this.ridersLabel,
    required this.monthlyRidersLabel,
    required this.monthlyDriversLabel,
    required this.milestoneLabel,
    required this.progressCount,
    required this.milestoneHint,
    required this.finalGoalReached,
    required this.milestoneCelebrationTitle,
    required this.milestoneCelebrationBody,
    required this.milestoneCelebrationCta,
    required this.impactTitle,
    required this.peopleInvited,
    required this.joined,
    required this.completedRides,
    required this.badgesTitle,
    required this.badgeSupporter,
    required this.badgeBuilder,
    required this.badgeAmbassador,
    required this.badgeTopPromoter,
    required this.sharePrompt,
    required this.shareLink,
    required this.copyLink,
    required this.inviteLinkLabel,
    required this.linkCopied,
    required this.shareSubject,
    required this.shareMessage,
    required this.shareDoneSnackbar,
    required this.linkUnavailable,
    required this.linkUnavailableHint,
    required this.whyHelpTitle,
    required this.whyHelpBullet1,
    required this.whyHelpBullet2,
    required this.whyHelpBullet3,
    required this.whyHelpBullet4,
    required this.socialProof,
  });

  final String screenTitle;
  final String Function(String regionName) heroTitle;
  final String heroBody1;
  final String heroBody2;
  final String heroMission;
  final String Function(String regionName) communityTitle;
  final String driversLabel;
  final String ridersLabel;
  final String monthlyRidersLabel;
  final String monthlyDriversLabel;
  final String milestoneLabel;
  final String Function(String current, String milestone) progressCount;
  final String Function(String remaining, String milestone) milestoneHint;
  final String finalGoalReached;
  final String milestoneCelebrationTitle;
  final String Function(String milestone) milestoneCelebrationBody;
  final String milestoneCelebrationCta;
  final String impactTitle;
  final String peopleInvited;
  final String joined;
  final String completedRides;
  final String badgesTitle;
  final String badgeSupporter;
  final String badgeBuilder;
  final String badgeAmbassador;
  final String badgeTopPromoter;
  final String sharePrompt;
  final String shareLink;
  final String copyLink;
  final String inviteLinkLabel;
  final String linkCopied;
  final String shareSubject;
  final String shareMessage;
  final String shareDoneSnackbar;
  final String linkUnavailable;
  final String linkUnavailableHint;
  final String whyHelpTitle;
  final String whyHelpBullet1;
  final String whyHelpBullet2;
  final String whyHelpBullet3;
  final String whyHelpBullet4;
  final String socialProof;
}

final _en = DriverGrowCityStrings(
  screenTitle: 'Grow Your City',
  heroTitle: (region) => 'Grow HeyCaby in $region',
  heroBody1:
      'Invite fellow taxi drivers you trust to join the independent HeyCaby network.',
  heroBody2:
      'More drivers on the platform means shorter waits for riders and more ride opportunities for you.',
  heroMission:
      'Help us build the largest independent taxi network in the Netherlands.',
  communityTitle: (region) => '$region community',
  driversLabel: 'Drivers',
  ridersLabel: 'Riders',
  monthlyRidersLabel: 'Monthly riders',
  monthlyDriversLabel: 'Monthly drivers',
  milestoneLabel: 'Next milestone',
  progressCount: (current, milestone) => '$current / $milestone',
  milestoneHint: (remaining, milestone) =>
      '$remaining monthly riders until we celebrate $milestone.',
  finalGoalReached:
      'We reached 1 million monthly riders in the Netherlands. Thank you for growing HeyCaby with us.',
  milestoneCelebrationTitle: 'Milestone reached!',
  milestoneCelebrationBody: (milestone) =>
      'The HeyCaby community just hit $milestone monthly riders in the Netherlands. Thank you for helping us grow — on to the next milestone!',
  milestoneCelebrationCta: 'Let\'s keep growing',
  impactTitle: 'Your impact',
  peopleInvited: 'Drivers invited',
  joined: 'Joined',
  completedRides: 'Completed rides',
  badgesTitle: 'Community badges',
  badgeSupporter: 'Community Supporter',
  badgeBuilder: 'Community Builder',
  badgeAmbassador: 'City Ambassador',
  badgeTopPromoter: 'Top Promoter',
  sharePrompt:
      'Share HeyCaby Driver with taxi colleagues in your city. Every new driver strengthens the network.',
  shareLink: 'Share HeyCaby',
  copyLink: 'Copy link',
  inviteLinkLabel: 'App Store link',
  linkCopied: 'Link copied',
  shareSubject: 'Download HeyCaby Driver',
  shareMessage:
      'Download HeyCaby Driver — join the independent taxi network in the Netherlands:',
  shareDoneSnackbar: 'Thanks for sharing HeyCaby!',
  linkUnavailable: 'App Store link not configured',
  linkUnavailableHint:
      'Add DRIVER_IOS_APP_STORE_URL to your build environment, then rebuild the app.',
  whyHelpTitle: 'Why help?',
  whyHelpBullet1: 'More drivers in your city',
  whyHelpBullet2: 'More ride requests for everyone',
  whyHelpBullet3: 'Shorter waiting times for riders',
  whyHelpBullet4: 'Stronger independent taxi community',
  socialProof:
      'Thanks for helping build the largest independent taxi network in the Netherlands.',
);

final _nl = DriverGrowCityStrings(
  screenTitle: 'Groei je stad',
  heroTitle: (region) => 'Laat HeyCaby groeien in $region',
  heroBody1:
      'Nodig taxichauffeurs uit die je vertrouwt om mee te doen aan het onafhankelijke HeyCaby-netwerk.',
  heroBody2:
      'Meer chauffeurs op het platform betekent kortere wachttijden voor passagiers en meer ritkansen voor jou.',
  heroMission:
      'Help ons het grootste onafhankelijke taxinetwerk van Nederland te bouwen.',
  communityTitle: (region) => '$region-gemeenschap',
  driversLabel: 'Chauffeurs',
  ridersLabel: 'Passagiers',
  monthlyRidersLabel: 'Maandelijkse passagiers',
  monthlyDriversLabel: 'Maandelijkse chauffeurs',
  milestoneLabel: 'Volgende mijlpaal',
  progressCount: (current, milestone) => '$current / $milestone',
  milestoneHint: (remaining, milestone) =>
      'Nog $remaining maandelijkse passagiers tot we $milestone vieren.',
  finalGoalReached:
      'We hebben 1 miljoen maandelijkse passagiers in Nederland bereikt. Bedankt dat je HeyCaby met ons laat groeien.',
  milestoneCelebrationTitle: 'Mijlpaal bereikt!',
  milestoneCelebrationBody: (milestone) =>
      'De HeyCaby-community heeft $milestone maandelijkse passagiers in Nederland bereikt. Bedankt voor je hulp — door naar de volgende mijlpaal!',
  milestoneCelebrationCta: 'Laten we doorgroeien',
  impactTitle: 'Jouw impact',
  peopleInvited: 'Chauffeurs uitgenodigd',
  joined: 'Aangemeld',
  completedRides: 'Voltooide ritten',
  badgesTitle: 'Community-badges',
  badgeSupporter: 'Community Supporter',
  badgeBuilder: 'Community Builder',
  badgeAmbassador: 'Stadsambassadeur',
  badgeTopPromoter: 'Top Promoter',
  sharePrompt:
      'Deel HeyCaby Driver met taxicollega\'s in jouw stad. Elke nieuwe chauffeur versterkt het netwerk.',
  shareLink: 'Deel HeyCaby',
  copyLink: 'Link kopiëren',
  inviteLinkLabel: 'App Store-link',
  linkCopied: 'Link gekopieerd',
  shareSubject: 'Download HeyCaby Driver',
  shareMessage:
      'Download HeyCaby Driver — sluit je aan bij het onafhankelijke taxinetwerk in Nederland:',
  shareDoneSnackbar: 'Bedankt voor het delen van HeyCaby!',
  linkUnavailable: 'App Store-link niet geconfigureerd',
  linkUnavailableHint:
      'Voeg DRIVER_IOS_APP_STORE_URL toe aan je build-omgeving en bouw de app opnieuw.',
  whyHelpTitle: 'Waarom helpen?',
  whyHelpBullet1: 'Meer chauffeurs in jouw stad',
  whyHelpBullet2: 'Meer ritverzoeken voor iedereen',
  whyHelpBullet3: 'Kortere wachttijden voor passagiers',
  whyHelpBullet4: 'Sterkere onafhankelijke taxigemeenschap',
  socialProof:
      'Bedankt dat je helpt het grootste onafhankelijke taxinetwerk van Nederland te bouwen.',
);

DriverGrowCityStrings driverGrowCityStringsFor(Locale? locale) {
  final code = locale?.languageCode ?? 'nl';
  if (code == 'en') return _en;
  if (code == 'nl') return _nl;
  return _en;
}
