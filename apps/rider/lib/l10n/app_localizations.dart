import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';
import 'app_localizations_nl.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('nl'),
    Locale('ar')
  ];

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'HeyCaby'**
  String get appName;

  /// No description provided for @hello.
  ///
  /// In en, this message translates to:
  /// **'Hello'**
  String get hello;

  /// No description provided for @rider.
  ///
  /// In en, this message translates to:
  /// **'Rider'**
  String get rider;

  /// No description provided for @tagline.
  ///
  /// In en, this message translates to:
  /// **'Connect with taxi drivers in your neighborhood.'**
  String get tagline;

  /// No description provided for @continueButton.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueButton;

  /// No description provided for @bookRide.
  ///
  /// In en, this message translates to:
  /// **'Book a ride'**
  String get bookRide;

  /// No description provided for @whereAreYouGoing.
  ///
  /// In en, this message translates to:
  /// **'Where are you going?'**
  String get whereAreYouGoing;

  /// No description provided for @searchScheduleHint.
  ///
  /// In en, this message translates to:
  /// **'Now, or pick a date & time'**
  String get searchScheduleHint;

  /// No description provided for @searchStartTypingHint.
  ///
  /// In en, this message translates to:
  /// **'Type at least 3 characters to search the map.'**
  String get searchStartTypingHint;

  /// No description provided for @searchBrowseSavedPlaces.
  ///
  /// In en, this message translates to:
  /// **'Browse all saved places'**
  String get searchBrowseSavedPlaces;

  /// No description provided for @searchBrowseRecentPlaces.
  ///
  /// In en, this message translates to:
  /// **'Browse recent'**
  String get searchBrowseRecentPlaces;

  /// No description provided for @searchRecentOnDeviceSection.
  ///
  /// In en, this message translates to:
  /// **'Recent on this device'**
  String get searchRecentOnDeviceSection;

  /// No description provided for @searchRecentOnDeviceSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Last 10 places you used on this phone — separate from saved places.'**
  String get searchRecentOnDeviceSubtitle;

  /// No description provided for @searchNoLocalRecentsYet.
  ///
  /// In en, this message translates to:
  /// **'No recent addresses yet. Search for a place and select it — we keep the last 10 here so the next search can be faster.'**
  String get searchNoLocalRecentsYet;

  /// No description provided for @searchLocalMatchesHeader.
  ///
  /// In en, this message translates to:
  /// **'Matches on this device'**
  String get searchLocalMatchesHeader;

  /// No description provided for @whereTo.
  ///
  /// In en, this message translates to:
  /// **'Where to?'**
  String get whereTo;

  /// No description provided for @pickup.
  ///
  /// In en, this message translates to:
  /// **'Pickup'**
  String get pickup;

  /// No description provided for @destination.
  ///
  /// In en, this message translates to:
  /// **'Destination'**
  String get destination;

  /// No description provided for @findMyDriver.
  ///
  /// In en, this message translates to:
  /// **'Find my driver'**
  String get findMyDriver;

  /// No description provided for @searching.
  ///
  /// In en, this message translates to:
  /// **'Searching for a driver...'**
  String get searching;

  /// No description provided for @driverAssigned.
  ///
  /// In en, this message translates to:
  /// **'Driver on the way'**
  String get driverAssigned;

  /// No description provided for @driverReturnTripDiscount.
  ///
  /// In en, this message translates to:
  /// **'{pct}% return ride discount'**
  String driverReturnTripDiscount(int pct);

  /// No description provided for @driverArrived.
  ///
  /// In en, this message translates to:
  /// **'Your driver has arrived'**
  String get driverArrived;

  /// No description provided for @tripInProgress.
  ///
  /// In en, this message translates to:
  /// **'Trip in progress'**
  String get tripInProgress;

  /// No description provided for @tripComplete.
  ///
  /// In en, this message translates to:
  /// **'Trip complete'**
  String get tripComplete;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// No description provided for @confirmDestination.
  ///
  /// In en, this message translates to:
  /// **'Confirm destination'**
  String get confirmDestination;

  /// No description provided for @rateYourDriver.
  ///
  /// In en, this message translates to:
  /// **'Rate your driver'**
  String get rateYourDriver;

  /// No description provided for @howWasYourRide.
  ///
  /// In en, this message translates to:
  /// **'How was your ride?'**
  String get howWasYourRide;

  /// No description provided for @whatDidYouLike.
  ///
  /// In en, this message translates to:
  /// **'What did you like?'**
  String get whatDidYouLike;

  /// No description provided for @additionalFeedback.
  ///
  /// In en, this message translates to:
  /// **'Additional feedback (optional)'**
  String get additionalFeedback;

  /// No description provided for @tellUsMore.
  ///
  /// In en, this message translates to:
  /// **'Tell us more about your experience...'**
  String get tellUsMore;

  /// No description provided for @submitRating.
  ///
  /// In en, this message translates to:
  /// **'Submit Rating'**
  String get submitRating;

  /// No description provided for @ratingCategorySectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Rate specific areas'**
  String get ratingCategorySectionTitle;

  /// No description provided for @ratingCategorySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Each area uses 1–5 stars. They start matching your overall rating — adjust any that differ.'**
  String get ratingCategorySubtitle;

  /// No description provided for @ratingDimensionPunctuality.
  ///
  /// In en, this message translates to:
  /// **'Punctuality'**
  String get ratingDimensionPunctuality;

  /// No description provided for @ratingDimensionCleanliness.
  ///
  /// In en, this message translates to:
  /// **'Cleanliness'**
  String get ratingDimensionCleanliness;

  /// No description provided for @ratingDimensionAttitude.
  ///
  /// In en, this message translates to:
  /// **'Attitude'**
  String get ratingDimensionAttitude;

  /// No description provided for @ratingDimensionDrivingSafety.
  ///
  /// In en, this message translates to:
  /// **'Driving safety'**
  String get ratingDimensionDrivingSafety;

  /// No description provided for @ratingDimensionCommunication.
  ///
  /// In en, this message translates to:
  /// **'Communication'**
  String get ratingDimensionCommunication;

  /// No description provided for @recentDestinations.
  ///
  /// In en, this message translates to:
  /// **'Recent Destinations'**
  String get recentDestinations;

  /// No description provided for @recentDestinationsShowMore.
  ///
  /// In en, this message translates to:
  /// **'Show {count} more'**
  String recentDestinationsShowMore(int count);

  /// No description provided for @recentDestinationsShowLess.
  ///
  /// In en, this message translates to:
  /// **'Show less'**
  String get recentDestinationsShowLess;

  /// No description provided for @recentDestinationRemoveHint.
  ///
  /// In en, this message translates to:
  /// **'Remove from recents'**
  String get recentDestinationRemoveHint;

  /// No description provided for @recentDestinationRemoveFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t remove this place. Try again.'**
  String get recentDestinationRemoveFailed;

  /// No description provided for @whatWentWrong.
  ///
  /// In en, this message translates to:
  /// **'What went wrong?'**
  String get whatWentWrong;

  /// No description provided for @helpUsUnderstand.
  ///
  /// In en, this message translates to:
  /// **'Help us understand the issue so we can improve'**
  String get helpUsUnderstand;

  /// No description provided for @additionalDetails.
  ///
  /// In en, this message translates to:
  /// **'Additional details'**
  String get additionalDetails;

  /// No description provided for @pleaseProvideMoreDetails.
  ///
  /// In en, this message translates to:
  /// **'Please provide more details about the issue...'**
  String get pleaseProvideMoreDetails;

  /// No description provided for @submitReport.
  ///
  /// In en, this message translates to:
  /// **'Submit Report'**
  String get submitReport;

  /// No description provided for @reportSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Report submitted successfully'**
  String get reportSubmitted;

  /// No description provided for @reportSubmitFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to submit report'**
  String get reportSubmitFailed;

  /// No description provided for @fareEstimate.
  ///
  /// In en, this message translates to:
  /// **'Estimated fare'**
  String get fareEstimate;

  /// No description provided for @scheduledFor.
  ///
  /// In en, this message translates to:
  /// **'Scheduled for {date}'**
  String scheduledFor(String date);

  /// No description provided for @noDriversNearby.
  ///
  /// In en, this message translates to:
  /// **'No drivers nearby'**
  String get noDriversNearby;

  /// No description provided for @connectionProblem.
  ///
  /// In en, this message translates to:
  /// **'Connection problem. Please try again.'**
  String get connectionProblem;

  /// No description provided for @rideBookingFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t start your ride — authorization was rejected by the server. Please refresh your session (log out and log in), then try Find driver again.'**
  String get rideBookingFailed;

  /// No description provided for @locationPermissionRequired.
  ///
  /// In en, this message translates to:
  /// **'Location access is needed to set pickup and find nearby drivers.'**
  String get locationPermissionRequired;

  /// No description provided for @locationRequired.
  ///
  /// In en, this message translates to:
  /// **'Location required'**
  String get locationRequired;

  /// No description provided for @locationRequiredMessage.
  ///
  /// In en, this message translates to:
  /// **'HeyCaby needs your location to set accurate pickup points, find nearby drivers, and give reliable arrival times. Without location access we cannot serve you well and you cannot book rides.'**
  String get locationRequiredMessage;

  /// No description provided for @enableLocation.
  ///
  /// In en, this message translates to:
  /// **'Enable Location'**
  String get enableLocation;

  /// No description provided for @tryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get tryAgain;

  /// No description provided for @enterAddressManually.
  ///
  /// In en, this message translates to:
  /// **'Enter address manually'**
  String get enterAddressManually;

  /// No description provided for @home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// No description provided for @rides.
  ///
  /// In en, this message translates to:
  /// **'Rides'**
  String get rides;

  /// No description provided for @account.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get account;

  /// No description provided for @tellAFriendNavLabel.
  ///
  /// In en, this message translates to:
  /// **'TAF'**
  String get tellAFriendNavLabel;

  /// No description provided for @tellAFriendNavSemanticLabel.
  ///
  /// In en, this message translates to:
  /// **'Invite friends — grow your ride circle'**
  String get tellAFriendNavSemanticLabel;

  /// No description provided for @tellAFriendScreenTitle.
  ///
  /// In en, this message translates to:
  /// **'Invite friends'**
  String get tellAFriendScreenTitle;

  /// No description provided for @tellAFriendSharePrompt.
  ///
  /// In en, this message translates to:
  /// **'Send your link. Friends join free — you’ll see them here when they sign up.'**
  String get tellAFriendSharePrompt;

  /// No description provided for @tellAFriendHeroTitle.
  ///
  /// In en, this message translates to:
  /// **'Invite friends'**
  String get tellAFriendHeroTitle;

  /// No description provided for @tellAFriendHeroSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Share your link in one tap.'**
  String get tellAFriendHeroSubtitle;

  /// No description provided for @tellAFriendBodyLine1.
  ///
  /// In en, this message translates to:
  /// **'Grow your ride circle nearby.'**
  String get tellAFriendBodyLine1;

  /// No description provided for @tellAFriendBodyLine2.
  ///
  /// In en, this message translates to:
  /// **'More trusted riders can mean quicker matches for everyone.'**
  String get tellAFriendBodyLine2;

  /// No description provided for @tellAFriendFriendsInvitedLabel.
  ///
  /// In en, this message translates to:
  /// **'Friends invited'**
  String get tellAFriendFriendsInvitedLabel;

  /// No description provided for @tellAFriendFriendsInvitedZeroHint.
  ///
  /// In en, this message translates to:
  /// **'No joins yet — share below.'**
  String get tellAFriendFriendsInvitedZeroHint;

  /// No description provided for @tellAFriendRewardTitle.
  ///
  /// In en, this message translates to:
  /// **'Why it helps'**
  String get tellAFriendRewardTitle;

  /// No description provided for @tellAFriendRewardBullet1.
  ///
  /// In en, this message translates to:
  /// **'More riders nearby can speed up matching.'**
  String get tellAFriendRewardBullet1;

  /// No description provided for @tellAFriendRewardBullet2.
  ///
  /// In en, this message translates to:
  /// **'Perks may unlock as your circle grows.'**
  String get tellAFriendRewardBullet2;

  /// No description provided for @tellAFriendRewardBullet3.
  ///
  /// In en, this message translates to:
  /// **'Weekend discounts when available'**
  String get tellAFriendRewardBullet3;

  /// No description provided for @tellAFriendRewardBullet4.
  ///
  /// In en, this message translates to:
  /// **'Helps drivers see demand in your area'**
  String get tellAFriendRewardBullet4;

  /// No description provided for @tellAFriendInviteLinkLabel.
  ///
  /// In en, this message translates to:
  /// **'Your link'**
  String get tellAFriendInviteLinkLabel;

  /// No description provided for @tellAFriendLinkResolving.
  ///
  /// In en, this message translates to:
  /// **'Getting your short invite link…'**
  String get tellAFriendLinkResolving;

  /// No description provided for @tellAFriendCopyLink.
  ///
  /// In en, this message translates to:
  /// **'Copy link'**
  String get tellAFriendCopyLink;

  /// No description provided for @tellAFriendShareLink.
  ///
  /// In en, this message translates to:
  /// **'Share invite'**
  String get tellAFriendShareLink;

  /// No description provided for @tellAFriendShowQr.
  ///
  /// In en, this message translates to:
  /// **'Show QR code'**
  String get tellAFriendShowQr;

  /// No description provided for @tellAFriendQrTitle.
  ///
  /// In en, this message translates to:
  /// **'Scan to join HeyCaby'**
  String get tellAFriendQrTitle;

  /// No description provided for @tellAFriendQrHint.
  ///
  /// In en, this message translates to:
  /// **'Scanning opens heycaby.nl in the browser. Use Share or Copy for your personal invite link.'**
  String get tellAFriendQrHint;

  /// No description provided for @tellAFriendSocialProof.
  ///
  /// In en, this message translates to:
  /// **'Thanks for helping HeyCaby grow locally.'**
  String get tellAFriendSocialProof;

  /// No description provided for @tellAFriendShareDoneSnackbar.
  ///
  /// In en, this message translates to:
  /// **'Invite sent — thanks for spreading the word!'**
  String get tellAFriendShareDoneSnackbar;

  /// No description provided for @tellAFriendLinkCopied.
  ///
  /// In en, this message translates to:
  /// **'Copied — ready to paste anywhere'**
  String get tellAFriendLinkCopied;

  /// No description provided for @tellAFriendShareSubject.
  ///
  /// In en, this message translates to:
  /// **'Join me on HeyCaby'**
  String get tellAFriendShareSubject;

  /// No description provided for @tellAFriendShareMessage.
  ///
  /// In en, this message translates to:
  /// **'I\'m building my ride circle on HeyCaby — want in? Tap my invite:'**
  String get tellAFriendShareMessage;

  /// No description provided for @tellAFriendLinkUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Link not ready yet'**
  String get tellAFriendLinkUnavailable;

  /// No description provided for @tellAFriendLinkUnavailableHint.
  ///
  /// In en, this message translates to:
  /// **'Open this screen again in a moment, or restart the app.'**
  String get tellAFriendLinkUnavailableHint;

  /// No description provided for @iosUpdateRequiredTitle.
  ///
  /// In en, this message translates to:
  /// **'Please update iOS'**
  String get iosUpdateRequiredTitle;

  /// No description provided for @iosUpdateRequiredBody.
  ///
  /// In en, this message translates to:
  /// **'HeyCaby requires iOS {minimumVersion} or later. This iPhone is on iOS {currentVersion}. Open Settings → General → Software Update to install the latest iOS your device supports.'**
  String iosUpdateRequiredBody(String minimumVersion, String currentVersion);

  /// No description provided for @iosUpdateRequiredFooter.
  ///
  /// In en, this message translates to:
  /// **'If your device cannot upgrade to iOS {minimumVersion}, you will need a newer iPhone to use HeyCaby.'**
  String iosUpdateRequiredFooter(String minimumVersion);

  /// No description provided for @scheduledCommitmentDisclosure.
  ///
  /// In en, this message translates to:
  /// **'Your driver may ask for a small confirmation contribution of up to €5 up to 40 minutes before your ride. It is deducted from your trip total. If you or the driver cancel afterward, the usual cancellation rules apply.'**
  String get scheduledCommitmentDisclosure;

  /// No description provided for @prerideBannerTitle.
  ///
  /// In en, this message translates to:
  /// **'Please confirm your ride'**
  String get prerideBannerTitle;

  /// No description provided for @prerideBannerSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your driver is waiting for confirmation before pickup.'**
  String get prerideBannerSubtitle;

  /// No description provided for @prerideOpenTikkie.
  ///
  /// In en, this message translates to:
  /// **'Open Tikkie'**
  String get prerideOpenTikkie;

  /// No description provided for @prerideConfirmAttending.
  ///
  /// In en, this message translates to:
  /// **'I\'m coming'**
  String get prerideConfirmAttending;

  /// No description provided for @prerideConfirmedThanks.
  ///
  /// In en, this message translates to:
  /// **'Thanks — you\'re confirmed.'**
  String get prerideConfirmedThanks;

  /// No description provided for @myRides.
  ///
  /// In en, this message translates to:
  /// **'My rides'**
  String get myRides;

  /// No description provided for @favouriteDrivers.
  ///
  /// In en, this message translates to:
  /// **'Favourite drivers'**
  String get favouriteDrivers;

  /// No description provided for @favouriteDriversSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Book a driver you trust'**
  String get favouriteDriversSubtitle;

  /// No description provided for @favouriteDriversSubtitleWithCount.
  ///
  /// In en, this message translates to:
  /// **'{count} favourite drivers'**
  String favouriteDriversSubtitleWithCount(int count);

  /// No description provided for @noFavouritesYet.
  ///
  /// In en, this message translates to:
  /// **'No favourites yet'**
  String get noFavouritesYet;

  /// No description provided for @paymentMethod.
  ///
  /// In en, this message translates to:
  /// **'Payment method'**
  String get paymentMethod;

  /// No description provided for @cash.
  ///
  /// In en, this message translates to:
  /// **'Cash'**
  String get cash;

  /// No description provided for @pin.
  ///
  /// In en, this message translates to:
  /// **'PIN'**
  String get pin;

  /// No description provided for @tikkie.
  ///
  /// In en, this message translates to:
  /// **'Tikkie'**
  String get tikkie;

  /// No description provided for @instantRide.
  ///
  /// In en, this message translates to:
  /// **'Instant'**
  String get instantRide;

  /// No description provided for @scheduledRide.
  ///
  /// In en, this message translates to:
  /// **'Schedule'**
  String get scheduledRide;

  /// No description provided for @marketplace.
  ///
  /// In en, this message translates to:
  /// **'Marketplace'**
  String get marketplace;

  /// No description provided for @marketplaceSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Drivers heading your way — save up to 40%'**
  String get marketplaceSubtitle;

  /// No description provided for @homeAirportBookingTitle.
  ///
  /// In en, this message translates to:
  /// **'Airport drop-off'**
  String get homeAirportBookingTitle;

  /// No description provided for @homeAirportBookingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Schiphol, Brussels, Luxembourg & more — one tap'**
  String get homeAirportBookingSubtitle;

  /// No description provided for @homeAirportBookingBadge.
  ///
  /// In en, this message translates to:
  /// **'Fast'**
  String get homeAirportBookingBadge;

  /// No description provided for @airportBookingScreenTitle.
  ///
  /// In en, this message translates to:
  /// **'Airport drop-off'**
  String get airportBookingScreenTitle;

  /// No description provided for @airportBookingScreenSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose your terminal. Pickup stays your current location unless you change it in the next step.'**
  String get airportBookingScreenSubtitle;

  /// No description provided for @airportBookingSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search by airport, city, or code'**
  String get airportBookingSearchHint;

  /// No description provided for @airportBookingNoResults.
  ///
  /// In en, this message translates to:
  /// **'No airport matches that search.'**
  String get airportBookingNoResults;

  /// No description provided for @airportSectionNetherlands.
  ///
  /// In en, this message translates to:
  /// **'NETHERLANDS'**
  String get airportSectionNetherlands;

  /// No description provided for @airportSectionBelgium.
  ///
  /// In en, this message translates to:
  /// **'BELGIUM'**
  String get airportSectionBelgium;

  /// No description provided for @airportSectionLuxembourg.
  ///
  /// In en, this message translates to:
  /// **'LUXEMBOURG'**
  String get airportSectionLuxembourg;

  /// No description provided for @favouritesOnly.
  ///
  /// In en, this message translates to:
  /// **'Favorite drivers first'**
  String get favouritesOnly;

  /// No description provided for @offerFare.
  ///
  /// In en, this message translates to:
  /// **'Offer your fare'**
  String get offerFare;

  /// No description provided for @bids.
  ///
  /// In en, this message translates to:
  /// **'Bids'**
  String get bids;

  /// No description provided for @acceptBid.
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get acceptBid;

  /// No description provided for @notifyMe.
  ///
  /// In en, this message translates to:
  /// **'Notify me when available'**
  String get notifyMe;

  /// No description provided for @rideHistory.
  ///
  /// In en, this message translates to:
  /// **'Ride history'**
  String get rideHistory;

  /// No description provided for @reportDriver.
  ///
  /// In en, this message translates to:
  /// **'Report driver'**
  String get reportDriver;

  /// No description provided for @support.
  ///
  /// In en, this message translates to:
  /// **'Support'**
  String get support;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @theme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get theme;

  /// No description provided for @homeAddress.
  ///
  /// In en, this message translates to:
  /// **'Home address'**
  String get homeAddress;

  /// No description provided for @savedAddresses.
  ///
  /// In en, this message translates to:
  /// **'Saved places'**
  String get savedAddresses;

  /// No description provided for @logout.
  ///
  /// In en, this message translates to:
  /// **'Log out'**
  String get logout;

  /// No description provided for @distance.
  ///
  /// In en, this message translates to:
  /// **'{km} km'**
  String distance(String km);

  /// No description provided for @duration.
  ///
  /// In en, this message translates to:
  /// **'{min} min'**
  String duration(String min);

  /// No description provided for @bestPrice.
  ///
  /// In en, this message translates to:
  /// **'Best price'**
  String get bestPrice;

  /// No description provided for @howHeyCabyWorks.
  ///
  /// In en, this message translates to:
  /// **'How HeyCaby works'**
  String get howHeyCabyWorks;

  /// No description provided for @zeroCommission.
  ///
  /// In en, this message translates to:
  /// **'Zero commission — fair for everyone'**
  String get zeroCommission;

  /// No description provided for @driverEarns100.
  ///
  /// In en, this message translates to:
  /// **'Your driver earns 100% of the fare'**
  String get driverEarns100;

  /// No description provided for @noShowWarning.
  ///
  /// In en, this message translates to:
  /// **'Please only book when you\'re ready at your location'**
  String get noShowWarning;

  /// No description provided for @communityPledge.
  ///
  /// In en, this message translates to:
  /// **'Only book when you\'re ready and at your location. Our drivers pay for fuel on every call-out.'**
  String get communityPledge;

  /// No description provided for @namePlaceholder.
  ///
  /// In en, this message translates to:
  /// **'What should the driver call you?'**
  String get namePlaceholder;

  /// No description provided for @welcomeProfileModalTitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome to HeyCaby!'**
  String get welcomeProfileModalTitle;

  /// No description provided for @welcomeProfileModalBody.
  ///
  /// In en, this message translates to:
  /// **'To make your journey easy and fast, we recommend setting up your profile. It\'ll make booking much faster.'**
  String get welcomeProfileModalBody;

  /// No description provided for @setUpProfileNow.
  ///
  /// In en, this message translates to:
  /// **'Set up now'**
  String get setUpProfileNow;

  /// No description provided for @welcomeDriverCallYouModalTitle.
  ///
  /// In en, this message translates to:
  /// **'What should the driver call you?'**
  String get welcomeDriverCallYouModalTitle;

  /// No description provided for @welcomeSkipDriverName.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get welcomeSkipDriverName;

  /// No description provided for @onboardingProfileBannerMessage.
  ///
  /// In en, this message translates to:
  /// **'Complete your profile to make booking faster.'**
  String get onboardingProfileBannerMessage;

  /// No description provided for @saveAndContinue.
  ///
  /// In en, this message translates to:
  /// **'Save & continue'**
  String get saveAndContinue;

  /// No description provided for @onboardingNextAddEmail.
  ///
  /// In en, this message translates to:
  /// **'Next: add your email to save addresses and favourites.'**
  String get onboardingNextAddEmail;

  /// No description provided for @onboardingNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter your name to continue.'**
  String get onboardingNameRequired;

  /// No description provided for @riderProfileCompletionPercent.
  ///
  /// In en, this message translates to:
  /// **'Profile {percent}% complete'**
  String riderProfileCompletionPercent(String percent);

  /// No description provided for @riderProfileCompleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Profile complete'**
  String get riderProfileCompleteTitle;

  /// No description provided for @riderProfileMeterName.
  ///
  /// In en, this message translates to:
  /// **'Booking name'**
  String get riderProfileMeterName;

  /// No description provided for @riderProfileMeterEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get riderProfileMeterEmail;

  /// No description provided for @riderProfileHomeNudgeTitle.
  ///
  /// In en, this message translates to:
  /// **'Finish your profile'**
  String get riderProfileHomeNudgeTitle;

  /// No description provided for @riderProfileHomeNudgeBoth.
  ///
  /// In en, this message translates to:
  /// **'Add your name and email on Account — each counts for 50%.'**
  String get riderProfileHomeNudgeBoth;

  /// No description provided for @riderProfileHomeNudgeNameOnly.
  ///
  /// In en, this message translates to:
  /// **'Add your booking name on Account to reach 100%.'**
  String get riderProfileHomeNudgeNameOnly;

  /// No description provided for @riderProfileHomeNudgeEmailOnly.
  ///
  /// In en, this message translates to:
  /// **'Add your email on Account to reach 100%.'**
  String get riderProfileHomeNudgeEmailOnly;

  /// No description provided for @yourRoute.
  ///
  /// In en, this message translates to:
  /// **'Your route'**
  String get yourRoute;

  /// No description provided for @howDoYouWantToBook.
  ///
  /// In en, this message translates to:
  /// **'How do you want to book?'**
  String get howDoYouWantToBook;

  /// No description provided for @howWillYouPay.
  ///
  /// In en, this message translates to:
  /// **'How will you pay?'**
  String get howWillYouPay;

  /// No description provided for @laterButton.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get laterButton;

  /// No description provided for @tripSummary.
  ///
  /// In en, this message translates to:
  /// **'Trip summary'**
  String get tripSummary;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get loading;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @error.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get error;

  /// No description provided for @driverOnTheWay.
  ///
  /// In en, this message translates to:
  /// **'Driver on the way'**
  String get driverOnTheWay;

  /// No description provided for @eta.
  ///
  /// In en, this message translates to:
  /// **'ETA {min} min'**
  String eta(String min);

  /// No description provided for @shareRide.
  ///
  /// In en, this message translates to:
  /// **'Share ride'**
  String get shareRide;

  /// No description provided for @chat.
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get chat;

  /// No description provided for @reportIssue.
  ///
  /// In en, this message translates to:
  /// **'Report issue'**
  String get reportIssue;

  /// No description provided for @rideComplete.
  ///
  /// In en, this message translates to:
  /// **'Ride complete'**
  String get rideComplete;

  /// No description provided for @leaveAComment.
  ///
  /// In en, this message translates to:
  /// **'Leave a comment (optional)'**
  String get leaveAComment;

  /// No description provided for @submit.
  ///
  /// In en, this message translates to:
  /// **'Submit'**
  String get submit;

  /// No description provided for @skip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get skip;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @next.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// No description provided for @notifyMeWhenDriverFound.
  ///
  /// In en, this message translates to:
  /// **'You\'ll be notified when a driver is found'**
  String get notifyMeWhenDriverFound;

  /// No description provided for @cancelBookingTitle.
  ///
  /// In en, this message translates to:
  /// **'Cancel booking?'**
  String get cancelBookingTitle;

  /// No description provided for @cancelBookingMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to cancel? Your ride details will be lost.'**
  String get cancelBookingMessage;

  /// No description provided for @keepGoing.
  ///
  /// In en, this message translates to:
  /// **'Keep going'**
  String get keepGoing;

  /// No description provided for @nameSavedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Name saved successfully'**
  String get nameSavedSuccess;

  /// No description provided for @ridesFilterActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get ridesFilterActive;

  /// No description provided for @ridesFilterBidding.
  ///
  /// In en, this message translates to:
  /// **'Bidding'**
  String get ridesFilterBidding;

  /// No description provided for @ridesFilterCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get ridesFilterCompleted;

  /// No description provided for @ridesFilterCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get ridesFilterCancelled;

  /// No description provided for @ridesScreenSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Scheduled trips, live matching, and your history'**
  String get ridesScreenSubtitle;

  /// No description provided for @ridesTabUpcoming.
  ///
  /// In en, this message translates to:
  /// **'Upcoming'**
  String get ridesTabUpcoming;

  /// No description provided for @ridesTabHistory.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get ridesTabHistory;

  /// No description provided for @upcomingRideDetailTitle.
  ///
  /// In en, this message translates to:
  /// **'Trip details'**
  String get upcomingRideDetailTitle;

  /// No description provided for @upcomingRideMatchingProgressTitle.
  ///
  /// In en, this message translates to:
  /// **'Driver search in progress'**
  String get upcomingRideMatchingProgressTitle;

  /// No description provided for @upcomingRideMatchingProgressBody.
  ///
  /// In en, this message translates to:
  /// **'We\'re matching you with nearby drivers. Open the live search screen for the full radar view and live updates.'**
  String get upcomingRideMatchingProgressBody;

  /// No description provided for @upcomingRideOpenLiveSearch.
  ///
  /// In en, this message translates to:
  /// **'Open live search'**
  String get upcomingRideOpenLiveSearch;

  /// No description provided for @upcomingRideEditBookAgain.
  ///
  /// In en, this message translates to:
  /// **'Change addresses'**
  String get upcomingRideEditBookAgain;

  /// No description provided for @upcomingRideEditBookAgainSubtitle.
  ///
  /// In en, this message translates to:
  /// **'This cancels your current request so you can book again with a new pickup or destination.'**
  String get upcomingRideEditBookAgainSubtitle;

  /// No description provided for @upcomingRideGoToActive.
  ///
  /// In en, this message translates to:
  /// **'Go to live ride'**
  String get upcomingRideGoToActive;

  /// No description provided for @upcomingRideDriverSection.
  ///
  /// In en, this message translates to:
  /// **'Driver'**
  String get upcomingRideDriverSection;

  /// No description provided for @ridesUpcomingScheduledBadge.
  ///
  /// In en, this message translates to:
  /// **'Scheduled'**
  String get ridesUpcomingScheduledBadge;

  /// No description provided for @ridesUpcomingMatchingBadge.
  ///
  /// In en, this message translates to:
  /// **'Matching'**
  String get ridesUpcomingMatchingBadge;

  /// No description provided for @ridesUpcomingEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Nothing upcoming'**
  String get ridesUpcomingEmptyTitle;

  /// No description provided for @ridesUpcomingEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Book a ride or schedule one for later — it will show up here while we find your Caby.'**
  String get ridesUpcomingEmptyBody;

  /// No description provided for @ridesHistorySectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Past activity'**
  String get ridesHistorySectionTitle;

  /// No description provided for @searchAddressCouldNotResolve.
  ///
  /// In en, this message translates to:
  /// **'We couldn’t use that address. Try another result or search again.'**
  String get searchAddressCouldNotResolve;

  /// No description provided for @saveBookingForLater.
  ///
  /// In en, this message translates to:
  /// **'Save for later'**
  String get saveBookingForLater;

  /// No description provided for @searchAddressesContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get searchAddressesContinue;

  /// No description provided for @saveTripForNextTimeLabel.
  ///
  /// In en, this message translates to:
  /// **'Save this trip for next time'**
  String get saveTripForNextTimeLabel;

  /// No description provided for @saveTripForNextTimeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Saves pickup and destination to your recent places when you’re signed in.'**
  String get saveTripForNextTimeSubtitle;

  /// No description provided for @scheduledMatchingHeadline.
  ///
  /// In en, this message translates to:
  /// **'We’ll look for a driver for you.'**
  String get scheduledMatchingHeadline;

  /// No description provided for @scheduledMatchingSubhead.
  ///
  /// In en, this message translates to:
  /// **'Drivers can see your scheduled trip and accept it when they’re available.'**
  String get scheduledMatchingSubhead;

  /// No description provided for @matchingAlternativesTitleScheduled.
  ///
  /// In en, this message translates to:
  /// **'Still waiting on a driver. You can try another option.'**
  String get matchingAlternativesTitleScheduled;

  /// No description provided for @matchingTryMarketplace.
  ///
  /// In en, this message translates to:
  /// **'Marketplace'**
  String get matchingTryMarketplace;

  /// No description provided for @matchingAlternativesFabTooltip.
  ///
  /// In en, this message translates to:
  /// **'More options to find a driver'**
  String get matchingAlternativesFabTooltip;

  /// No description provided for @scheduledMatchingBackToHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get scheduledMatchingBackToHome;

  /// No description provided for @scheduledMatchingCancelRide.
  ///
  /// In en, this message translates to:
  /// **'Cancel ride'**
  String get scheduledMatchingCancelRide;

  /// No description provided for @scheduledMatchingMoreMenuTooltip.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get scheduledMatchingMoreMenuTooltip;

  /// No description provided for @scheduledRideDetailsSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'Scheduled trip details'**
  String get scheduledRideDetailsSheetTitle;

  /// No description provided for @marketplaceMatchingBannerTitle.
  ///
  /// In en, this message translates to:
  /// **'Marketplace ride'**
  String get marketplaceMatchingBannerTitle;

  /// No description provided for @marketplaceMatchingBannerBody.
  ///
  /// In en, this message translates to:
  /// **'Drivers can bid on your route. We’ll match you with a Caby as soon as someone accepts.'**
  String get marketplaceMatchingBannerBody;

  /// No description provided for @continueSavedBooking.
  ///
  /// In en, this message translates to:
  /// **'Continue saved booking'**
  String get continueSavedBooking;

  /// No description provided for @continueSavedBookingHint.
  ///
  /// In en, this message translates to:
  /// **'Pick up where you left off.'**
  String get continueSavedBookingHint;

  /// No description provided for @scheduledRideQueuedTitle.
  ///
  /// In en, this message translates to:
  /// **'Ride queued'**
  String get scheduledRideQueuedTitle;

  /// No description provided for @scheduledRideQueuedSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Drivers can see your scheduled trip and accept it. We’ll notify you when someone is assigned.'**
  String get scheduledRideQueuedSubtitle;

  /// No description provided for @scheduledRideQueuedSubtitleWithTime.
  ///
  /// In en, this message translates to:
  /// **'Pickup {when}. Drivers can see your trip and accept it — we’ll notify you when someone is assigned.'**
  String scheduledRideQueuedSubtitleWithTime(String when);

  /// No description provided for @tripSummaryDropoffLabel.
  ///
  /// In en, this message translates to:
  /// **'Drop-off'**
  String get tripSummaryDropoffLabel;

  /// No description provided for @tripSummarySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Review before requesting a driver'**
  String get tripSummarySubtitle;

  /// No description provided for @tripSummaryPassengerRideSection.
  ///
  /// In en, this message translates to:
  /// **'Passenger & ride'**
  String get tripSummaryPassengerRideSection;

  /// No description provided for @tripSummaryPaymentSection.
  ///
  /// In en, this message translates to:
  /// **'Payment'**
  String get tripSummaryPaymentSection;

  /// No description provided for @tripSummaryEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get tripSummaryEdit;

  /// No description provided for @tripSummaryNameNotSet.
  ///
  /// In en, this message translates to:
  /// **'No pickup name yet — add who drivers should ask for'**
  String get tripSummaryNameNotSet;

  /// No description provided for @smartBundleTitle.
  ///
  /// In en, this message translates to:
  /// **'YOUR RIDE CLASSES'**
  String get smartBundleTitle;

  /// No description provided for @smartBundleIncludes.
  ///
  /// In en, this message translates to:
  /// **'Includes: {names}'**
  String smartBundleIncludes(Object names);

  /// No description provided for @smartBundleExpandHint.
  ///
  /// In en, this message translates to:
  /// **'Refine'**
  String get smartBundleExpandHint;

  /// No description provided for @smartBundleTapToExpand.
  ///
  /// In en, this message translates to:
  /// **'Tap to view all ride classes'**
  String get smartBundleTapToExpand;

  /// No description provided for @smartBundleExpandSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Standard, Comfort, taxi bus, wheelchair & prices.'**
  String get smartBundleExpandSubtitle;

  /// No description provided for @smartBundleFootnoteWide.
  ///
  /// In en, this message translates to:
  /// **'More classes selected — you’ll usually match faster. First driver to accept sets the final fare for their class.'**
  String get smartBundleFootnoteWide;

  /// No description provided for @smartBundleFootnoteNarrow.
  ///
  /// In en, this message translates to:
  /// **'Fewer classes selected — matching may take a bit longer.'**
  String get smartBundleFootnoteNarrow;

  /// No description provided for @smartBundleFootnoteSingle.
  ///
  /// In en, this message translates to:
  /// **'Single class — fixed estimate for this trip.'**
  String get smartBundleFootnoteSingle;

  /// No description provided for @smartBundlePriceBand.
  ///
  /// In en, this message translates to:
  /// **'€{min}–€{max}'**
  String smartBundlePriceBand(Object min, Object max);

  /// No description provided for @smartBundlePriceSingle.
  ///
  /// In en, this message translates to:
  /// **'€{price}'**
  String smartBundlePriceSingle(Object price);

  /// No description provided for @smartBundlePetRowTitle.
  ///
  /// In en, this message translates to:
  /// **'Pet-friendly ride'**
  String get smartBundlePetRowTitle;

  /// No description provided for @smartBundleLoadError.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t load class prices. Pick a vehicle below.'**
  String get smartBundleLoadError;

  /// No description provided for @smartBundleRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry loading prices'**
  String get smartBundleRetry;

  /// Trip summary chip when the rider enabled favorite-drivers-first matching.
  ///
  /// In en, this message translates to:
  /// **'Favorite drivers first'**
  String get favoriteDriversFirstTripDetail;

  /// No description provided for @bookDriver.
  ///
  /// In en, this message translates to:
  /// **'Book driver'**
  String get bookDriver;

  /// No description provided for @postToAllDrivers.
  ///
  /// In en, this message translates to:
  /// **'Post to all drivers'**
  String get postToAllDrivers;

  /// No description provided for @vehiclePreferredCategoryUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Your saved vehicle type is not available. We selected Standard.'**
  String get vehiclePreferredCategoryUnavailable;

  /// No description provided for @vehiclePreferredNoDriversNearby.
  ///
  /// In en, this message translates to:
  /// **'No drivers for your usual vehicle nearby. We switched to an available option.'**
  String get vehiclePreferredNoDriversNearby;

  /// No description provided for @bookingUsualVehicleChip.
  ///
  /// In en, this message translates to:
  /// **'Your usual: {vehicle}'**
  String bookingUsualVehicleChip(String vehicle);

  /// No description provided for @noRidesInCategory.
  ///
  /// In en, this message translates to:
  /// **'No rides in this category'**
  String get noRidesInCategory;

  /// No description provided for @tryDifferentFilter.
  ///
  /// In en, this message translates to:
  /// **'Try a different filter'**
  String get tryDifferentFilter;

  /// No description provided for @rideStatusCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get rideStatusCancelled;

  /// No description provided for @rideStatusSearching.
  ///
  /// In en, this message translates to:
  /// **'Searching'**
  String get rideStatusSearching;

  /// No description provided for @rideStatusDriverAssigned.
  ///
  /// In en, this message translates to:
  /// **'Driver Assigned'**
  String get rideStatusDriverAssigned;

  /// No description provided for @rideStatusDriverArrived.
  ///
  /// In en, this message translates to:
  /// **'Driver Arrived'**
  String get rideStatusDriverArrived;

  /// No description provided for @rideStatusInProgress.
  ///
  /// In en, this message translates to:
  /// **'In Progress'**
  String get rideStatusInProgress;

  /// No description provided for @selectAllThatApply.
  ///
  /// In en, this message translates to:
  /// **'Select all that apply'**
  String get selectAllThatApply;

  /// No description provided for @morePaymentOptionsHint.
  ///
  /// In en, this message translates to:
  /// **'More payment options = better chance of finding a driver'**
  String get morePaymentOptionsHint;

  /// No description provided for @chooseYourRide.
  ///
  /// In en, this message translates to:
  /// **'Choose your ride'**
  String get chooseYourRide;

  /// No description provided for @driverPayment.
  ///
  /// In en, this message translates to:
  /// **'Driver Payment'**
  String get driverPayment;

  /// No description provided for @searchEnterDestinationHint.
  ///
  /// In en, this message translates to:
  /// **'Enter destination'**
  String get searchEnterDestinationHint;

  /// No description provided for @whenRowLabel.
  ///
  /// In en, this message translates to:
  /// **'When'**
  String get whenRowLabel;

  /// No description provided for @accountProfileHeading.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get accountProfileHeading;

  /// No description provided for @accountProfileCardSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your booking name, email, and how the app looks.'**
  String get accountProfileCardSubtitle;

  /// No description provided for @accountProfilePreferencesLabel.
  ///
  /// In en, this message translates to:
  /// **'Language & theme'**
  String get accountProfilePreferencesLabel;

  /// No description provided for @accountBookingNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Booking name'**
  String get accountBookingNameLabel;

  /// No description provided for @accountBookingNameHint.
  ///
  /// In en, this message translates to:
  /// **'What should drivers call you?'**
  String get accountBookingNameHint;

  /// No description provided for @accountBookingNameDescription.
  ///
  /// In en, this message translates to:
  /// **'This name will be shown to drivers when you book a ride.'**
  String get accountBookingNameDescription;

  /// No description provided for @accountSettingsHeading.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get accountSettingsHeading;

  /// No description provided for @accountLocationNeededBody.
  ///
  /// In en, this message translates to:
  /// **'Location access is required for accurate pickup, nearby driver matching, and reliable trip updates.'**
  String get accountLocationNeededBody;

  /// No description provided for @accountManageLocation.
  ///
  /// In en, this message translates to:
  /// **'Manage location access'**
  String get accountManageLocation;

  /// No description provided for @accountNotificationsNeededBody.
  ///
  /// In en, this message translates to:
  /// **'Notifications needed'**
  String get accountNotificationsNeededBody;

  /// No description provided for @accountManageNotifications.
  ///
  /// In en, this message translates to:
  /// **'Manage notifications'**
  String get accountManageNotifications;

  /// No description provided for @toggleOn.
  ///
  /// In en, this message translates to:
  /// **'On'**
  String get toggleOn;

  /// No description provided for @toggleOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get toggleOff;

  /// No description provided for @marketplaceYourSavings.
  ///
  /// In en, this message translates to:
  /// **'Your savings'**
  String get marketplaceYourSavings;

  /// No description provided for @marketplaceStandardPrice.
  ///
  /// In en, this message translates to:
  /// **'Typical price'**
  String get marketplaceStandardPrice;

  /// No description provided for @marketplaceTypicalPriceTitle.
  ///
  /// In en, this message translates to:
  /// **'Typical for this route'**
  String get marketplaceTypicalPriceTitle;

  /// No description provided for @marketplaceTypicalPriceBody.
  ///
  /// In en, this message translates to:
  /// **'Based on nearby Cabys, this journey usually costs around {amount}.'**
  String marketplaceTypicalPriceBody(String amount);

  /// No description provided for @marketplaceMatchChanceTitle.
  ///
  /// In en, this message translates to:
  /// **'Match chance'**
  String get marketplaceMatchChanceTitle;

  /// No description provided for @marketplaceMatchChanceBody.
  ///
  /// In en, this message translates to:
  /// **'At {bid}, we estimate about a {percent}% chance a driver accepts.'**
  String marketplaceMatchChanceBody(String bid, String percent);

  /// No description provided for @marketplaceMatchChanceStrong.
  ///
  /// In en, this message translates to:
  /// **'Strong offer — you\'re at or above the usual price, so drivers are more likely to accept.'**
  String get marketplaceMatchChanceStrong;

  /// No description provided for @marketplacePricingLoading.
  ///
  /// In en, this message translates to:
  /// **'Checking live driver rates…'**
  String get marketplacePricingLoading;

  /// No description provided for @marketplaceTypicalUnavailable.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t load a typical price yet. Try again in a moment.'**
  String get marketplaceTypicalUnavailable;

  /// No description provided for @marketplaceSavingsVsTypicalPercent.
  ///
  /// In en, this message translates to:
  /// **'{percent}% below typical'**
  String marketplaceSavingsVsTypicalPercent(String percent);

  /// No description provided for @marketplaceSavingsBanner.
  ///
  /// In en, this message translates to:
  /// **'Save up to {percent}% on this ride'**
  String marketplaceSavingsBanner(String percent);

  /// No description provided for @marketplaceYourBid.
  ///
  /// In en, this message translates to:
  /// **'Your bid'**
  String get marketplaceYourBid;

  /// No description provided for @marketplaceQuickSelect.
  ///
  /// In en, this message translates to:
  /// **'Quick select'**
  String get marketplaceQuickSelect;

  /// No description provided for @marketplaceHeroTagline.
  ///
  /// In en, this message translates to:
  /// **'Name your price — drivers accept or suggest a counter.'**
  String get marketplaceHeroTagline;

  /// No description provided for @marketplaceYourRoute.
  ///
  /// In en, this message translates to:
  /// **'Your route'**
  String get marketplaceYourRoute;

  /// No description provided for @marketplaceDragToAdjustHint.
  ///
  /// In en, this message translates to:
  /// **'Slide to adjust'**
  String get marketplaceDragToAdjustHint;

  /// No description provided for @marketplaceSetPickupDestinationHint.
  ///
  /// In en, this message translates to:
  /// **'Add pickup and destination to post your ride to the marketplace.'**
  String get marketplaceSetPickupDestinationHint;

  /// No description provided for @marketplaceLiveBadge.
  ///
  /// In en, this message translates to:
  /// **'LIVE'**
  String get marketplaceLiveBadge;

  /// No description provided for @marketplaceQuickBudget.
  ///
  /// In en, this message translates to:
  /// **'Budget'**
  String get marketplaceQuickBudget;

  /// No description provided for @marketplaceQuickPopular.
  ///
  /// In en, this message translates to:
  /// **'Popular'**
  String get marketplaceQuickPopular;

  /// No description provided for @marketplaceQuickFaster.
  ///
  /// In en, this message translates to:
  /// **'Faster'**
  String get marketplaceQuickFaster;

  /// No description provided for @marketplaceQuickExpress.
  ///
  /// In en, this message translates to:
  /// **'Express'**
  String get marketplaceQuickExpress;

  /// No description provided for @marketplaceBidRangeMin.
  ///
  /// In en, this message translates to:
  /// **'€{amount}'**
  String marketplaceBidRangeMin(int amount);

  /// No description provided for @marketplaceBidRangeMax.
  ///
  /// In en, this message translates to:
  /// **'€{amount}'**
  String marketplaceBidRangeMax(int amount);

  /// No description provided for @favoritesSaveTrustedDriversBody.
  ///
  /// In en, this message translates to:
  /// **'Save drivers you trust for quick booking'**
  String get favoritesSaveTrustedDriversBody;

  /// No description provided for @favoritesSelectAllDrivers.
  ///
  /// In en, this message translates to:
  /// **'Select all drivers'**
  String get favoritesSelectAllDrivers;

  /// No description provided for @favoritesPostRideTo.
  ///
  /// In en, this message translates to:
  /// **'Post ride to {count} favorites'**
  String favoritesPostRideTo(int count);

  /// No description provided for @searchFactIndependentDrivers.
  ///
  /// In en, this message translates to:
  /// **'Independent drivers set their own prices'**
  String get searchFactIndependentDrivers;

  /// No description provided for @searchFactOwnPrices.
  ///
  /// In en, this message translates to:
  /// **'No surge pricing - ever'**
  String get searchFactOwnPrices;

  /// No description provided for @searchFactOwnFuel.
  ///
  /// In en, this message translates to:
  /// **'Drivers pay for their own fuel'**
  String get searchFactOwnFuel;

  /// No description provided for @searchFactVerifiedDrivers.
  ///
  /// In en, this message translates to:
  /// **'All drivers are verified'**
  String get searchFactVerifiedDrivers;

  /// No description provided for @searchFactFavorites.
  ///
  /// In en, this message translates to:
  /// **'We notify your saved drivers first, then open the ride to everyone nearby if none accept.'**
  String get searchFactFavorites;

  /// No description provided for @searchEnterPickupHint.
  ///
  /// In en, this message translates to:
  /// **'Enter pickup location'**
  String get searchEnterPickupHint;

  /// No description provided for @goWhereverWhenever.
  ///
  /// In en, this message translates to:
  /// **'Go wherever, whenever.'**
  String get goWhereverWhenever;

  /// No description provided for @noTaxisInZone.
  ///
  /// In en, this message translates to:
  /// **'No taxis in your zone'**
  String get noTaxisInZone;

  /// No description provided for @oneTaxiInZone.
  ///
  /// In en, this message translates to:
  /// **'1 taxi in your zone'**
  String get oneTaxiInZone;

  /// No description provided for @taxisInZone.
  ///
  /// In en, this message translates to:
  /// **'{count}+ taxis in your zone'**
  String taxisInZone(int count);

  /// No description provided for @favouriteDriver.
  ///
  /// In en, this message translates to:
  /// **'Favourite driver'**
  String get favouriteDriver;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @verified.
  ///
  /// In en, this message translates to:
  /// **'Verified'**
  String get verified;

  /// No description provided for @addEmail.
  ///
  /// In en, this message translates to:
  /// **'Add Email'**
  String get addEmail;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @reportARide.
  ///
  /// In en, this message translates to:
  /// **'Report a ride'**
  String get reportARide;

  /// No description provided for @reportARideSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Report a completed ride within 24 hours.'**
  String get reportARideSubtitle;

  /// No description provided for @reportSelectRideTitle.
  ///
  /// In en, this message translates to:
  /// **'Which ride?'**
  String get reportSelectRideTitle;

  /// No description provided for @reportSelectRideHint.
  ///
  /// In en, this message translates to:
  /// **'Choose a completed trip so we can tie your report to the correct booking.'**
  String get reportSelectRideHint;

  /// No description provided for @reportNoRidesToReport.
  ///
  /// In en, this message translates to:
  /// **'No completed rides found in the last two weeks. If something happened on an older trip, contact support.'**
  String get reportNoRidesToReport;

  /// No description provided for @reportSelectThisRide.
  ///
  /// In en, this message translates to:
  /// **'Select'**
  String get reportSelectThisRide;

  /// No description provided for @reportChangeRide.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get reportChangeRide;

  /// No description provided for @reportSelectedRideLabel.
  ///
  /// In en, this message translates to:
  /// **'Ride selected'**
  String get reportSelectedRideLabel;

  /// No description provided for @reportSelectedRideFallback.
  ///
  /// In en, this message translates to:
  /// **'This ride is linked to your report. Continue below to describe what went wrong.'**
  String get reportSelectedRideFallback;

  /// No description provided for @reportActiveTripBanner.
  ///
  /// In en, this message translates to:
  /// **'You’re reporting an issue for your current trip. Tell us what happened below.'**
  String get reportActiveTripBanner;

  /// No description provided for @ridesCardReportRide.
  ///
  /// In en, this message translates to:
  /// **'Report ride'**
  String get ridesCardReportRide;

  /// No description provided for @supportSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Question or issue? Chat with support'**
  String get supportSubtitle;

  /// No description provided for @supportHubContact.
  ///
  /// In en, this message translates to:
  /// **'Contact'**
  String get supportHubContact;

  /// No description provided for @supportNewThread.
  ///
  /// In en, this message translates to:
  /// **'New message'**
  String get supportNewThread;

  /// No description provided for @supportAllThreads.
  ///
  /// In en, this message translates to:
  /// **'All messages'**
  String get supportAllThreads;

  /// No description provided for @supportChatSendFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not send. Check connection and try again.'**
  String get supportChatSendFailed;

  /// No description provided for @supportNoThreads.
  ///
  /// In en, this message translates to:
  /// **'No conversations yet.'**
  String get supportNoThreads;

  /// No description provided for @supportThreadsTitle.
  ///
  /// In en, this message translates to:
  /// **'Messages'**
  String get supportThreadsTitle;

  /// No description provided for @supportTypeMessage.
  ///
  /// In en, this message translates to:
  /// **'Type a message'**
  String get supportTypeMessage;

  /// No description provided for @supportTicketOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get supportTicketOpen;

  /// No description provided for @supportTicketResolved.
  ///
  /// In en, this message translates to:
  /// **'Resolved'**
  String get supportTicketResolved;

  /// No description provided for @supportRecentHeading.
  ///
  /// In en, this message translates to:
  /// **'Recent'**
  String get supportRecentHeading;

  /// No description provided for @supportSeeAll.
  ///
  /// In en, this message translates to:
  /// **'See all'**
  String get supportSeeAll;

  /// No description provided for @supportOtherCategory.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get supportOtherCategory;

  /// No description provided for @supportHelpArticles.
  ///
  /// In en, this message translates to:
  /// **'Help articles'**
  String get supportHelpArticles;

  /// No description provided for @supportPickCategory.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get supportPickCategory;

  /// No description provided for @supportStartChat.
  ///
  /// In en, this message translates to:
  /// **'Start chat'**
  String get supportStartChat;

  /// No description provided for @supportSectionOngoing.
  ///
  /// In en, this message translates to:
  /// **'Ongoing'**
  String get supportSectionOngoing;

  /// No description provided for @supportSectionClosed.
  ///
  /// In en, this message translates to:
  /// **'Closed'**
  String get supportSectionClosed;

  /// No description provided for @supportResolutionSummary.
  ///
  /// In en, this message translates to:
  /// **'Reason'**
  String get supportResolutionSummary;

  /// No description provided for @supportResolutionOutcome.
  ///
  /// In en, this message translates to:
  /// **'How it was resolved'**
  String get supportResolutionOutcome;

  /// No description provided for @supportChatOfflineSaved.
  ///
  /// In en, this message translates to:
  /// **'Your message was saved. The assistant is offline — support can still read it.'**
  String get supportChatOfflineSaved;

  /// No description provided for @supportAiConsentTitle.
  ///
  /// In en, this message translates to:
  /// **'Meet Yaz, your AI support assistant'**
  String get supportAiConsentTitle;

  /// No description provided for @supportAiConsentIntro.
  ///
  /// In en, this message translates to:
  /// **'Yaz is HeyCaby\'s AI customer service assistant. Her job is to listen to your complaint and help solve simple support issues quickly.'**
  String get supportAiConsentIntro;

  /// No description provided for @supportAiConsentDataSent.
  ///
  /// In en, this message translates to:
  /// **'To help you, we send: the message you type, your support ticket category, and limited account context needed to answer your request.'**
  String get supportAiConsentDataSent;

  /// No description provided for @supportAiConsentThirdParty.
  ///
  /// In en, this message translates to:
  /// **'AI processing: Yaz uses OpenAI (ChatGPT) models to generate responses.'**
  String get supportAiConsentThirdParty;

  /// No description provided for @supportAiConsentPolicy.
  ///
  /// In en, this message translates to:
  /// **'For serious or sensitive issues, do not share private details in AI chat. Please email support at hello@heycaby.nl.'**
  String get supportAiConsentPolicy;

  /// No description provided for @supportAiConsentEmailOption.
  ///
  /// In en, this message translates to:
  /// **'Do not include passwords, full payment card numbers, government IDs, or other highly sensitive data in AI chat.'**
  String get supportAiConsentEmailOption;

  /// No description provided for @supportAiConsentCheckbox.
  ///
  /// In en, this message translates to:
  /// **'I understand what data is sent, who processes it, and I allow HeyCaby to share this support chat data with Yaz AI support.'**
  String get supportAiConsentCheckbox;

  /// No description provided for @supportAiConsentContinue.
  ///
  /// In en, this message translates to:
  /// **'I agree and continue'**
  String get supportAiConsentContinue;

  /// No description provided for @supportAiConsentSendEmail.
  ///
  /// In en, this message translates to:
  /// **'Send email instead'**
  String get supportAiConsentSendEmail;

  /// No description provided for @supportCategoryRideIssue.
  ///
  /// In en, this message translates to:
  /// **'Ride issue'**
  String get supportCategoryRideIssue;

  /// No description provided for @supportCategoryPayment.
  ///
  /// In en, this message translates to:
  /// **'Payment'**
  String get supportCategoryPayment;

  /// No description provided for @supportCategoryAccount.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get supportCategoryAccount;

  /// No description provided for @supportMessageSentTitle.
  ///
  /// In en, this message translates to:
  /// **'Message sent'**
  String get supportMessageSentTitle;

  /// No description provided for @supportMessageSentBody.
  ///
  /// In en, this message translates to:
  /// **'Thank you for your message. Our customer support team will review it and get back to you as soon as possible.\n\nIf your issue is urgent, you can chat with Yaz (AI support assistant). Please avoid sharing sensitive personal information in AI chat.'**
  String get supportMessageSentBody;

  /// No description provided for @supportMessageSendFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Could not send message'**
  String get supportMessageSendFailedTitle;

  /// No description provided for @supportMessageSendFailedBody.
  ///
  /// In en, this message translates to:
  /// **'We could not send your support message right now. Please try again shortly, or use Chat with Yaz for urgent help.'**
  String get supportMessageSendFailedBody;

  /// No description provided for @supportChatWithYaz.
  ///
  /// In en, this message translates to:
  /// **'Chat with Yaz'**
  String get supportChatWithYaz;

  /// No description provided for @supportSendMessageButton.
  ///
  /// In en, this message translates to:
  /// **'Send message'**
  String get supportSendMessageButton;

  /// No description provided for @supportYazUnavailableGuestAuthDisabled.
  ///
  /// In en, this message translates to:
  /// **'Yaz chat is temporarily unavailable because guest chat auth is disabled on the server.'**
  String get supportYazUnavailableGuestAuthDisabled;

  /// No description provided for @supportYazUnavailableTemporary.
  ///
  /// In en, this message translates to:
  /// **'Yaz chat is temporarily unavailable. Please try again shortly.'**
  String get supportYazUnavailableTemporary;

  /// No description provided for @supportYazFallbackReply.
  ///
  /// In en, this message translates to:
  /// **'I could not answer right now. Please try again or send email support.'**
  String get supportYazFallbackReply;

  /// No description provided for @supportEmailSupport.
  ///
  /// In en, this message translates to:
  /// **'Email support'**
  String get supportEmailSupport;

  /// No description provided for @supportYazAssistantTitle.
  ///
  /// In en, this message translates to:
  /// **'Yaz AI support assistant'**
  String get supportYazAssistantTitle;

  /// No description provided for @supportYazAssistantSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Ask anything about your ride, account, or payment.'**
  String get supportYazAssistantSubtitle;

  /// No description provided for @supportYazMessageHint.
  ///
  /// In en, this message translates to:
  /// **'Message Yaz...'**
  String get supportYazMessageHint;

  /// No description provided for @favouriteDriversAccountSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Save trusted drivers and send rides directly to them.'**
  String get favouriteDriversAccountSubtitle;

  /// No description provided for @openLocationSettings.
  ///
  /// In en, this message translates to:
  /// **'Open location settings'**
  String get openLocationSettings;

  /// No description provided for @openNotificationSettings.
  ///
  /// In en, this message translates to:
  /// **'Open notification settings'**
  String get openNotificationSettings;

  /// No description provided for @cashSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Pay with cash directly to driver'**
  String get cashSubtitle;

  /// No description provided for @pinSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Debit card payment in vehicle'**
  String get pinSubtitle;

  /// No description provided for @tikkieSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Pay via Tikkie payment request'**
  String get tikkieSubtitle;

  /// No description provided for @yourName.
  ///
  /// In en, this message translates to:
  /// **'Your name'**
  String get yourName;

  /// No description provided for @paymentMethodsSelected.
  ///
  /// In en, this message translates to:
  /// **'{count} payment method(s) selected'**
  String paymentMethodsSelected(int count);

  /// No description provided for @vehicleStandard.
  ///
  /// In en, this message translates to:
  /// **'Standard'**
  String get vehicleStandard;

  /// No description provided for @vehicleStandardDesc.
  ///
  /// In en, this message translates to:
  /// **'Affordable rides for everyday trips'**
  String get vehicleStandardDesc;

  /// No description provided for @vehicleComfort.
  ///
  /// In en, this message translates to:
  /// **'Comfort'**
  String get vehicleComfort;

  /// No description provided for @vehicleComfortDesc.
  ///
  /// In en, this message translates to:
  /// **'Premium vehicles with extra space'**
  String get vehicleComfortDesc;

  /// No description provided for @vehicleTaxibus.
  ///
  /// In en, this message translates to:
  /// **'Taxibus'**
  String get vehicleTaxibus;

  /// No description provided for @vehicleTaxibusDesc.
  ///
  /// In en, this message translates to:
  /// **'Up to 8 passengers with luggage'**
  String get vehicleTaxibusDesc;

  /// No description provided for @vehicleWheelchair.
  ///
  /// In en, this message translates to:
  /// **'Wheelchair'**
  String get vehicleWheelchair;

  /// No description provided for @vehicleWheelchairDesc.
  ///
  /// In en, this message translates to:
  /// **'Accessible vehicles with ramps'**
  String get vehicleWheelchairDesc;

  /// No description provided for @petFriendly.
  ///
  /// In en, this message translates to:
  /// **'Pet-friendly'**
  String get petFriendly;

  /// No description provided for @petFriendlyDesc.
  ///
  /// In en, this message translates to:
  /// **'Drivers who accept pets'**
  String get petFriendlyDesc;

  /// No description provided for @vehicleSupplyCountCaption.
  ///
  /// In en, this message translates to:
  /// **'drivers available'**
  String get vehicleSupplyCountCaption;

  /// No description provided for @vehicleSupplyDriversCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No drivers nearby} one{1 driver nearby} other{{count} drivers nearby}}'**
  String vehicleSupplyDriversCount(int count);

  /// No description provided for @vehicleSupplyNearestKm.
  ///
  /// In en, this message translates to:
  /// **'Nearest ~{km} km'**
  String vehicleSupplyNearestKm(String km);

  /// No description provided for @vehicleSupplyFromPrice.
  ///
  /// In en, this message translates to:
  /// **'From €{price}'**
  String vehicleSupplyFromPrice(String price);

  /// No description provided for @vehicleSupplyShowDrivers.
  ///
  /// In en, this message translates to:
  /// **'Show drivers'**
  String get vehicleSupplyShowDrivers;

  /// No description provided for @vehicleSupplyHideDrivers.
  ///
  /// In en, this message translates to:
  /// **'Hide drivers'**
  String get vehicleSupplyHideDrivers;

  /// No description provided for @vehicleSupplyEstimatesNote.
  ///
  /// In en, this message translates to:
  /// **'Prices and availability are estimates and may change when you book.'**
  String get vehicleSupplyEstimatesNote;

  /// No description provided for @returnTripFareEstimatesTitle.
  ///
  /// In en, this message translates to:
  /// **'Return-trip offers'**
  String get returnTripFareEstimatesTitle;

  /// No description provided for @returnTripFareEstimatesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Show driver prices with their active return-trip discount applied. Turn off for standard tariff estimates.'**
  String get returnTripFareEstimatesSubtitle;

  /// No description provided for @returnTripFareEstimatesRequiresRoute.
  ///
  /// In en, this message translates to:
  /// **'Add pickup and drop-off to preview return-trip prices.'**
  String get returnTripFareEstimatesRequiresRoute;

  /// No description provided for @vehicleSupplyNoPickup.
  ///
  /// In en, this message translates to:
  /// **'Set a pickup location to see nearby drivers.'**
  String get vehicleSupplyNoPickup;

  /// No description provided for @vehicleSupplyLoading.
  ///
  /// In en, this message translates to:
  /// **'Checking nearby drivers…'**
  String get vehicleSupplyLoading;

  /// No description provided for @vehicleSupplyNoDriversInCategory.
  ///
  /// In en, this message translates to:
  /// **'No drivers in this category right now.'**
  String get vehicleSupplyNoDriversInCategory;

  /// No description provided for @vehicleDriverOfferRow.
  ///
  /// In en, this message translates to:
  /// **'~{distanceKm} km · €{price}'**
  String vehicleDriverOfferRow(String distanceKm, String price);

  /// No description provided for @vehicleDriverNumbered.
  ///
  /// In en, this message translates to:
  /// **'Driver {n}'**
  String vehicleDriverNumbered(int n);

  /// No description provided for @ratingGreatDriver.
  ///
  /// In en, this message translates to:
  /// **'Great driver'**
  String get ratingGreatDriver;

  /// No description provided for @ratingCleanVehicle.
  ///
  /// In en, this message translates to:
  /// **'Clean vehicle'**
  String get ratingCleanVehicle;

  /// No description provided for @ratingSafeDriving.
  ///
  /// In en, this message translates to:
  /// **'Safe driving'**
  String get ratingSafeDriving;

  /// No description provided for @ratingFriendly.
  ///
  /// In en, this message translates to:
  /// **'Friendly'**
  String get ratingFriendly;

  /// No description provided for @ratingOnTime.
  ///
  /// In en, this message translates to:
  /// **'On time'**
  String get ratingOnTime;

  /// No description provided for @ratingProfessional.
  ///
  /// In en, this message translates to:
  /// **'Professional'**
  String get ratingProfessional;

  /// No description provided for @failedToSubmitRating.
  ///
  /// In en, this message translates to:
  /// **'Failed to submit rating'**
  String get failedToSubmitRating;

  /// No description provided for @reportDriverBehavior.
  ///
  /// In en, this message translates to:
  /// **'Driver behavior'**
  String get reportDriverBehavior;

  /// No description provided for @reportVehicleCondition.
  ///
  /// In en, this message translates to:
  /// **'Vehicle condition'**
  String get reportVehicleCondition;

  /// No description provided for @reportRouteIssue.
  ///
  /// In en, this message translates to:
  /// **'Route issue'**
  String get reportRouteIssue;

  /// No description provided for @reportSafetyConcern.
  ///
  /// In en, this message translates to:
  /// **'Safety concern'**
  String get reportSafetyConcern;

  /// No description provided for @reportPricingDispute.
  ///
  /// In en, this message translates to:
  /// **'Pricing dispute'**
  String get reportPricingDispute;

  /// No description provided for @reportOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get reportOther;

  /// No description provided for @driver.
  ///
  /// In en, this message translates to:
  /// **'Driver'**
  String get driver;

  /// No description provided for @errorLoadingMessages.
  ///
  /// In en, this message translates to:
  /// **'Error loading messages'**
  String get errorLoadingMessages;

  /// No description provided for @typeAMessage.
  ///
  /// In en, this message translates to:
  /// **'Type a message...'**
  String get typeAMessage;

  /// No description provided for @noMessagesYet.
  ///
  /// In en, this message translates to:
  /// **'No messages yet'**
  String get noMessagesYet;

  /// No description provided for @startConversation.
  ///
  /// In en, this message translates to:
  /// **'Start a conversation with your driver'**
  String get startConversation;

  /// No description provided for @faq.
  ///
  /// In en, this message translates to:
  /// **'FAQ'**
  String get faq;

  /// No description provided for @termsOfService.
  ///
  /// In en, this message translates to:
  /// **'Terms of Service'**
  String get termsOfService;

  /// No description provided for @privacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacyPolicy;

  /// No description provided for @logoutConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Log out?'**
  String get logoutConfirmTitle;

  /// No description provided for @logoutConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'You will need to re-enter your details to book again.'**
  String get logoutConfirmMessage;

  /// No description provided for @linkCopied.
  ///
  /// In en, this message translates to:
  /// **'Link copied to clipboard'**
  String get linkCopied;

  /// No description provided for @cancelRide.
  ///
  /// In en, this message translates to:
  /// **'Cancel ride'**
  String get cancelRide;

  /// No description provided for @cancelRideConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to cancel this ride?'**
  String get cancelRideConfirm;

  /// No description provided for @noDriverFound.
  ///
  /// In en, this message translates to:
  /// **'No driver found'**
  String get noDriverFound;

  /// No description provided for @noDriverFoundMessage.
  ///
  /// In en, this message translates to:
  /// **'We could not find a driver for your ride.'**
  String get noDriverFoundMessage;

  /// No description provided for @retrySearch.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get retrySearch;

  /// No description provided for @youHaveArrived.
  ///
  /// In en, this message translates to:
  /// **'You have arrived!'**
  String get youHaveArrived;

  /// No description provided for @payDriverCash.
  ///
  /// In en, this message translates to:
  /// **'Pay cash to the driver'**
  String get payDriverCash;

  /// No description provided for @payDriverPin.
  ///
  /// In en, this message translates to:
  /// **'Pay by PIN to the driver'**
  String get payDriverPin;

  /// No description provided for @payDriverTikkie.
  ///
  /// In en, this message translates to:
  /// **'You will receive a Tikkie from the driver'**
  String get payDriverTikkie;

  /// No description provided for @rateDriver.
  ///
  /// In en, this message translates to:
  /// **'Rate driver'**
  String get rateDriver;

  /// No description provided for @addToFavourites.
  ///
  /// In en, this message translates to:
  /// **'Add to favourites'**
  String get addToFavourites;

  /// No description provided for @addComment.
  ///
  /// In en, this message translates to:
  /// **'Add a comment...'**
  String get addComment;

  /// No description provided for @etaToDestination.
  ///
  /// In en, this message translates to:
  /// **'{min} min to destination'**
  String etaToDestination(String min);

  /// No description provided for @rideDetails.
  ///
  /// In en, this message translates to:
  /// **'Ride details'**
  String get rideDetails;

  /// No description provided for @rideDetailViewReceipt.
  ///
  /// In en, this message translates to:
  /// **'View receipt'**
  String get rideDetailViewReceipt;

  /// No description provided for @rideDetailReceiptLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load receipt right now.'**
  String get rideDetailReceiptLoadFailed;

  /// No description provided for @rebookRide.
  ///
  /// In en, this message translates to:
  /// **'Book again'**
  String get rebookRide;

  /// No description provided for @scheduleYourRide.
  ///
  /// In en, this message translates to:
  /// **'Schedule your ride'**
  String get scheduleYourRide;

  /// No description provided for @selectDate.
  ///
  /// In en, this message translates to:
  /// **'Select date'**
  String get selectDate;

  /// No description provided for @selectTime.
  ///
  /// In en, this message translates to:
  /// **'Select time'**
  String get selectTime;

  /// No description provided for @confirmSchedule.
  ///
  /// In en, this message translates to:
  /// **'Confirm schedule'**
  String get confirmSchedule;

  /// No description provided for @postToMarketplace.
  ///
  /// In en, this message translates to:
  /// **'Post to Marketplace'**
  String get postToMarketplace;

  /// No description provided for @addYourEmail.
  ///
  /// In en, this message translates to:
  /// **'Add your email'**
  String get addYourEmail;

  /// No description provided for @emailOnlyUsedFor.
  ///
  /// In en, this message translates to:
  /// **'We use your email only to verify your identity for favourite drivers.'**
  String get emailOnlyUsedFor;

  /// No description provided for @enterYourEmail.
  ///
  /// In en, this message translates to:
  /// **'Enter your email address'**
  String get enterYourEmail;

  /// No description provided for @sendCode.
  ///
  /// In en, this message translates to:
  /// **'Send code'**
  String get sendCode;

  /// No description provided for @invalidEmail.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid email address'**
  String get invalidEmail;

  /// No description provided for @failedToSaveEmail.
  ///
  /// In en, this message translates to:
  /// **'Failed to save email. Please try again.'**
  String get failedToSaveEmail;

  /// No description provided for @riderEmailReviewCodeHint.
  ///
  /// In en, this message translates to:
  /// **'Verification code (App Store review only — leave empty for a normal account)'**
  String get riderEmailReviewCodeHint;

  /// No description provided for @riderEmailReviewCodeFieldHint.
  ///
  /// In en, this message translates to:
  /// **'6-digit code from App Store notes'**
  String get riderEmailReviewCodeFieldHint;

  /// No description provided for @riderEmailReviewCredentialsError.
  ///
  /// In en, this message translates to:
  /// **'That email and code do not match the review login. Leave the code empty if you are not using the review account.'**
  String get riderEmailReviewCredentialsError;

  /// No description provided for @riderEmailReviewOtpSixDigitsOrEmpty.
  ///
  /// In en, this message translates to:
  /// **'Enter all 6 digits or leave the code field empty.'**
  String get riderEmailReviewOtpSixDigitsOrEmpty;

  /// No description provided for @addYourHome.
  ///
  /// In en, this message translates to:
  /// **'Add your home'**
  String get addYourHome;

  /// No description provided for @homeAddressDesc.
  ///
  /// In en, this message translates to:
  /// **'Save your home address for quick access.'**
  String get homeAddressDesc;

  /// No description provided for @enterHomeAddress.
  ///
  /// In en, this message translates to:
  /// **'Enter your home address'**
  String get enterHomeAddress;

  /// No description provided for @saving.
  ///
  /// In en, this message translates to:
  /// **'Saving...'**
  String get saving;

  /// No description provided for @failedToSaveHome.
  ///
  /// In en, this message translates to:
  /// **'Failed to save home address'**
  String get failedToSaveHome;

  /// No description provided for @faqBookingSection.
  ///
  /// In en, this message translates to:
  /// **'Booking'**
  String get faqBookingSection;

  /// No description provided for @faqHowToBook.
  ///
  /// In en, this message translates to:
  /// **'How do I book a ride?'**
  String get faqHowToBook;

  /// No description provided for @faqHowToBookAnswer.
  ///
  /// In en, this message translates to:
  /// **'Open the app, tap \'Where to?\', enter your destination, choose a booking mode (Instant or Marketplace), select a payment method, and tap \'Find my driver\'. A nearby driver will be matched to your ride.'**
  String get faqHowToBookAnswer;

  /// No description provided for @faqInstantVsMarketplace.
  ///
  /// In en, this message translates to:
  /// **'What is the difference between Instant and Marketplace?'**
  String get faqInstantVsMarketplace;

  /// No description provided for @faqInstantVsMarketplaceAnswer.
  ///
  /// In en, this message translates to:
  /// **'Instant sends your ride request to nearby drivers immediately. Marketplace lets you set your own price and drivers can bid on your ride, potentially saving you money.'**
  String get faqInstantVsMarketplaceAnswer;

  /// No description provided for @faqScheduleRide.
  ///
  /// In en, this message translates to:
  /// **'Can I schedule a ride for later?'**
  String get faqScheduleRide;

  /// No description provided for @faqScheduleRideAnswer.
  ///
  /// In en, this message translates to:
  /// **'Yes! Tap the \'Later\' button on the home screen to choose a date and time for your ride. Your request will be sent to drivers at the scheduled time.'**
  String get faqScheduleRideAnswer;

  /// No description provided for @faqHowMarketplace.
  ///
  /// In en, this message translates to:
  /// **'How does the Marketplace work?'**
  String get faqHowMarketplace;

  /// No description provided for @faqHowMarketplaceAnswer.
  ///
  /// In en, this message translates to:
  /// **'You set your desired price for the ride. Drivers see your offer and can bid on it. You choose which driver to accept based on their price, rating, and ETA.'**
  String get faqHowMarketplaceAnswer;

  /// No description provided for @faqDriversSection.
  ///
  /// In en, this message translates to:
  /// **'Drivers and favourites'**
  String get faqDriversSection;

  /// No description provided for @faqAddFavourite.
  ///
  /// In en, this message translates to:
  /// **'How do I add a driver as a favourite?'**
  String get faqAddFavourite;

  /// No description provided for @faqAddFavouriteAnswer.
  ///
  /// In en, this message translates to:
  /// **'After completing a ride, you can tap the heart icon on the rating screen to add that driver to your favourites. You need a verified email to use favourites.'**
  String get faqAddFavouriteAnswer;

  /// No description provided for @faqWhatAreFavourites.
  ///
  /// In en, this message translates to:
  /// **'What are favourite drivers?'**
  String get faqWhatAreFavourites;

  /// No description provided for @faqWhatAreFavouritesAnswer.
  ///
  /// In en, this message translates to:
  /// **'Favourite drivers are drivers you have saved. You can book rides directly to your trusted drivers for a more personal experience.'**
  String get faqWhatAreFavouritesAnswer;

  /// No description provided for @faqBlockDriver.
  ///
  /// In en, this message translates to:
  /// **'Can I block a driver?'**
  String get faqBlockDriver;

  /// No description provided for @faqBlockDriverAnswer.
  ///
  /// In en, this message translates to:
  /// **'During an active ride chat, open the menu (⋮) and use Block driver. You can also report a driver after a ride from the rating flow.'**
  String get faqBlockDriverAnswer;

  /// No description provided for @faqPaymentSection.
  ///
  /// In en, this message translates to:
  /// **'Payment'**
  String get faqPaymentSection;

  /// No description provided for @faqPaymentMethods.
  ///
  /// In en, this message translates to:
  /// **'Which payment methods are available?'**
  String get faqPaymentMethods;

  /// No description provided for @faqPaymentMethodsAnswer.
  ///
  /// In en, this message translates to:
  /// **'Cash, PIN (debit card in vehicle), and Tikkie (payment request sent after the ride).'**
  String get faqPaymentMethodsAnswer;

  /// No description provided for @faqWhoPaysWho.
  ///
  /// In en, this message translates to:
  /// **'Who pays who?'**
  String get faqWhoPaysWho;

  /// No description provided for @faqWhoPaysWhoAnswer.
  ///
  /// In en, this message translates to:
  /// **'You pay the driver directly. HeyCaby takes zero commission — 100% of the fare goes to the driver.'**
  String get faqWhoPaysWhoAnswer;

  /// No description provided for @faqWhereSeeCosts.
  ///
  /// In en, this message translates to:
  /// **'Where can I see my ride costs?'**
  String get faqWhereSeeCosts;

  /// No description provided for @faqWhereSeeCostsAnswer.
  ///
  /// In en, this message translates to:
  /// **'On the ride complete screen and in your rides history under the Rides tab.'**
  String get faqWhereSeeCostsAnswer;

  /// No description provided for @faqSafetySection.
  ///
  /// In en, this message translates to:
  /// **'Problems and safety'**
  String get faqSafetySection;

  /// No description provided for @faqDriverNoShow.
  ///
  /// In en, this message translates to:
  /// **'What do I do if my driver doesn\'t come?'**
  String get faqDriverNoShow;

  /// No description provided for @faqDriverNoShowAnswer.
  ///
  /// In en, this message translates to:
  /// **'The waiting screen has a cancel option. If no driver is found within a few minutes, you can retry or cancel the ride.'**
  String get faqDriverNoShowAnswer;

  /// No description provided for @faqReportIncident.
  ///
  /// In en, this message translates to:
  /// **'How do I report an incident?'**
  String get faqReportIncident;

  /// No description provided for @faqReportIncidentAnswer.
  ///
  /// In en, this message translates to:
  /// **'After a ride, use the report option on the rating screen to submit details about what happened.'**
  String get faqReportIncidentAnswer;

  /// No description provided for @faqInsurance.
  ///
  /// In en, this message translates to:
  /// **'Is my ride insured?'**
  String get faqInsurance;

  /// No description provided for @faqInsuranceAnswer.
  ///
  /// In en, this message translates to:
  /// **'All HeyCaby drivers are professional licensed taxi drivers with valid insurance.'**
  String get faqInsuranceAnswer;

  /// No description provided for @faqAccountSection.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get faqAccountSection;

  /// No description provided for @faqChangeName.
  ///
  /// In en, this message translates to:
  /// **'How do I change my booking name?'**
  String get faqChangeName;

  /// No description provided for @faqChangeNameAnswer.
  ///
  /// In en, this message translates to:
  /// **'Go to Account and tap the name field to edit it. Your new name will be shown to drivers on future bookings.'**
  String get faqChangeNameAnswer;

  /// No description provided for @faqVerifyEmail.
  ///
  /// In en, this message translates to:
  /// **'How do I verify my email?'**
  String get faqVerifyEmail;

  /// No description provided for @faqVerifyEmailAnswer.
  ///
  /// In en, this message translates to:
  /// **'Favourites need a saved email. Open Account or Favourite drivers, tap Add Email, enter your address, and tap Continue. For App Store review, use the review email and enter the 6-digit code from App Review Information in the verification code field.'**
  String get faqVerifyEmailAnswer;

  /// No description provided for @faqDeleteAccount.
  ///
  /// In en, this message translates to:
  /// **'How do I delete my account?'**
  String get faqDeleteAccount;

  /// No description provided for @faqDeleteAccountAnswer.
  ///
  /// In en, this message translates to:
  /// **'Go to Account, tap Delete my account, confirm by typing DELETE. This removes your rider identity and related saved data from HeyCaby.'**
  String get faqDeleteAccountAnswer;

  /// No description provided for @termsTitle.
  ///
  /// In en, this message translates to:
  /// **'Terms of Service'**
  String get termsTitle;

  /// No description provided for @termsWhatIsHeyCaby.
  ///
  /// In en, this message translates to:
  /// **'1. About HeyCaby'**
  String get termsWhatIsHeyCaby;

  /// No description provided for @termsWhatIsHeyCabyBody.
  ///
  /// In en, this message translates to:
  /// **'HeyCaby is a platform that connects riders with independent, licensed taxi drivers. We do not employ drivers and do not provide transportation services ourselves. We act solely as a matching and facilitation platform.\n\nUser roles:\n• Riders: individuals requesting transportation\n• Drivers: independent professionals providing transportation\n\nEach user is responsible for their own actions on the platform.'**
  String get termsWhatIsHeyCabyBody;

  /// No description provided for @termsRiderResponsibilities.
  ///
  /// In en, this message translates to:
  /// **'2. Rider Responsibilities'**
  String get termsRiderResponsibilities;

  /// No description provided for @termsRiderResponsibilitiesBody.
  ///
  /// In en, this message translates to:
  /// **'As a rider, you agree to:\n• Provide accurate pickup and destination information\n• Be present at the pickup location on time\n• Treat drivers with respect and professionalism\n• Pay for completed rides using agreed methods\n• Not engage in illegal, abusive, or unsafe behavior\n\nFailure to meet these responsibilities may result in account suspension.'**
  String get termsRiderResponsibilitiesBody;

  /// No description provided for @termsPayment.
  ///
  /// In en, this message translates to:
  /// **'3. Driver Responsibilities and 4. Payments'**
  String get termsPayment;

  /// No description provided for @termsPaymentBody.
  ///
  /// In en, this message translates to:
  /// **'Drivers using HeyCaby must hold valid licenses and permits required by law, provide safe and lawful transport, communicate clearly, set fair pricing, and handle payments directly with riders.\n\nPayments are made directly between rider and driver. HeyCaby does not process, hold, or guarantee payments. Available methods may include cash, card (PIN), or third-party apps (e.g. Tikkie). Payment disputes must be resolved between rider and driver.'**
  String get termsPaymentBody;

  /// No description provided for @termsCancellation.
  ///
  /// In en, this message translates to:
  /// **'5. Cancellations'**
  String get termsCancellation;

  /// No description provided for @termsCancellationBody.
  ///
  /// In en, this message translates to:
  /// **'Riders may cancel before driver acceptance at no cost. After acceptance, cancellation fees may apply at the driver’s discretion. Repeated cancellations or no-shows may result in account restrictions.'**
  String get termsCancellationBody;

  /// No description provided for @termsSuspension.
  ///
  /// In en, this message translates to:
  /// **'6. Platform Usage and 8. Account Suspension'**
  String get termsSuspension;

  /// No description provided for @termsSuspensionBody.
  ///
  /// In en, this message translates to:
  /// **'You agree not to misuse the platform, provide false information, attempt fraud or payment abuse, or harass/harm other users.\n\nHeyCaby may suspend or terminate accounts in cases of fraudulent activity, abuse, harassment, repeated no-shows/cancellations, or other violations of these terms.'**
  String get termsSuspensionBody;

  /// No description provided for @termsDisputes.
  ///
  /// In en, this message translates to:
  /// **'9. Disputes and 10. Liability'**
  String get termsDisputes;

  /// No description provided for @termsDisputesBody.
  ///
  /// In en, this message translates to:
  /// **'Users should first resolve disputes directly. If needed, disputes can be reported through the app. HeyCaby may assist but is not liable for outcomes between users.\n\nHeyCaby is not liable for actions of drivers or riders, ride quality/safety, or damages/losses/disputes arising from trips. Users accept that HeyCaby is a facilitator, not a transport provider.'**
  String get termsDisputesBody;

  /// No description provided for @termsGoverningLaw.
  ///
  /// In en, this message translates to:
  /// **'11. Changes to Terms'**
  String get termsGoverningLaw;

  /// No description provided for @termsGoverningLawBody.
  ///
  /// In en, this message translates to:
  /// **'We may update these terms at any time. Continued use of the platform means you accept the updated terms.'**
  String get termsGoverningLawBody;

  /// No description provided for @termsContact.
  ///
  /// In en, this message translates to:
  /// **'12. Contact'**
  String get termsContact;

  /// No description provided for @termsContactBody.
  ///
  /// In en, this message translates to:
  /// **'For support or disputes, use the in-app support feature.'**
  String get termsContactBody;

  /// No description provided for @privacyTitle.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacyTitle;

  /// No description provided for @privacyDataCollected.
  ///
  /// In en, this message translates to:
  /// **'1. Information We Collect'**
  String get privacyDataCollected;

  /// No description provided for @privacyDataCollectedBody.
  ///
  /// In en, this message translates to:
  /// **'We collect only the data necessary to provide our services:\n• Account information: email and basic profile details for account creation and identity verification\n• Location data: used during active bookings to match riders with nearby drivers and facilitate trips\n• Trip data: pickup/drop-off locations, timestamps, and ride history for receipts and service improvement\n• Device data: app version, device type, and push notification tokens for functionality and performance\n• Support data: support ticket messages and category, which may be processed by our AI support provider when you consent in chat'**
  String get privacyDataCollectedBody;

  /// No description provided for @privacyLocationData.
  ///
  /// In en, this message translates to:
  /// **'3. Location Data Usage'**
  String get privacyLocationData;

  /// No description provided for @privacyLocationDataBody.
  ///
  /// In en, this message translates to:
  /// **'Location is accessed only during active ride sessions. We do not track users in the background outside of bookings. Location data is not stored longer than necessary for trip completion.'**
  String get privacyLocationDataBody;

  /// No description provided for @privacyDataSharing.
  ///
  /// In en, this message translates to:
  /// **'4. Data Sharing'**
  String get privacyDataSharing;

  /// No description provided for @privacyDataSharingBody.
  ///
  /// In en, this message translates to:
  /// **'We share limited data only when required to provide the service.\n\nDrivers receive: rider name (or alias) and pickup location.\nRiders receive: driver details necessary for the trip.\n\nSupport AI (with your consent before first message): support chat message content, ticket category, and minimal context needed to answer your support request are processed by OpenAI (ChatGPT) models.\n\nWe do not share email addresses, phone numbers (unless explicitly required by future features), or sensitive personal data for AI chat.'**
  String get privacyDataSharingBody;

  /// No description provided for @privacyRetention.
  ///
  /// In en, this message translates to:
  /// **'5. Data Retention'**
  String get privacyRetention;

  /// No description provided for @privacyRetentionBody.
  ///
  /// In en, this message translates to:
  /// **'Trip data is stored for receipts and history. Account data is stored until account deletion is requested. Temporary data (like recent searches) may expire automatically.'**
  String get privacyRetentionBody;

  /// No description provided for @privacyGdpr.
  ///
  /// In en, this message translates to:
  /// **'6. Your Rights (GDPR)'**
  String get privacyGdpr;

  /// No description provided for @privacyGdprBody.
  ///
  /// In en, this message translates to:
  /// **'As a user in the EU, you have the right to access your personal data, correct inaccurate data, request deletion of your account, and restrict or object to processing.\n\nYou can delete your account directly in the app: Account → Delete Account.'**
  String get privacyGdprBody;

  /// No description provided for @privacyNoAds.
  ///
  /// In en, this message translates to:
  /// **'2/7/8/9/10/11/12. Use, AI Support (Yaz), Security, Notifications, Third Parties, Changes, Contact'**
  String get privacyNoAds;

  /// No description provided for @privacyNoAdsBody.
  ///
  /// In en, this message translates to:
  /// **'Your data is used strictly to operate HeyCaby: matching riders and drivers, facilitating bookings and communication, providing trip history and receipts, improving performance, and sending important notifications.\n\nAI Support (Yaz): when you choose \"Chat with Yaz\" and explicitly consent in-app, your support message content, ticket category, and limited account context are processed by OpenAI (ChatGPT) to generate support responses. AI chat is optional. You can use non-AI support instead via \"New message\".\n\nWe instruct users not to include highly sensitive data in AI chat (such as passwords, full payment card numbers, or government ID numbers). For sensitive or complex issues, users are directed to contact human support.\n\nWe do not use your data for advertising and we do not sell your data to third parties.\n\nWe apply technical and organizational security measures, though no system is 100% secure.\n\nPush notifications may include ride updates, important service messages, and occasional product updates. You can disable notifications in device settings.\n\nWe may use trusted providers (e.g., payment providers, Firebase, Supabase) only as needed to deliver services.\n\nWe may update this policy from time to time; continued use means acceptance of updates.\n\nFor privacy-related requests, contact us via the in-app support section.'**
  String get privacyNoAdsBody;

  /// No description provided for @distanceRemaining.
  ///
  /// In en, this message translates to:
  /// **'{km} km remaining'**
  String distanceRemaining(String km);

  /// No description provided for @shareRideLink.
  ///
  /// In en, this message translates to:
  /// **'Share ride link'**
  String get shareRideLink;

  /// No description provided for @rideShareCopied.
  ///
  /// In en, this message translates to:
  /// **'Ride tracking link copied to clipboard'**
  String get rideShareCopied;

  /// No description provided for @deleteMyAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete my account'**
  String get deleteMyAccount;

  /// No description provided for @deleteAccountConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete your account permanently?'**
  String get deleteAccountConfirmTitle;

  /// No description provided for @deleteAccountConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'Your rider profile and data tied to this session will be removed from HeyCaby. Some trip records may be kept where the law requires. This cannot be undone.'**
  String get deleteAccountConfirmBody;

  /// No description provided for @deleteAccountTypeDeleteHint.
  ///
  /// In en, this message translates to:
  /// **'Type DELETE to confirm'**
  String get deleteAccountTypeDeleteHint;

  /// No description provided for @deleteAccountTypeDeleteError.
  ///
  /// In en, this message translates to:
  /// **'Type the word DELETE (any letter case is fine), then tap Delete my account again.'**
  String get deleteAccountTypeDeleteError;

  /// No description provided for @deleteAccountFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not delete account. Try again or contact support.'**
  String get deleteAccountFailed;

  /// No description provided for @deleteAccountSuccess.
  ///
  /// In en, this message translates to:
  /// **'Your account was deleted.'**
  String get deleteAccountSuccess;

  /// No description provided for @deleteAccountSuccessModalTitle.
  ///
  /// In en, this message translates to:
  /// **'Account deleted'**
  String get deleteAccountSuccessModalTitle;

  /// No description provided for @deleteAccountSuccessModalBody.
  ///
  /// In en, this message translates to:
  /// **'Your HeyCaby rider profile and associated personal data from this app have been permanently removed.\n\nYou can uninstall the app from your phone whenever you wish—there is nothing else you need to do here.'**
  String get deleteAccountSuccessModalBody;

  /// No description provided for @deleteAccountSuccessModalCta.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get deleteAccountSuccessModalCta;

  /// No description provided for @deleteAccountNoSession.
  ///
  /// In en, this message translates to:
  /// **'No active session to delete.'**
  String get deleteAccountNoSession;

  /// No description provided for @deleteAccountNoPersonalDataMessage.
  ///
  /// In en, this message translates to:
  /// **'You have no personal information stored in our system. No email or data to delete. You can simply remove the app from your phone.'**
  String get deleteAccountNoPersonalDataMessage;

  /// No description provided for @deleteAccountNoEmailMessage.
  ///
  /// In en, this message translates to:
  /// **'You have no email associated with your account. There is no personal data to delete. You can simply remove the app from your phone.'**
  String get deleteAccountNoEmailMessage;

  /// No description provided for @dialogOk.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get dialogOk;

  /// No description provided for @blockDriver.
  ///
  /// In en, this message translates to:
  /// **'Block driver'**
  String get blockDriver;

  /// No description provided for @blockDriverConfirm.
  ///
  /// In en, this message translates to:
  /// **'You will not see new messages from this driver in this ride chat.'**
  String get blockDriverConfirm;

  /// No description provided for @reportDriverTitle.
  ///
  /// In en, this message translates to:
  /// **'Report this driver?'**
  String get reportDriverTitle;

  /// No description provided for @reportDriverBody.
  ///
  /// In en, this message translates to:
  /// **'HeyCaby will review this ride chat. You can add details below (optional).'**
  String get reportDriverBody;

  /// No description provided for @reportReasonHint.
  ///
  /// In en, this message translates to:
  /// **'What happened? (optional)'**
  String get reportReasonHint;

  /// No description provided for @chatReportSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Thanks — we received your report.'**
  String get chatReportSubmitted;

  /// No description provided for @chatMoreOptions.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get chatMoreOptions;

  /// No description provided for @chatBlockFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not update block list.'**
  String get chatBlockFailed;

  /// No description provided for @chatReportFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not send report. Try again.'**
  String get chatReportFailed;

  /// No description provided for @saveButton.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get saveButton;

  /// No description provided for @savedAddressesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your saved destinations'**
  String get savedAddressesSubtitle;

  /// No description provided for @savedPlacesSheetSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Tap a place to book, or save another below.'**
  String get savedPlacesSheetSubtitle;

  /// No description provided for @noSavedAddressesYet.
  ///
  /// In en, this message translates to:
  /// **'Build your shortcut list'**
  String get noSavedAddressesYet;

  /// No description provided for @noSavedAddressesEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Save home, work, the gym — or several homes (Mom, Dad, vacation). Same icon, different names.'**
  String get noSavedAddressesEmptyBody;

  /// No description provided for @addSavedAddress.
  ///
  /// In en, this message translates to:
  /// **'Save a place'**
  String get addSavedAddress;

  /// No description provided for @addSavedAddressSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'Save a new place'**
  String get addSavedAddressSheetTitle;

  /// No description provided for @savedAddressCategoryLabel.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get savedAddressCategoryLabel;

  /// No description provided for @savedAddressNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Name this place'**
  String get savedAddressNameLabel;

  /// No description provided for @savedAddressNameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Mom’s home, Office, Gym'**
  String get savedAddressNameHint;

  /// No description provided for @savedAddressSearchLabel.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get savedAddressSearchLabel;

  /// No description provided for @savedAddressSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search for an address'**
  String get savedAddressSearchHint;

  /// No description provided for @savedAddressesEmailPrompt.
  ///
  /// In en, this message translates to:
  /// **'Save your favourite addresses and book in one tap. Enter your email to get started.'**
  String get savedAddressesEmailPrompt;

  /// No description provided for @savedAddressesGetStarted.
  ///
  /// In en, this message translates to:
  /// **'Get started'**
  String get savedAddressesGetStarted;

  /// No description provided for @savedAddressesUnlocked.
  ///
  /// In en, this message translates to:
  /// **'Great! You can now save addresses.'**
  String get savedAddressesUnlocked;

  /// No description provided for @savedAddressLabelHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get savedAddressLabelHome;

  /// No description provided for @savedAddressLabelWork.
  ///
  /// In en, this message translates to:
  /// **'Work'**
  String get savedAddressLabelWork;

  /// No description provided for @savedAddressLabelGym.
  ///
  /// In en, this message translates to:
  /// **'Gym'**
  String get savedAddressLabelGym;

  /// No description provided for @savedAddressLabelCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get savedAddressLabelCustom;

  /// No description provided for @savedAddressesLimitReached.
  ///
  /// In en, this message translates to:
  /// **'You can save up to 10 places. Remove one to add another.'**
  String get savedAddressesLimitReached;

  /// No description provided for @deleteSavedAddress.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get deleteSavedAddress;

  /// No description provided for @searchFactDriversKeep100.
  ///
  /// In en, this message translates to:
  /// **'Drivers keep 100% of their earnings. HeyCaby takes zero commission per ride.'**
  String get searchFactDriversKeep100;

  /// No description provided for @searchFactNoSurgePricing.
  ///
  /// In en, this message translates to:
  /// **'No surge pricing. Ever. The price you see is the price you pay.'**
  String get searchFactNoSurgePricing;

  /// No description provided for @searchFactAllVerified.
  ///
  /// In en, this message translates to:
  /// **'Every licence, every insurance, every chauffeurspas — checked by us before going online.'**
  String get searchFactAllVerified;

  /// No description provided for @searchFactMarketplace.
  ///
  /// In en, this message translates to:
  /// **'Drivers heading home sometimes ride for less. Check the marketplace for the best price.'**
  String get searchFactMarketplace;

  /// No description provided for @searchFactZZP.
  ///
  /// In en, this message translates to:
  /// **'Every Caby driver is an independent professional. You ride with someone proud of their work.'**
  String get searchFactZZP;

  /// No description provided for @searchFactSaveAddresses.
  ///
  /// In en, this message translates to:
  /// **'Live in Rotterdam? Tap the house icon once and your destination is filled in. Always.'**
  String get searchFactSaveAddresses;

  /// No description provided for @searchFactPayHowYouWant.
  ///
  /// In en, this message translates to:
  /// **'Cash, Tikkie, card or invoice — your driver will tell you which options are available.'**
  String get searchFactPayHowYouWant;

  /// No description provided for @searchingTitle.
  ///
  /// In en, this message translates to:
  /// **'Finding you a Caby…'**
  String get searchingTitle;

  /// No description provided for @matchingTitleMarketplace.
  ///
  /// In en, this message translates to:
  /// **'Finding a marketplace Caby…'**
  String get matchingTitleMarketplace;

  /// No description provided for @matchingTitleScheduled.
  ///
  /// In en, this message translates to:
  /// **'Finding a Caby for your scheduled ride…'**
  String get matchingTitleScheduled;

  /// No description provided for @homeNearTermTitleInstant.
  ///
  /// In en, this message translates to:
  /// **'Finding your Caby'**
  String get homeNearTermTitleInstant;

  /// No description provided for @homeNearTermTitleMarketplace.
  ///
  /// In en, this message translates to:
  /// **'Marketplace request'**
  String get homeNearTermTitleMarketplace;

  /// No description provided for @homeNearTermTitleScheduled.
  ///
  /// In en, this message translates to:
  /// **'Scheduled ride'**
  String get homeNearTermTitleScheduled;

  /// No description provided for @homeNearTermOpenMatching.
  ///
  /// In en, this message translates to:
  /// **'We’re still matching you with a driver. Tap to view progress.'**
  String get homeNearTermOpenMatching;

  /// No description provided for @homeNearTermOpenMatchingHint.
  ///
  /// In en, this message translates to:
  /// **'Still matching — tap for trip details'**
  String get homeNearTermOpenMatchingHint;

  /// No description provided for @homeNearTermTripDetails.
  ///
  /// In en, this message translates to:
  /// **'Trip details'**
  String get homeNearTermTripDetails;

  /// No description provided for @rideMatchingTypeLabelInstant.
  ///
  /// In en, this message translates to:
  /// **'Instant ride'**
  String get rideMatchingTypeLabelInstant;

  /// No description provided for @rideMatchingTypeLabelMarketplace.
  ///
  /// In en, this message translates to:
  /// **'Marketplace'**
  String get rideMatchingTypeLabelMarketplace;

  /// No description provided for @rideMatchingTypeLabelScheduled.
  ///
  /// In en, this message translates to:
  /// **'Scheduled'**
  String get rideMatchingTypeLabelScheduled;

  /// No description provided for @activeSearchStopTitle.
  ///
  /// In en, this message translates to:
  /// **'Stop searching?'**
  String get activeSearchStopTitle;

  /// No description provided for @activeSearchStopBody.
  ///
  /// In en, this message translates to:
  /// **'We\'ll cancel this ride request. Drivers will stop seeing it, and you won\'t get driver notifications for it. You can book again anytime.'**
  String get activeSearchStopBody;

  /// No description provided for @activeSearchStopConfirm.
  ///
  /// In en, this message translates to:
  /// **'Stop ride'**
  String get activeSearchStopConfirm;

  /// No description provided for @activeSearchStopKeep.
  ///
  /// In en, this message translates to:
  /// **'Keep searching'**
  String get activeSearchStopKeep;

  /// No description provided for @homeNearTermUntilPickup.
  ///
  /// In en, this message translates to:
  /// **'Pickup in {remaining}'**
  String homeNearTermUntilPickup(String remaining);

  /// No description provided for @ridesScheduledMatchingSection.
  ///
  /// In en, this message translates to:
  /// **'Upcoming scheduled requests'**
  String get ridesScheduledMatchingSection;

  /// No description provided for @noDriverFoundCard.
  ///
  /// In en, this message translates to:
  /// **'No Caby found yet. What would you like to do?'**
  String get noDriverFoundCard;

  /// No description provided for @notifyMeWhenFound.
  ///
  /// In en, this message translates to:
  /// **'Notify Me'**
  String get notifyMeWhenFound;

  /// No description provided for @scheduleRideInstead.
  ///
  /// In en, this message translates to:
  /// **'Schedule'**
  String get scheduleRideInstead;

  /// No description provided for @activeSearchBannerSubtitle.
  ///
  /// In en, this message translates to:
  /// **'We\'ll notify you as soon as we find one.'**
  String get activeSearchBannerSubtitle;

  /// No description provided for @activeSearchCardHint.
  ///
  /// In en, this message translates to:
  /// **'HeyCaby is new and growing. This background search stops automatically after 30 minutes — you will not be left waiting silently.'**
  String get activeSearchCardHint;

  /// No description provided for @activeSearchMinutesLeft.
  ///
  /// In en, this message translates to:
  /// **'{minutes, plural, one{{minutes} minute left} other{{minutes} minutes left}}'**
  String activeSearchMinutesLeft(int minutes);

  /// No description provided for @noCabyFoundModalTitle.
  ///
  /// In en, this message translates to:
  /// **'Sorry, no Caby found 😔'**
  String get noCabyFoundModalTitle;

  /// No description provided for @noCabyFoundModalBody.
  ///
  /// In en, this message translates to:
  /// **'We are still a growing platform with a limited number of drivers. You can help us! Do you know a certified taxi driver? Share HeyCaby with them — together we make this platform bigger.'**
  String get noCabyFoundModalBody;

  /// No description provided for @shareHeyCabyInvite.
  ///
  /// In en, this message translates to:
  /// **'Share HeyCaby →'**
  String get shareHeyCabyInvite;

  /// No description provided for @shareHeyCabyMessage.
  ///
  /// In en, this message translates to:
  /// **'Try HeyCaby — fair rides, zero commission for drivers. {url}'**
  String shareHeyCabyMessage(String url);

  /// No description provided for @growthModalClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get growthModalClose;

  /// No description provided for @riderEmailVerificationSent.
  ///
  /// In en, this message translates to:
  /// **'We sent a 6-digit code to your email. Enter it below.'**
  String get riderEmailVerificationSent;

  /// No description provided for @riderSplashTagline.
  ///
  /// In en, this message translates to:
  /// **'Your caby, in minutes.'**
  String get riderSplashTagline;

  /// No description provided for @activeSearchWidget.
  ///
  /// In en, this message translates to:
  /// **'Searching for your Caby…'**
  String get activeSearchWidget;

  /// No description provided for @driverFoundWidget.
  ///
  /// In en, this message translates to:
  /// **'Caby found! Confirm your ride →'**
  String get driverFoundWidget;

  /// No description provided for @riderNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Your name'**
  String get riderNameLabel;

  /// No description provided for @scheduledRideLabel.
  ///
  /// In en, this message translates to:
  /// **'Scheduled for'**
  String get scheduledRideLabel;

  /// No description provided for @activeRideShareError.
  ///
  /// In en, this message translates to:
  /// **'Unable to share ride right now'**
  String get activeRideShareError;

  /// No description provided for @activeRideCancelConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'Do you really want to cancel the ride? Rebooking may not get you to your destination more quickly.'**
  String get activeRideCancelConfirmBody;

  /// No description provided for @activeRideWaitForDriver.
  ///
  /// In en, this message translates to:
  /// **'Wait for driver'**
  String get activeRideWaitForDriver;

  /// No description provided for @activeRidePickupNotes.
  ///
  /// In en, this message translates to:
  /// **'Any pickup notes?'**
  String get activeRidePickupNotes;

  /// No description provided for @activeRideChatSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Message your driver fast'**
  String get activeRideChatSubtitle;

  /// No description provided for @activeRideFoundingShort.
  ///
  /// In en, this message translates to:
  /// **'Founding'**
  String get activeRideFoundingShort;

  /// No description provided for @activeRideShareSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Share live trip link'**
  String get activeRideShareSubtitle;

  /// No description provided for @activeRideReportSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Submit ride report'**
  String get activeRideReportSubtitle;

  /// No description provided for @activeRideSupportSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Safety and help'**
  String get activeRideSupportSubtitle;

  /// No description provided for @activeRidePickupNotSet.
  ///
  /// In en, this message translates to:
  /// **'Pickup not set'**
  String get activeRidePickupNotSet;

  /// No description provided for @activeRideDestinationNotSet.
  ///
  /// In en, this message translates to:
  /// **'Destination not set'**
  String get activeRideDestinationNotSet;

  /// No description provided for @activeRideShareDetails.
  ///
  /// In en, this message translates to:
  /// **'Share ride details'**
  String get activeRideShareDetails;

  /// No description provided for @activeRideContactDriver.
  ///
  /// In en, this message translates to:
  /// **'Contact driver'**
  String get activeRideContactDriver;

  /// No description provided for @activeRideCategoryLabel.
  ///
  /// In en, this message translates to:
  /// **'Category: {category}'**
  String activeRideCategoryLabel(String category);

  /// No description provided for @activeRideCancelReasonLongPickup.
  ///
  /// In en, this message translates to:
  /// **'Long pickup time'**
  String get activeRideCancelReasonLongPickup;

  /// No description provided for @activeRideCancelReasonBetterAlternative.
  ///
  /// In en, this message translates to:
  /// **'Found better alternative'**
  String get activeRideCancelReasonBetterAlternative;

  /// No description provided for @activeRideCancelReasonDriverNotCloser.
  ///
  /// In en, this message translates to:
  /// **'Driver not getting closer'**
  String get activeRideCancelReasonDriverNotCloser;

  /// No description provided for @activeRideCancelReasonDriverAskedCancel.
  ///
  /// In en, this message translates to:
  /// **'Driver asked to cancel'**
  String get activeRideCancelReasonDriverAskedCancel;

  /// No description provided for @activeRideCancelReasonPriceDispute.
  ///
  /// In en, this message translates to:
  /// **'Price dispute with driver'**
  String get activeRideCancelReasonPriceDispute;

  /// No description provided for @activeRideCancelReasonOutsideAppPayment.
  ///
  /// In en, this message translates to:
  /// **'Driver asked to pay outside app'**
  String get activeRideCancelReasonOutsideAppPayment;

  /// No description provided for @activeRidePlateNumber.
  ///
  /// In en, this message translates to:
  /// **'Plate number'**
  String get activeRidePlateNumber;

  /// No description provided for @activeRideUnknownPlate.
  ///
  /// In en, this message translates to:
  /// **'UNKNOWN'**
  String get activeRideUnknownPlate;

  /// No description provided for @activeRideFoundingMember.
  ///
  /// In en, this message translates to:
  /// **'Founding Member'**
  String get activeRideFoundingMember;

  /// No description provided for @activeRideVerifyPlate.
  ///
  /// In en, this message translates to:
  /// **'Please verify this plate before entering the vehicle.'**
  String get activeRideVerifyPlate;

  /// No description provided for @openAction.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get openAction;

  /// No description provided for @rideReceiptTitle.
  ///
  /// In en, this message translates to:
  /// **'Ride receipt'**
  String get rideReceiptTitle;

  /// No description provided for @rideReceiptUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Receipt not available yet.'**
  String get rideReceiptUnavailable;

  /// No description provided for @rideReceiptSettlement.
  ///
  /// In en, this message translates to:
  /// **'Settlement'**
  String get rideReceiptSettlement;

  /// No description provided for @rideReceiptRideId.
  ///
  /// In en, this message translates to:
  /// **'Ride ID'**
  String get rideReceiptRideId;

  /// No description provided for @rideReceiptExpected.
  ///
  /// In en, this message translates to:
  /// **'Expected'**
  String get rideReceiptExpected;

  /// No description provided for @rideReceiptPaid.
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get rideReceiptPaid;

  /// No description provided for @rideReceiptMethod.
  ///
  /// In en, this message translates to:
  /// **'Method'**
  String get rideReceiptMethod;

  /// No description provided for @rideReceiptNote.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get rideReceiptNote;

  /// No description provided for @rideReceiptOutstanding.
  ///
  /// In en, this message translates to:
  /// **'Outstanding'**
  String get rideReceiptOutstanding;

  /// No description provided for @rideReceiptOverpaid.
  ///
  /// In en, this message translates to:
  /// **'Overpaid'**
  String get rideReceiptOverpaid;

  /// No description provided for @rideReceiptStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get rideReceiptStatus;

  /// No description provided for @rideReceiptSettlementComplete.
  ///
  /// In en, this message translates to:
  /// **'Settlement complete'**
  String get rideReceiptSettlementComplete;

  /// No description provided for @smartBundleRideTypeOptions.
  ///
  /// In en, this message translates to:
  /// **'Ride type options'**
  String get smartBundleRideTypeOptions;

  /// No description provided for @smartBundleEstimatedPrice.
  ///
  /// In en, this message translates to:
  /// **'Estimated price: {min} - {max}'**
  String smartBundleEstimatedPrice(String min, String max);

  /// No description provided for @smartBundleDriverPricingNote.
  ///
  /// In en, this message translates to:
  /// **'Drivers set their own prices. We\'ll match you with the best options nearby.'**
  String get smartBundleDriverPricingNote;

  /// No description provided for @smartBundleTapToHide.
  ///
  /// In en, this message translates to:
  /// **'Tap to hide ride classes'**
  String get smartBundleTapToHide;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en', 'nl'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
    case 'nl':
      return AppLocalizationsNl();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
