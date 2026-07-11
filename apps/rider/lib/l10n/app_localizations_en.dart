// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'HeyCaby';

  @override
  String get hello => 'Hello';

  @override
  String get rider => 'Rider';

  @override
  String get tagline => 'Connect with taxi drivers in your neighborhood.';

  @override
  String get continueButton => 'Continue';

  @override
  String get bookRide => 'Book a ride';

  @override
  String get whereAreYouGoing => 'Where are you going?';

  @override
  String get searchScheduleHint => 'Now, or pick a date & time';

  @override
  String get searchStartTypingHint =>
      'Type at least 3 characters to search the map.';

  @override
  String get searchBrowseSavedPlaces => 'Browse all saved places';

  @override
  String get searchBrowseRecentPlaces => 'Browse recent';

  @override
  String get searchRecentOnDeviceSection => 'Recent on this device';

  @override
  String get searchRecentOnDeviceSubtitle =>
      'Last 10 places you used on this phone — separate from saved places.';

  @override
  String get searchNoLocalRecentsYet =>
      'No recent addresses yet. Search for a place and select it — we keep the last 10 here so the next search can be faster.';

  @override
  String get searchLocalMatchesHeader => 'Matches on this device';

  @override
  String get whereTo => 'Where to?';

  @override
  String get homeDestinationPrompt => 'Where do you want to go?';

  @override
  String get homeContinue => 'Continue';

  @override
  String get homeSmartOptionsTitle => 'How do you want to ride?';

  @override
  String get homeBestPriceTitle => 'TAXI TERUG';

  @override
  String get homeBestPriceSubtitle => 'Find drivers already heading your way.';

  @override
  String get homeTaxiTerugTitle => 'TAXI TERUG';

  @override
  String get homeTaxiTerugSubtitle => 'Find drivers already heading your way.';

  @override
  String get taxiTerugOfferHeadline =>
      'Ride with taxis already heading your way.';

  @override
  String get taxiTerugIntroBody =>
      'Name your price. Drivers already travelling your direction can accept your offer.';

  @override
  String get taxiTerugFareExplanation =>
      'Taxi Terug means the taxi is already going your direction. The fare depends on the driver\'s tariff — not a platform discount.';

  @override
  String get taxiTerugDriversAcceptHint =>
      'Independent drivers decide whether to accept your offer.';

  @override
  String get taxiTerugCandidatesTitle => 'Taxis heading your way';

  @override
  String get taxiTerugCandidatesEmpty =>
      'No taxis heading your way yet. Name your price below — we\'ll notify matching drivers.';

  @override
  String taxiTerugCandidatesSubtitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count taxis match your route',
      one: '1 taxi matches your route',
    );
    return '$_temp0';
  }

  @override
  String taxiTerugCandidateHeading(String destination) {
    return 'Heading to $destination';
  }

  @override
  String taxiTerugCandidateEta(int minutes) {
    return '$minutes min to pickup';
  }

  @override
  String taxiTerugCandidateMatch(int score) {
    return '$score% match';
  }

  @override
  String taxiTerugCandidateFareRange(String minFare, String maxFare) {
    return '$minFare – $maxFare';
  }

  @override
  String get taxiTerugWaitToleranceTitle => 'How long can you wait?';

  @override
  String get taxiTerugWaitToleranceBody =>
      'Taxi Terug drivers may finish a ride nearby first. We only show taxis that can reach you within your wait time.';

  @override
  String taxiTerugWaitMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String get taxiTerugDelayedPickupAck =>
      'I understand pickup may be later while the taxi finishes its current ride.';

  @override
  String get taxiTerugConfirmDelayedPickup =>
      'Please confirm you understand the delayed pickup time.';

  @override
  String taxiTerugCandidatePickupWindow(int minMinutes, int maxMinutes) {
    return 'Pickup available in $minMinutes–$maxMinutes min';
  }

  @override
  String get taxiTerugCandidateFinishingRide =>
      'Driver is finishing a nearby ride first.';

  @override
  String taxiTerugCandidateDepartsAt(String time) {
    return 'Departs at $time';
  }

  @override
  String get taxiTerugQueuedConfirmed => 'Taxi Terug confirmed';

  @override
  String get taxiTerugQueuedWaitingForDriver =>
      'Your driver is finishing their current ride first.';

  @override
  String get homeScheduleLaterTitle => 'Schedule later';

  @override
  String get homeScheduleLaterSubtitle =>
      'Pick a pickup time that works for you.';

  @override
  String get homePopularAirportsTitle => 'Popular';

  @override
  String get homeRecentTrips => 'Recent trips';

  @override
  String get homeGreetingMorning => 'Good morning,';

  @override
  String get homeGreetingAfternoon => 'Good afternoon,';

  @override
  String get homeGreetingEvening => 'Good evening,';

  @override
  String get homeEnterDestination => 'Enter your destination';

  @override
  String get homeNoTaxisNearbySubtitle =>
      'You can still request a ride. We will notify you when a driver accepts.';

  @override
  String get homeSupplyNoneTitle => 'No drivers near you';

  @override
  String get homeSupplyNoneSubtitle =>
      'Try TAXI TERUG or schedule a ride for later.';

  @override
  String homeSupplyNearbyTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count drivers nearby',
      one: '1 driver nearby',
    );
    return '$_temp0';
  }

  @override
  String homeSupplyNearbySubtitle(String distanceKm) {
    return 'Closest about $distanceKm km away';
  }

  @override
  String get homeSupplyNearbySubtitleShort =>
      'Usually a quick pickup from here';

  @override
  String get homeSupplyZoneEmptyTitle => 'No drivers in your zone';

  @override
  String homeSupplyZoneEmptySubtitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count drivers within 10 km',
      one: '1 driver within 10 km',
    );
    return '$_temp0';
  }

  @override
  String get homeSupplyFarTitle => 'Drivers are further away';

  @override
  String homeSupplyFarSubtitle(int count, String distanceKm) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count drivers online',
      one: '1 driver online',
    );
    return '$_temp0 · closest about $distanceKm km';
  }

  @override
  String homeFavoriteSupplyTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count of your favourite drivers are online',
      one: '1 of your favourite drivers is online',
    );
    return '$_temp0';
  }

  @override
  String homeFavoriteSupplySubtitle(String distanceKm) {
    return 'Closest about $distanceKm km away · Book now';
  }

  @override
  String get homeFavoriteSupplySubtitleShort => 'Nearby now · Book now';

  @override
  String get homeRideAgainTitle => 'Ride again';

  @override
  String get homeRideAgainViewAll => 'View all';

  @override
  String get homeRideAgainBookAgain => 'Book again';

  @override
  String get homeRideAgainUsuallyAvailable => 'Usually available';

  @override
  String get homeRideAgainAvailableNow => 'Available now';

  @override
  String homeRideAgainDriverStats(String rating, int count) {
    return '$rating ★ • $count rides';
  }

  @override
  String get homeRecentPlacesTitle => 'Recent places';

  @override
  String get homeRecentPlacesEdit => 'Edit';

  @override
  String get savedTripsTitle => 'Saved trips';

  @override
  String get homeCompleteProfile => 'Complete profile';

  @override
  String get vehicleCategoryTitle => 'Do you need a specific vehicle?';

  @override
  String get vehicleSelectUpToThree =>
      'Select up to 3 types with drivers nearby';

  @override
  String get vehicleMaxCategoriesSelected =>
      'You can select up to 3 vehicle types';

  @override
  String get homeAirportChipSchiphol => 'Schiphol';

  @override
  String get homeAirportChipRotterdam => 'Rotterdam Airport';

  @override
  String get homeAirportChipEindhoven => 'Eindhoven';

  @override
  String get homeAirportChipBrussels => 'Brussels Airport';

  @override
  String get pickup => 'Pickup';

  @override
  String get destination => 'Destination';

  @override
  String get findMyDriver => 'Find my driver';

  @override
  String get searching => 'Searching for a driver...';

  @override
  String get driverAssigned => 'Driver on the way';

  @override
  String driverReturnTripDiscount(int pct) {
    return '$pct% return ride discount';
  }

  @override
  String get driverArrived => 'Your driver has arrived';

  @override
  String get tripInProgress => 'Trip in progress';

  @override
  String get tripComplete => 'Trip complete';

  @override
  String get cancel => 'Cancel';

  @override
  String get confirm => 'Confirm';

  @override
  String get confirmDestination => 'Confirm destination';

  @override
  String get rateYourDriver => 'Rate your driver';

  @override
  String get howWasYourRide => 'How was your ride?';

  @override
  String get ratingAddNoteOptional => 'Add a note (optional)';

  @override
  String get whatDidYouLike => 'What did you like?';

  @override
  String get additionalFeedback => 'Additional feedback (optional)';

  @override
  String get tellUsMore => 'Tell us more about your experience...';

  @override
  String get submitRating => 'Submit Rating';

  @override
  String get tipDriverTitle => 'Tip your driver';

  @override
  String get tipDriverSubtitle =>
      '100% goes to your driver. Added after the ride.';

  @override
  String get tipAmountCustom => 'Custom';

  @override
  String get tipNoTip => 'No tip';

  @override
  String get tipSubmitWithTip => 'Submit Rating + Tip';

  @override
  String get tipAdded => 'Tip added';

  @override
  String get ratingCategorySectionTitle => 'Rate specific areas';

  @override
  String get ratingCategorySubtitle =>
      'Each area uses 1–5 stars. They start matching your overall rating — adjust any that differ.';

  @override
  String get ratingDimensionPunctuality => 'Punctuality';

  @override
  String get ratingDimensionCleanliness => 'Cleanliness';

  @override
  String get ratingDimensionAttitude => 'Attitude';

  @override
  String get ratingDimensionDrivingSafety => 'Driving safety';

  @override
  String get ratingDimensionCommunication => 'Communication';

  @override
  String get recentDestinations => 'Recent Destinations';

  @override
  String recentDestinationsShowMore(int count) {
    return 'Show $count more';
  }

  @override
  String get recentDestinationsShowLess => 'Show less';

  @override
  String get recentDestinationRemoveHint => 'Remove from recents';

  @override
  String get recentDestinationRemoveFailed =>
      'Couldn\'t remove this place. Try again.';

  @override
  String get whatWentWrong => 'What went wrong?';

  @override
  String get helpUsUnderstand =>
      'Help us understand the issue so we can improve';

  @override
  String get additionalDetails => 'Additional details';

  @override
  String get pleaseProvideMoreDetails =>
      'Please provide more details about the issue...';

  @override
  String get submitReport => 'Submit Report';

  @override
  String get reportSubmitted => 'Report submitted successfully';

  @override
  String get reportSubmitFailed => 'Failed to submit report';

  @override
  String get fareEstimate => 'Estimated fare';

  @override
  String get vehicleLabel => 'Vehicle';

  @override
  String scheduledFor(String date) {
    return 'Scheduled for $date';
  }

  @override
  String get noDriversNearby => 'No drivers nearby';

  @override
  String get connectionProblem => 'Connection problem. Please try again.';

  @override
  String get rideBookingFailed =>
      'Couldn’t start your ride — authorization was rejected by the server. Please refresh your session (log out and log in), then try Find driver again.';

  @override
  String get locationPermissionRequired =>
      'Location access is needed to set pickup and find nearby drivers.';

  @override
  String get locationRequired => 'Location required';

  @override
  String get locationRequiredMessage =>
      'HeyCaby needs your location to set accurate pickup points, find nearby drivers, and give reliable arrival times. Without location access we cannot serve you well and you cannot book rides.';

  @override
  String get enableLocation => 'Enable Location';

  @override
  String get tryAgain => 'Try again';

  @override
  String get enterAddressManually => 'Enter address manually';

  @override
  String get home => 'Home';

  @override
  String get rides => 'Rides';

  @override
  String get account => 'Account';

  @override
  String get tellAFriendNavLabel => 'Community';

  @override
  String get tellAFriendNavSemanticLabel =>
      'Grow your city — build the HeyCaby community';

  @override
  String get tellAFriendScreenTitle => 'Grow Your City';

  @override
  String get tellAFriendSharePrompt =>
      'Share HeyCaby with people who need rides in your city. Every new rider helps local taxi drivers stay busy.';

  @override
  String get tellAFriendHeroTitle => 'Invite friends';

  @override
  String get tellAFriendHeroSubtitle => 'Share your link in one tap.';

  @override
  String get tellAFriendBodyLine1 => 'Grow your ride circle nearby.';

  @override
  String get tellAFriendBodyLine2 =>
      'More trusted riders can mean quicker matches for everyone.';

  @override
  String get tellAFriendFriendsInvitedLabel => 'Friends invited';

  @override
  String get tellAFriendFriendsInvitedZeroHint => 'No joins yet — share below.';

  @override
  String get tellAFriendRewardTitle => 'Why help?';

  @override
  String get tellAFriendRewardBullet1 => 'More riders nearby';

  @override
  String get tellAFriendRewardBullet2 => 'More ride requests for drivers';

  @override
  String get tellAFriendRewardBullet3 => 'Shorter waiting times';

  @override
  String get tellAFriendRewardBullet4 => 'Stronger taxi community';

  @override
  String get tellAFriendInviteLinkLabel => 'App Store link';

  @override
  String get tellAFriendWebsiteLinkLabel => 'Share link';

  @override
  String get tellAFriendLinkResolving => 'Getting your short invite link…';

  @override
  String get tellAFriendCopyLink => 'Copy link';

  @override
  String get tellAFriendShareLink => 'Share HeyCaby';

  @override
  String get tellAFriendShowQr => 'QR code';

  @override
  String get tellAFriendQrTitle => 'Scan to join HeyCaby';

  @override
  String get tellAFriendQrHint =>
      'Scanning opens the HeyCaby Rider app on the App Store. Use Share or Copy to send your download link.';

  @override
  String get tellAFriendSocialProof =>
      'Thanks for helping build the largest independent taxi network in the Netherlands.';

  @override
  String get tellAFriendShareDoneSnackbar => 'Thanks for sharing HeyCaby!';

  @override
  String get tellAFriendLinkCopied => 'Copied — ready to paste anywhere';

  @override
  String get tellAFriendShareSubject => 'Join HeyCaby — grow your city';

  @override
  String get tellAFriendShareMessage =>
      'Download HeyCaby Rider — the independent taxi app for the Netherlands:';

  @override
  String get tellAFriendLinkUnavailable => 'App Store link not configured';

  @override
  String get tellAFriendLinkUnavailableHint =>
      'Add RIDER_IOS_APP_STORE_URL to your build environment, then rebuild the app.';

  @override
  String growCityHeroTitle(String cityName) {
    return 'Grow HeyCaby in $cityName';
  }

  @override
  String get growCityHeroBody1 =>
      'Invite friends and family who need reliable taxis in your city.';

  @override
  String get growCityHeroBody2 =>
      'More riders nearby means more ride requests for local drivers and shorter waits for everyone.';

  @override
  String get growCityHeroMission =>
      'Help us build the largest independent taxi network in the Netherlands.';

  @override
  String growCityCommunityTitle(String cityName) {
    return '$cityName community';
  }

  @override
  String get growCityDriversLabel => 'Drivers';

  @override
  String get growCityRidersLabel => 'Riders';

  @override
  String get growCityMonthlyRidersLabel => 'Monthly riders';

  @override
  String get growCityMonthlyDriversLabel => 'Monthly drivers';

  @override
  String get growCityMilestoneLabel => 'Next milestone';

  @override
  String get growCityDriverCapLabel => 'Driver network cap';

  @override
  String get growCityRiderCapLabel => 'Monthly rider vision';

  @override
  String growCityProgressCount(String current, String milestone) {
    return '$current / $milestone';
  }

  @override
  String growCityMilestoneHint(String remaining, String milestone) {
    return '$remaining monthly riders until we celebrate $milestone.';
  }

  @override
  String get growCityFinalGoalReached =>
      'We reached 1 million monthly riders in the Netherlands. Thank you for growing HeyCaby with us.';

  @override
  String get growCityMilestoneCelebrationTitle => 'Milestone reached!';

  @override
  String growCityMilestoneCelebrationBody(String milestone) {
    return 'The HeyCaby community just hit $milestone monthly riders in the Netherlands. Thank you for helping us grow — on to the next milestone!';
  }

  @override
  String get growCityMilestoneCelebrationCta => 'Let\'s keep growing';

  @override
  String get growCityImpactTitle => 'Your impact';

  @override
  String get growCityPeopleInvited => 'Riders invited';

  @override
  String get growCityJoined => 'Joined';

  @override
  String get growCityCompletedRides => 'Completed rides';

  @override
  String get growCityBadgesTitle => 'Community badges';

  @override
  String get growCityBadgeSupporter => 'Community Supporter';

  @override
  String get growCityBadgeBuilder => 'Community Builder';

  @override
  String get growCityBadgeAmbassador => 'City Ambassador';

  @override
  String get growCityBadgeTopPromoter => 'Top Promoter';

  @override
  String get growCityRideBadgesTitle => 'Ride milestones';

  @override
  String get growCityRideBadgeFirstRide => 'First Ride';

  @override
  String get growCityRideBadgeRegular => 'Regular';

  @override
  String get growCityRideBadgeDedicated => 'Dedicated';

  @override
  String get growCityRideBadgeLegend => 'HeyCaby Legend';

  @override
  String growCityStreakWeeks(int count) {
    return '$count week streak';
  }

  @override
  String growCityProgressToRideBadge(String badge) {
    return 'Progress to $badge';
  }

  @override
  String growCityProgressToInviteBadge(String badge) {
    return 'Progress to $badge';
  }

  @override
  String get growCityWhyHelpTitle => 'Why help?';

  @override
  String get growCityWhyHelpBullet1 => 'More riders nearby';

  @override
  String get growCityWhyHelpBullet2 => 'More work for local taxi drivers';

  @override
  String get growCityWhyHelpBullet3 => 'Shorter waiting times';

  @override
  String get growCityWhyHelpBullet4 => 'Stronger taxi community';

  @override
  String get growCityPitchLine => 'Invite people who need taxis in your city.';

  @override
  String get growCityPitchBenefit =>
      'More riders nearby → more drivers and shorter waits.';

  @override
  String growCityProgressHeader(
      String region, String current, String milestone) {
    return '$region · $current / $milestone monthly riders';
  }

  @override
  String growCityCompactDrivers(String count) {
    return '$count drivers';
  }

  @override
  String growCityCompactRiders(String count) {
    return '$count riders';
  }

  @override
  String get growCityLearnMore => 'Why this helps';

  @override
  String growCityImpactCompact(int invited, int joined) {
    return '$invited invited · $joined joined';
  }

  @override
  String get growCityWhySheetDone => 'Got it';

  @override
  String get growCityRegionNetherlands => 'Netherlands';

  @override
  String get iosUpdateRequiredTitle => 'Please update iOS';

  @override
  String iosUpdateRequiredBody(String minimumVersion, String currentVersion) {
    return 'HeyCaby requires iOS $minimumVersion or later. This iPhone is on iOS $currentVersion. Open Settings → General → Software Update to install the latest iOS your device supports.';
  }

  @override
  String iosUpdateRequiredFooter(String minimumVersion) {
    return 'If your device cannot upgrade to iOS $minimumVersion, you will need a newer iPhone to use HeyCaby.';
  }

  @override
  String get scheduledCommitmentDisclosure =>
      'Your driver may ask for a small confirmation contribution of up to €5 up to 40 minutes before your ride. It is deducted from your trip total. If you or the driver cancel afterward, the usual cancellation rules apply.';

  @override
  String get prerideBannerTitle => 'Please confirm your ride';

  @override
  String get prerideBannerSubtitle =>
      'Your driver is waiting for confirmation before pickup.';

  @override
  String get prerideOpenTikkie => 'Open Tikkie';

  @override
  String get prerideConfirmAttending => 'I\'m coming';

  @override
  String get prerideConfirmedThanks => 'Thanks — you\'re confirmed.';

  @override
  String get myRides => 'My rides';

  @override
  String get myDrivers => 'My Drivers';

  @override
  String get myDriversHomeSubtitle => 'Ride with someone you trust';

  @override
  String get favouriteDrivers => 'My Drivers';

  @override
  String get favouriteDriversSubtitle => 'Your trusted driver network';

  @override
  String favouriteDriversSubtitleWithCount(int count) {
    return '$count drivers in your network';
  }

  @override
  String get noFavouritesYet => 'No favourites yet';

  @override
  String get saveDriverLabel => 'Save this driver';

  @override
  String get saveDriverSubtitle =>
      'Add to your trusted drivers for quick rebooking';

  @override
  String get saveDriverModalTitle => 'Save this driver?';

  @override
  String get saveDriverModalBody =>
      'You gave a great rating. Add this driver to your favourites for quicker booking next time.';

  @override
  String get saveDriverModalConfirm => 'Save to favourites';

  @override
  String get saveDriverModalDismiss => 'Not now';

  @override
  String get saveDriverWillSaveHint =>
      'Will be saved to your favourites when you submit';

  @override
  String get driverSaved => 'Driver saved to your favourites';

  @override
  String get removeFromFavorites => 'Remove from favourites';

  @override
  String get driverRemoved => 'Driver removed from favourites';

  @override
  String get driverOffline => 'Offline';

  @override
  String get driverAvailableNow => 'Available now';

  @override
  String get favoritesLimitReached =>
      'You already have 10 favourite drivers. Remove one before adding a new driver.';

  @override
  String get paymentMethod => 'Payment method';

  @override
  String get cash => 'Cash';

  @override
  String get pin => 'PIN';

  @override
  String get tikkie => 'Tikkie';

  @override
  String get instantRide => 'Instant';

  @override
  String get scheduledRide => 'Schedule';

  @override
  String get marketplaceStepRoute => 'Route';

  @override
  String get marketplaceStepOffer => 'Your offer';

  @override
  String get marketplaceStepPost => 'Post';

  @override
  String get marketplaceIntroBody =>
      'Set your price. Drivers choose to accept, counter, or pass. You pick who to ride with.';

  @override
  String get marketplace => 'Marketplace';

  @override
  String get marketplaceTagline => 'Drivers compete for your trip.';

  @override
  String get makeAnOffer => 'Marketplace';

  @override
  String get marketplacePostRequest => 'Post request';

  @override
  String get marketplaceOfferHeadline => 'Choose what you want to pay.';

  @override
  String get marketplaceOfferExplanation =>
      'Drivers already travelling in your direction can accept your offer or suggest another price.';

  @override
  String get marketplaceDriversAcceptHint =>
      'Drivers can accept, counter, or ignore — HeyCaby does not set the fare.';

  @override
  String marketplaceDriversOnline(int count) {
    return '$count drivers online';
  }

  @override
  String get marketplaceWhereAreYouGoing => 'Where are you going?';

  @override
  String get marketplaceYouAreHere => 'You\'re here';

  @override
  String marketplaceYouAreHereIn(String area) {
    return 'You\'re here in $area';
  }

  @override
  String marketplaceYouAreHereOn(String street) {
    return 'You\'re on $street';
  }

  @override
  String get marketplaceLocatingYou => 'Finding your location…';

  @override
  String get marketplaceLocationNeeded =>
      'Turn on location to see where you are';

  @override
  String get marketplaceNameYourPrice => 'Name your price';

  @override
  String get marketplaceNameYourPriceSubtitle =>
      'Drivers will see your offer and respond.';

  @override
  String marketplaceTypicalRangeLabel(String range) {
    return 'Typical range: $range';
  }

  @override
  String get marketplaceControlBanner =>
      'You\'re in control. Drivers can accept, counter, or ignore your offer.';

  @override
  String get marketplaceFasterOffersTip =>
      'Want faster offers? Increase your price to get more responses.';

  @override
  String get marketplaceEnterCustomPrice => 'Tap to type any amount';

  @override
  String get marketplacePriceHint => '50';

  @override
  String marketplaceBidRangeHint(int min, int max) {
    return 'You can offer between €$min and €$max';
  }

  @override
  String get marketplaceTypicalFareTitle => 'Typical fare';

  @override
  String get marketplaceYourOfferTitle => 'Your offer';

  @override
  String get marketplaceRequestOffers => 'Post request';

  @override
  String get marketplaceMatchingTitle => 'Marketplace';

  @override
  String get marketplaceMatchingHeadline => 'Searching for drivers…';

  @override
  String get marketplaceMatchingNotifySubtitle =>
      'We\'ll notify you when offers arrive.';

  @override
  String marketplaceDriversReceivedRequest(int count) {
    return '$count drivers received your request';
  }

  @override
  String get marketplaceExpectedWait => 'Expected wait: 1 – 2 min';

  @override
  String get marketplaceOffersFromDrivers => 'Offers from drivers';

  @override
  String get marketplaceRecommended => 'Recommended';

  @override
  String get marketplaceViewProfile => 'View profile';

  @override
  String get marketplaceOfferAcceptsYourPrice => 'Accepts your offer';

  @override
  String get marketplaceOfferCounterLabel => 'Counter offer';

  @override
  String get marketplaceOffersExpireIn => 'Offers expire in';

  @override
  String get marketplaceBoostOffer => 'Boost your offer';

  @override
  String get marketplaceBoostOfferSubtitle =>
      'Increase price to get more offers';

  @override
  String get marketplaceCancelRequest => 'Cancel request';

  @override
  String get marketplaceCancelRequestConfirm =>
      'Drivers will stop seeing your offer. Cancel this request?';

  @override
  String get marketplaceReceiveChooseTitle => 'Receive & choose offers';

  @override
  String get marketplaceReceiveChooseBullet1 => 'Drivers accept or counter';

  @override
  String get marketplaceReceiveChooseBullet2 => 'Compare price, rating, ETA';

  @override
  String get marketplaceReceiveChooseBullet3 => 'Choose the best match';

  @override
  String marketplaceMatchingSubhead(int nearby, int received) {
    return '$nearby nearby · $received offers received';
  }

  @override
  String get marketplaceMatchingWaiting => 'Waiting for driver responses';

  @override
  String get marketplaceMatchingWaitingBody =>
      'Independent drivers can accept your price, counter, or ignore. You choose who to ride with.';

  @override
  String marketplaceOfferAccepts(String price) {
    return 'Accepts $price';
  }

  @override
  String marketplaceOfferCounter(String price) {
    return 'Counter $price';
  }

  @override
  String marketplaceOfferMinutesAway(int minutes) {
    return '$minutes min away';
  }

  @override
  String marketplaceOfferExpiresIn(String time) {
    return 'Offer expires $time';
  }

  @override
  String get marketplaceDriverUsuallyAccepts => 'Usually accepts rider prices';

  @override
  String get marketplaceDriverOftenCounters => 'Often sends counter offers';

  @override
  String get marketplaceDriverMayCounter => 'May accept or counter your offer';

  @override
  String get declineBid => 'Decline';

  @override
  String get marketplaceDriverScopeTitle => 'Who should see your request?';

  @override
  String get marketplaceDriverScopeEveryone => 'Everyone';

  @override
  String get marketplaceDriverScopeMyDriversFirst => 'My Drivers first';

  @override
  String get marketplaceDriverScopeMyDriversOnly => 'My Drivers only';

  @override
  String get marketplaceAcceptanceGood => 'Good chance of acceptance';

  @override
  String get marketplaceAcceptanceFair =>
      'Fair offer — drivers may accept or counter';

  @override
  String get marketplaceAcceptanceLow =>
      'Offer is quite low — expect counter offers';

  @override
  String get marketplaceDemandLowTitle => 'Low demand';

  @override
  String get marketplaceDemandHighTitle => 'High demand';

  @override
  String get marketplaceDemandLowHint =>
      'Drivers are likely to accept lower offers.';

  @override
  String get marketplaceDemandHighHint =>
      'Offering slightly more may get faster responses.';

  @override
  String get marketplaceSubtitle =>
      'Choose your price — independent drivers decide.';

  @override
  String get homeAirportBookingTitle => 'Airport drop-off';

  @override
  String get homeAirportBookingSubtitle =>
      'Schiphol, Brussels, Luxembourg & more — one tap';

  @override
  String get homeAirportBookingBadge => 'Fast';

  @override
  String get airportBookingScreenTitle => 'Airport drop-off';

  @override
  String get airportBookingScreenSubtitle =>
      'Choose your terminal. Pickup stays your current location unless you change it in the next step.';

  @override
  String get airportBookingSearchHint => 'Search by airport, city, or code';

  @override
  String get airportBookingNoResults => 'No airport matches that search.';

  @override
  String get airportSectionNetherlands => 'NETHERLANDS';

  @override
  String get airportSectionBelgium => 'BELGIUM';

  @override
  String get airportSectionLuxembourg => 'LUXEMBOURG';

  @override
  String get favouritesOnly => 'Favorite drivers first';

  @override
  String get offerFare => 'Offer your fare';

  @override
  String get bids => 'Bids';

  @override
  String get acceptBid => 'Accept';

  @override
  String get notifyMe => 'Notify me when available';

  @override
  String get rideHistory => 'Ride history';

  @override
  String get reportDriver => 'Report driver';

  @override
  String get support => 'Support';

  @override
  String get settings => 'Settings';

  @override
  String get language => 'Language';

  @override
  String get languageFollowDevice => 'Device language';

  @override
  String get languageFollowDeviceSubtitle => 'Matches your phone settings';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageDutch => 'Nederlands';

  @override
  String get languageArabic => 'العربية';

  @override
  String get theme => 'Theme';

  @override
  String get homeAddress => 'Home address';

  @override
  String get savedAddresses => 'Saved places';

  @override
  String get logout => 'Log out';

  @override
  String distance(String km) {
    return '$km km';
  }

  @override
  String duration(String min) {
    return '$min min';
  }

  @override
  String get bestPrice => 'Best price';

  @override
  String get howHeyCabyWorks => 'How HeyCaby works';

  @override
  String get zeroCommission => 'Zero commission — fair for everyone';

  @override
  String get driverEarns100 => 'Your driver earns 100% of the fare';

  @override
  String get noShowWarning =>
      'Please only book when you\'re ready at your location';

  @override
  String get communityPledge =>
      'Only book when you\'re ready and at your location. Our drivers pay for fuel on every call-out.';

  @override
  String get namePlaceholder => 'What should the driver call you?';

  @override
  String get welcomeProfileModalTitle => 'Welcome to HeyCaby!';

  @override
  String get welcomeProfileModalBody =>
      'To make your journey easy and fast, we recommend setting up your profile. It\'ll make booking much faster.';

  @override
  String get setUpProfileNow => 'Set up now';

  @override
  String get welcomeDriverCallYouModalTitle =>
      'What should the driver call you?';

  @override
  String get welcomeSkipDriverName => 'Not now';

  @override
  String get onboardingProfileBannerMessage =>
      'Complete your profile to make booking faster.';

  @override
  String get saveAndContinue => 'Save & continue';

  @override
  String get onboardingNextAddEmail =>
      'Next: add your email to save addresses and favourites.';

  @override
  String get onboardingNameRequired => 'Enter your name to continue.';

  @override
  String riderProfileCompletionPercent(String percent) {
    return 'Profile $percent% complete';
  }

  @override
  String get riderProfileCompleteTitle => 'Profile complete';

  @override
  String get riderProfileMeterName => 'Booking name';

  @override
  String get riderProfileMeterEmail => 'Email';

  @override
  String get riderProfileHomeNudgeTitle => 'Finish your profile';

  @override
  String get riderProfileHomeNudgeBoth =>
      'Add your name and email on Account — each counts for 50%.';

  @override
  String get riderProfileHomeNudgeNameOnly =>
      'Add your booking name on Account to reach 100%.';

  @override
  String get riderProfileHomeNudgeEmailOnly =>
      'Add your email on Account to reach 100%.';

  @override
  String get yourRoute => 'Your route';

  @override
  String get rideTimeline => 'Ride progress';

  @override
  String get rideTimelineStepAccepted => 'Driver accepted';

  @override
  String get rideTimelineStepEnRoute => 'On the way to pickup';

  @override
  String get rideTimelineStepArrived => 'At pickup';

  @override
  String get rideTimelineStepInProgress => 'Trip in progress';

  @override
  String get rideTimelineStepCompleted => 'Trip complete';

  @override
  String get howDoYouWantToBook => 'How do you want to book?';

  @override
  String get howWillYouPay => 'How will you pay?';

  @override
  String get laterButton => 'Later';

  @override
  String get tripSummary => 'Trip summary';

  @override
  String get loading => 'Loading...';

  @override
  String get retry => 'Retry';

  @override
  String get error => 'Something went wrong';

  @override
  String get driverOnTheWay => 'Driver on the way';

  @override
  String eta(String min) {
    return 'ETA $min min';
  }

  @override
  String get shareRide => 'Share ride';

  @override
  String get chat => 'Chat';

  @override
  String get reportIssue => 'Report issue';

  @override
  String get rideComplete => 'Ride complete';

  @override
  String get leaveAComment => 'Leave a comment (optional)';

  @override
  String get submit => 'Submit';

  @override
  String get skip => 'Skip';

  @override
  String get back => 'Back';

  @override
  String get next => 'Next';

  @override
  String get notifyMeWhenDriverFound =>
      'You\'ll be notified when a driver is found';

  @override
  String get cancelBookingTitle => 'Cancel booking?';

  @override
  String get cancelBookingMessage =>
      'Are you sure you want to cancel? Your ride details will be lost.';

  @override
  String get keepGoing => 'Keep going';

  @override
  String get nameSavedSuccess => 'Name saved successfully';

  @override
  String get ridesFilterActive => 'Active';

  @override
  String get ridesFilterAll => 'All';

  @override
  String get ridesFilterBidding => 'Bidding';

  @override
  String get ridesFilterCompleted => 'Completed';

  @override
  String get ridesFilterCancelled => 'Cancelled';

  @override
  String get ridesScreenSubtitle =>
      'Scheduled trips, live matching, and your history';

  @override
  String get ridesTabUpcoming => 'Upcoming';

  @override
  String get ridesTabHistory => 'History';

  @override
  String get upcomingRideDetailTitle => 'Trip details';

  @override
  String get upcomingRideMatchingProgressTitle => 'Driver search in progress';

  @override
  String get upcomingRideMatchingProgressBody =>
      'We\'re matching you with nearby drivers. Open the live search screen for the full radar view and live updates.';

  @override
  String get upcomingRideOpenLiveSearch => 'Open live search';

  @override
  String get upcomingRideEditBookAgain => 'Change addresses';

  @override
  String get upcomingRideEditBookAgainSubtitle =>
      'This cancels your current request so you can book again with a new pickup or destination.';

  @override
  String get upcomingRideGoToActive => 'Go to live ride';

  @override
  String get upcomingRideDriverSection => 'Driver';

  @override
  String get ridesUpcomingScheduledBadge => 'Scheduled';

  @override
  String get ridesUpcomingMatchingBadge => 'Matching';

  @override
  String get ridesUpcomingEmptyTitle => 'Nothing upcoming';

  @override
  String get ridesUpcomingEmptyBody =>
      'Book a ride or schedule one for later — it will show up here while we find your Caby.';

  @override
  String get ridesHistorySectionTitle => 'Past activity';

  @override
  String get searchAddressCouldNotResolve =>
      'We couldn’t use that address. Try another result or search again.';

  @override
  String get saveBookingForLater => 'Save for later';

  @override
  String get searchAddressesContinue => 'Continue';

  @override
  String get saveTripForNextTimeLabel => 'Save this trip for next time';

  @override
  String get saveTripForNextTimeSubtitle =>
      'Saves pickup and destination to your recent places when you’re signed in.';

  @override
  String get scheduledMatchingHeadline => 'We’ll look for a driver for you.';

  @override
  String get scheduledMatchingSubhead =>
      'Drivers can see your scheduled trip and accept it when they’re available.';

  @override
  String get matchingAlternativesTitleScheduled =>
      'Still waiting on a driver. You can try another option.';

  @override
  String get matchingTryMarketplace => 'Marketplace';

  @override
  String get matchingAlternativesFabTooltip => 'More options to find a driver';

  @override
  String get scheduledMatchingBackToHome => 'Home';

  @override
  String get scheduledMatchingCancelRide => 'Cancel ride';

  @override
  String get scheduledMatchingMoreMenuTooltip => 'More';

  @override
  String get scheduledRideDetailsSheetTitle => 'Scheduled trip details';

  @override
  String get marketplaceMatchingBannerTitle => 'Marketplace ride';

  @override
  String get marketplaceMatchingBannerBody =>
      'Drivers can bid on your route. We’ll match you with a Caby as soon as someone accepts.';

  @override
  String get continueSavedBooking => 'Continue saved booking';

  @override
  String get continueSavedBookingHint => 'Pick up where you left off.';

  @override
  String get scheduledRideQueuedTitle => 'Ride queued';

  @override
  String get scheduledRideQueuedSubtitle =>
      'Drivers can see your scheduled trip and accept it. We’ll notify you when someone is assigned.';

  @override
  String scheduledRideQueuedSubtitleWithTime(String when) {
    return 'Pickup $when. Drivers can see your trip and accept it — we’ll notify you when someone is assigned.';
  }

  @override
  String get tripSummaryDropoffLabel => 'Drop-off';

  @override
  String get tripSummarySubtitle => 'Review before requesting a driver';

  @override
  String get tripSummaryPassengerRideSection => 'Passenger & ride';

  @override
  String get tripSummaryPaymentSection => 'Payment';

  @override
  String get tripSummaryEdit => 'Edit';

  @override
  String get tripSummaryNameNotSet =>
      'No pickup name yet — add who drivers should ask for';

  @override
  String get smartBundleTitle => 'YOUR RIDE CLASSES';

  @override
  String smartBundleIncludes(Object names) {
    return 'Includes: $names';
  }

  @override
  String get smartBundleExpandHint => 'Refine';

  @override
  String get smartBundleTapToExpand => 'Tap to view all ride classes';

  @override
  String get smartBundleExpandSubtitle =>
      'Standard, Comfort, taxi bus, wheelchair & prices.';

  @override
  String get smartBundleFootnoteWide =>
      'More classes selected — you’ll usually match faster. First driver to accept sets the final fare for their class.';

  @override
  String get smartBundleFootnoteNarrow =>
      'Fewer classes selected — matching may take a bit longer.';

  @override
  String get smartBundleFootnoteSingle =>
      'Single class — fixed estimate for this trip.';

  @override
  String smartBundlePriceBand(Object min, Object max) {
    return '€$min–€$max';
  }

  @override
  String smartBundlePriceSingle(Object price) {
    return '€$price';
  }

  @override
  String get smartBundlePetRowTitle => 'Pet-friendly ride';

  @override
  String get smartBundleLoadError =>
      'Couldn’t load class prices. Pick a vehicle below.';

  @override
  String get smartBundleRetry => 'Retry loading prices';

  @override
  String get favoriteDriversFirstTripDetail => 'Favorite drivers first';

  @override
  String get bookDriver => 'Book driver';

  @override
  String get postToAllDrivers => 'Post to all drivers';

  @override
  String get vehiclePreferredCategoryUnavailable =>
      'Your saved vehicle type is not available. We selected Standard.';

  @override
  String get vehiclePreferredNoDriversNearby =>
      'No drivers for your usual vehicle nearby. We switched to an available option.';

  @override
  String bookingUsualVehicleChip(String vehicle) {
    return 'Your usual: $vehicle';
  }

  @override
  String get noRidesInCategory => 'No rides in this category';

  @override
  String get tryDifferentFilter => 'Try a different filter';

  @override
  String get rideStatusCancelled => 'Cancelled';

  @override
  String get rideStatusSearching => 'Searching';

  @override
  String get rideStatusDriverAssigned => 'Driver Assigned';

  @override
  String get rideStatusDriverArrived => 'Driver Arrived';

  @override
  String get rideStatusInProgress => 'In Progress';

  @override
  String get selectAllThatApply => 'Select all that apply';

  @override
  String get morePaymentOptionsHint =>
      'More payment options = better chance of finding a driver';

  @override
  String get chooseYourRide => 'Choose your ride';

  @override
  String get driverPayment => 'Driver Payment';

  @override
  String get searchEnterDestinationHint => 'Enter destination';

  @override
  String get whenRowLabel => 'When';

  @override
  String get accountProfileHeading => 'Profile';

  @override
  String get accountProfileCardSubtitle =>
      'Your booking name, email, and how the app looks.';

  @override
  String get accountProfilePreferencesLabel => 'Language';

  @override
  String get riderPassportTitle => 'Rider Passport';

  @override
  String get riderPassportSubtitle =>
      'Your HeyCaby travel identity for faster, smoother bookings.';

  @override
  String get riderPassportReady => 'Ready for faster bookings';

  @override
  String get riderPassportNeedsWork => 'A few details make booking faster';

  @override
  String get accountCompleteProfileHeading => 'Complete your profile';

  @override
  String get accountBookingDetailsHeading => 'Booking details';

  @override
  String get accountRidePreferencesHeading => 'Ride preferences';

  @override
  String get accountHelpSafetyHeading => 'Help & safety';

  @override
  String get accountLegalAccountHeading => 'Legal & account';

  @override
  String get accountChecklistName => 'Booking name';

  @override
  String get accountChecklistEmail => 'Verified email';

  @override
  String get accountChecklistSavedPlaces => 'Saved places';

  @override
  String get accountChecklistPayment => 'Payment preference';

  @override
  String get accountChecklistDone => 'Done';

  @override
  String get accountChecklistMissing => 'Missing';

  @override
  String get accountTripReadyBody =>
      'Your profile helps drivers recognize you and keeps repeat bookings quick.';

  @override
  String get riderRatingTitle => 'Your rider rating';

  @override
  String get riderRatingSubtitle =>
      'Based on driver feedback after completed rides.';

  @override
  String get riderRatingNoRating => 'No rating yet';

  @override
  String get riderRatingNoRatingBody =>
      'Complete a few rides to start building your reputation.';

  @override
  String riderRatingTrips(int count) {
    return '$count trips rated';
  }

  @override
  String get riderRatingDetailsTitle => 'Your rider reputation';

  @override
  String get riderRatingBreakdownTitle => 'Ratings breakdown';

  @override
  String get riderRatingDriverNotesTitle => 'Notes from drivers';

  @override
  String get riderRatingDriverNotesBody =>
      'Private feedback becomes visible after both sides have rated the trip.';

  @override
  String get riderRatingNoComments => 'No written feedback yet.';

  @override
  String get riderRatingAnonymousDriver => 'Driver feedback';

  @override
  String get riderRatingLoadFailed => 'Your rating could not be loaded.';

  @override
  String riderRatingBasedOn(int count) {
    return 'Based on $count completed trips rated by drivers.';
  }

  @override
  String riderRatingAccessibility(String rating, int count) {
    return 'Rider rating $rating out of 5, based on $count ratings';
  }

  @override
  String get accountBookingNameLabel => 'Booking name';

  @override
  String get accountBookingNameHint => 'What should drivers call you?';

  @override
  String get accountBookingNameDescription =>
      'This name will be shown to drivers when you book a ride.';

  @override
  String get accountSettingsHeading => 'Settings';

  @override
  String get accountLocationNeededBody =>
      'Location access is required for accurate pickup, nearby driver matching, and reliable trip updates.';

  @override
  String get accountManageLocation => 'Manage location access';

  @override
  String get accountNotificationsNeededBody => 'Notifications needed';

  @override
  String get accountManageNotifications => 'Manage notifications';

  @override
  String get toggleOn => 'On';

  @override
  String get toggleOff => 'Off';

  @override
  String get marketplaceYourSavings => 'Your savings';

  @override
  String get marketplaceStandardPrice => 'Typical price';

  @override
  String get marketplaceTypicalPriceTitle => 'Typical for this route';

  @override
  String marketplaceTypicalPriceBody(String amount) {
    return 'Based on nearby Cabys, this journey usually costs around $amount.';
  }

  @override
  String get marketplaceMatchChanceTitle => 'Match chance';

  @override
  String marketplaceMatchChanceBody(String bid, String percent) {
    return 'At $bid, we estimate about a $percent% chance a driver accepts.';
  }

  @override
  String get marketplaceMatchChanceStrong =>
      'Strong offer — you\'re at or above the usual price, so drivers are more likely to accept.';

  @override
  String get marketplacePricingLoading => 'Checking live driver rates…';

  @override
  String get marketplaceTypicalUnavailable =>
      'We couldn\'t load a typical price yet. Try again in a moment.';

  @override
  String marketplaceSavingsVsTypicalPercent(String percent) {
    return '$percent% below typical';
  }

  @override
  String marketplaceSavingsBanner(String percent) {
    return 'Save up to $percent% on this ride';
  }

  @override
  String get marketplaceYourBid => 'Your bid';

  @override
  String get marketplaceQuickSelect => 'Quick select';

  @override
  String get marketplaceHeroTagline =>
      'Name your price — drivers heading your way can accept or counter.';

  @override
  String get marketplaceYourRoute => 'Your route';

  @override
  String get marketplaceDragToAdjustHint => 'Slide to adjust';

  @override
  String get marketplaceSetPickupDestinationHint =>
      'Add pickup and destination to post your ride to the marketplace.';

  @override
  String get marketplaceLiveBadge => 'LIVE';

  @override
  String get marketplaceQuickBudget => 'Budget';

  @override
  String get marketplaceQuickPopular => 'Popular';

  @override
  String get marketplaceQuickFaster => 'Faster';

  @override
  String get marketplaceQuickExpress => 'Express';

  @override
  String marketplaceBidRangeMin(int amount) {
    return '€$amount';
  }

  @override
  String marketplaceBidRangeMax(int amount) {
    return '€$amount';
  }

  @override
  String get favoritesSaveTrustedDriversBody =>
      'Save drivers you trust for quick booking';

  @override
  String get favoritesSelectAllDrivers => 'Select all drivers';

  @override
  String favoritesPostRideTo(int count) {
    return 'Post ride to $count favorites';
  }

  @override
  String get searchFactIndependentDrivers =>
      'Independent drivers set their own prices';

  @override
  String get searchFactOwnPrices => 'No surge pricing - ever';

  @override
  String get searchFactOwnFuel => 'Drivers pay for their own fuel';

  @override
  String get searchFactVerifiedDrivers =>
      'Drivers on HeyCaby work as licensed taxi professionals';

  @override
  String get searchFactFavorites =>
      'We notify your saved drivers first, then open the ride to everyone nearby if none accept.';

  @override
  String get searchEnterPickupHint => 'Enter pickup location';

  @override
  String get goWhereverWhenever => 'Go wherever, whenever.';

  @override
  String get noTaxisInZone => 'No drivers nearby right now';

  @override
  String get oneTaxiInZone => '1 taxi in your zone';

  @override
  String taxisInZone(int count) {
    return '$count+ taxis in your zone';
  }

  @override
  String get favouriteDriver => 'Favourite driver';

  @override
  String get email => 'Email';

  @override
  String get verified => 'Verified';

  @override
  String get addEmail => 'Add Email';

  @override
  String get add => 'Add';

  @override
  String get reportARide => 'Report a ride';

  @override
  String get reportARideSubtitle => 'Report a completed ride within 24 hours.';

  @override
  String get reportSelectRideTitle => 'Which ride?';

  @override
  String get reportSelectRideHint =>
      'Choose a completed trip so we can tie your report to the correct booking.';

  @override
  String get reportNoRidesToReport =>
      'No completed rides found in the last two weeks. If something happened on an older trip, contact support.';

  @override
  String get reportSelectThisRide => 'Select';

  @override
  String get reportChangeRide => 'Change';

  @override
  String get reportSelectedRideLabel => 'Ride selected';

  @override
  String get reportSelectedRideFallback =>
      'This ride is linked to your report. Continue below to describe what went wrong.';

  @override
  String get reportActiveTripBanner =>
      'You’re reporting an issue for your current trip. Tell us what happened below.';

  @override
  String get ridesCardReportRide => 'Report ride';

  @override
  String get supportSubtitle => 'Question or issue? Chat with support';

  @override
  String get supportHubContact => 'Contact';

  @override
  String get supportNewThread => 'New message';

  @override
  String get supportAllThreads => 'All messages';

  @override
  String get supportChatSendFailed =>
      'Could not send. Check connection and try again.';

  @override
  String get supportNoThreads => 'No conversations yet.';

  @override
  String get supportThreadsTitle => 'Messages';

  @override
  String get supportTypeMessage => 'Type a message';

  @override
  String get supportTicketOpen => 'Open';

  @override
  String get supportTicketResolved => 'Resolved';

  @override
  String get supportRecentHeading => 'Recent';

  @override
  String get supportSeeAll => 'See all';

  @override
  String get supportOtherCategory => 'Other';

  @override
  String get supportHelpArticles => 'Help articles';

  @override
  String get supportPickCategory => 'Category';

  @override
  String get supportStartChat => 'Start chat';

  @override
  String get supportSectionOngoing => 'Ongoing';

  @override
  String get supportSectionClosed => 'Closed';

  @override
  String get supportResolutionSummary => 'Reason';

  @override
  String get supportResolutionOutcome => 'How it was resolved';

  @override
  String get supportChatOfflineSaved =>
      'Your message was saved. The assistant is offline — support can still read it.';

  @override
  String get supportAiConsentTitle => 'Meet Yaz, your AI support assistant';

  @override
  String get supportAiConsentIntro =>
      'Yaz is HeyCaby\'s AI customer service assistant. Her job is to listen to your complaint and help solve simple support issues quickly.';

  @override
  String get supportAiConsentDataSent =>
      'To help you, we send: the message you type, your support ticket category, and limited account context needed to answer your request.';

  @override
  String get supportAiConsentThirdParty =>
      'AI processing: Yaz uses OpenAI (ChatGPT) models to generate responses.';

  @override
  String get supportAiConsentPolicy =>
      'For serious or sensitive issues, do not share private details in AI chat. Please email support at hello@heycaby.nl.';

  @override
  String get supportAiConsentEmailOption =>
      'Do not include passwords, full payment card numbers, government IDs, or other highly sensitive data in AI chat.';

  @override
  String get supportAiConsentCheckbox =>
      'I understand what data is sent, who processes it, and I allow HeyCaby to share this support chat data with Yaz AI support.';

  @override
  String get supportAiConsentContinue => 'I agree and continue';

  @override
  String get supportAiConsentSendEmail => 'Send email instead';

  @override
  String get supportCategoryRideIssue => 'Ride issue';

  @override
  String get supportCategoryPayment => 'Payment';

  @override
  String get supportCategoryAccount => 'Account';

  @override
  String get supportMessageSentTitle => 'Message sent';

  @override
  String get supportMessageSentBody =>
      'Thank you for your message. Our customer support team will review it and get back to you as soon as possible.\n\nIf your issue is urgent, you can chat with Yaz (AI support assistant). Please avoid sharing sensitive personal information in AI chat.';

  @override
  String get supportMessageSendFailedTitle => 'Could not send message';

  @override
  String get supportMessageSendFailedBody =>
      'We could not send your support message right now. Please try again shortly, or use Chat with Yaz for urgent help.';

  @override
  String get supportChatWithYaz => 'Chat with Yaz';

  @override
  String get supportSendMessageButton => 'Send message';

  @override
  String get supportYazUnavailableGuestAuthDisabled =>
      'Yaz chat is temporarily unavailable because guest chat auth is disabled on the server.';

  @override
  String get supportYazUnavailableTemporary =>
      'Yaz chat is temporarily unavailable. Please try again shortly.';

  @override
  String get supportYazFallbackReply =>
      'I could not answer right now. Please try again or send email support.';

  @override
  String get supportEmailSupport => 'Email support';

  @override
  String get supportYazAssistantTitle => 'Yaz AI support assistant';

  @override
  String get supportYazAssistantSubtitle =>
      'Ask anything about your ride, account, or payment.';

  @override
  String get supportYazMessageHint => 'Message Yaz...';

  @override
  String get favouriteDriversAccountSubtitle =>
      'Build your network of trusted drivers.';

  @override
  String get openLocationSettings => 'Open location settings';

  @override
  String get openNotificationSettings => 'Open notification settings';

  @override
  String get cashSubtitle => 'Pay with cash directly to driver';

  @override
  String get pinSubtitle => 'Debit card payment in vehicle';

  @override
  String get tikkieSubtitle => 'Pay via Tikkie payment request';

  @override
  String get yourName => 'Your name';

  @override
  String paymentMethodsSelected(int count) {
    return '$count payment method(s) selected';
  }

  @override
  String get vehicleStandard => 'Standard taxi';

  @override
  String get vehicleStandardDesc => 'Everyday taxi for up to 4 passengers.';

  @override
  String get vehicleComfort => 'Comfort';

  @override
  String get vehicleComfortDesc => 'Premium vehicles with extra space';

  @override
  String get vehicleTaxibus => 'Taxibus';

  @override
  String get vehicleTaxibusDesc => 'Up to 8 passengers with luggage';

  @override
  String get vehicleWheelchair => 'Wheelchair accessible';

  @override
  String get vehicleWheelchairDesc => 'Accessible vehicles with ramps';

  @override
  String get vehicleNearbyMarketTitle => 'Nearby taxi market';

  @override
  String get vehicleNearbyMarketChecking => 'Checking live availability...';

  @override
  String vehicleNearbyDriverCount(int count) {
    return '$count nearby drivers';
  }

  @override
  String get vehicleFareRangeLabel => 'Fare range';

  @override
  String get vehiclePickupRangeLabel => 'Pickup';

  @override
  String get vehicleOptionalPreferencesTitle => 'Optional preferences';

  @override
  String get vehicleOptionalPreferencesSubtitle =>
      'Fine-tune who sees your request.';

  @override
  String vehicleSupplyNearbyCount(int count) {
    return '$count nearby';
  }

  @override
  String get vehiclePetsWelcome => 'Pets welcome';

  @override
  String get vehicleIndependentPricingTitle => 'Independent driver pricing';

  @override
  String get vehicleIndependentPricingBody =>
      'Drivers set their own prices. This range comes from nearby taxis and may update before booking.';

  @override
  String get petFriendly => 'Pet-friendly';

  @override
  String get petFriendlyDesc => 'Drivers who accept pets';

  @override
  String get vehicleSupplyCountCaption => 'drivers available';

  @override
  String vehicleSupplyDriversCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count drivers nearby',
      one: '1 driver nearby',
      zero: 'No drivers nearby',
    );
    return '$_temp0';
  }

  @override
  String vehicleSupplyNearestKm(String km) {
    return 'Nearest ~$km km';
  }

  @override
  String vehicleSupplyFromPrice(String price) {
    return 'From €$price';
  }

  @override
  String get vehicleSupplyShowDrivers => 'Show drivers';

  @override
  String get vehicleSupplyHideDrivers => 'Hide drivers';

  @override
  String get vehicleSupplyEstimatesNote =>
      'Prices and availability are estimates and may change when you book.';

  @override
  String get returnTripFareEstimatesTitle => 'Return-trip offers';

  @override
  String get returnTripFareEstimatesSubtitle =>
      'Show driver prices with their active return-trip discount applied. Turn off for standard tariff estimates.';

  @override
  String get returnTripFareEstimatesRequiresRoute =>
      'Add pickup and drop-off to preview return-trip prices.';

  @override
  String get vehicleSupplyNoPickup =>
      'Set a pickup location to see nearby drivers.';

  @override
  String get vehicleSupplyLoading => 'Checking nearby drivers…';

  @override
  String get vehicleSupplyNoDriversInCategory =>
      'No drivers in this category right now.';

  @override
  String vehicleDriverOfferRow(String distanceKm, String price) {
    return '~$distanceKm km · €$price';
  }

  @override
  String vehicleDriverNumbered(int n) {
    return 'Driver $n';
  }

  @override
  String get ratingGreatDriver => 'Great driver';

  @override
  String get ratingCleanVehicle => 'Clean vehicle';

  @override
  String get ratingSafeDriving => 'Safe driving';

  @override
  String get ratingFriendly => 'Friendly';

  @override
  String get ratingOnTime => 'On time';

  @override
  String get ratingProfessional => 'Professional';

  @override
  String get failedToSubmitRating => 'Failed to submit rating';

  @override
  String get reportDriverBehavior => 'Driver behavior';

  @override
  String get reportVehicleCondition => 'Vehicle condition';

  @override
  String get reportRouteIssue => 'Route issue';

  @override
  String get reportSafetyConcern => 'Safety concern';

  @override
  String get reportPricingDispute => 'Pricing dispute';

  @override
  String get reportOther => 'Other';

  @override
  String get driver => 'Driver';

  @override
  String get errorLoadingMessages => 'Error loading messages';

  @override
  String get typeAMessage => 'Type a message...';

  @override
  String get noMessagesYet => 'No messages yet';

  @override
  String get startConversation => 'Start a conversation with your driver';

  @override
  String get faq => 'FAQ';

  @override
  String get termsOfService => 'Terms of Service';

  @override
  String get privacyPolicy => 'Privacy Policy';

  @override
  String get logoutConfirmTitle => 'Log out?';

  @override
  String get logoutConfirmMessage =>
      'You will need to re-enter your details to book again.';

  @override
  String get linkCopied => 'Link copied to clipboard';

  @override
  String get cancelRide => 'Cancel ride';

  @override
  String get cancelRideConfirm => 'Are you sure you want to cancel this ride?';

  @override
  String get noDriverFound => 'No driver found';

  @override
  String get noDriverFoundMessage =>
      'We could not find a driver for your ride.';

  @override
  String get retrySearch => 'Try again';

  @override
  String get youHaveArrived => 'You have arrived!';

  @override
  String get payDriverCash => 'Pay cash to the driver';

  @override
  String get payDriverPin => 'Pay by PIN to the driver';

  @override
  String get payDriverTikkie => 'You will receive a Tikkie from the driver';

  @override
  String get rateDriver => 'Rate driver';

  @override
  String get addToFavourites => 'Add to favourites';

  @override
  String get addComment => 'Add a comment...';

  @override
  String etaToDestination(String min) {
    return '$min min to destination';
  }

  @override
  String get rideDetails => 'Ride details';

  @override
  String get rideDetailViewReceipt => 'View receipt';

  @override
  String get rideDetailReceiptLoadFailed => 'Could not load receipt right now.';

  @override
  String get rebookRide => 'Book again';

  @override
  String get scheduleYourRide => 'Schedule your ride';

  @override
  String get selectDate => 'Select date';

  @override
  String get selectTime => 'Select time';

  @override
  String get confirmSchedule => 'Confirm schedule';

  @override
  String get postToMarketplace => 'Post to Marketplace';

  @override
  String get addYourEmail => 'Add your email';

  @override
  String get emailOnlyUsedFor =>
      'We use your email only to verify your identity for favourite drivers.';

  @override
  String get enterYourEmail => 'Enter your email address';

  @override
  String get sendCode => 'Send code';

  @override
  String get invalidEmail => 'Please enter a valid email address';

  @override
  String get failedToSaveEmail => 'Failed to save email. Please try again.';

  @override
  String get riderEmailReviewCodeHint =>
      'Verification code (App Store review only — leave empty for a normal account)';

  @override
  String get riderEmailReviewCodeFieldHint =>
      '6-digit code from App Store notes';

  @override
  String get riderEmailReviewCredentialsError =>
      'That email and code do not match the review login. Leave the code empty if you are not using the review account.';

  @override
  String get riderEmailReviewOtpSixDigitsOrEmpty =>
      'Enter all 6 digits or leave the code field empty.';

  @override
  String get addYourHome => 'Add your home';

  @override
  String get homeAddressDesc => 'Save your home address for quick access.';

  @override
  String get enterHomeAddress => 'Enter your home address';

  @override
  String get saving => 'Saving...';

  @override
  String get failedToSaveHome => 'Failed to save home address';

  @override
  String get faqBookingSection => 'Booking';

  @override
  String get faqHowToBook => 'How do I book a ride?';

  @override
  String get faqHowToBookAnswer =>
      'Open the app, tap \'Where to?\', enter your destination, choose a booking mode (Instant or Marketplace), select a payment method, and tap \'Find my driver\'. A nearby driver will be matched to your ride.';

  @override
  String get faqInstantVsMarketplace =>
      'What is the difference between Instant and Marketplace?';

  @override
  String get faqInstantVsMarketplaceAnswer =>
      'Instant sends your ride request to nearby drivers immediately. Marketplace lets you set your own price and drivers can bid on your ride, potentially saving you money.';

  @override
  String get faqScheduleRide => 'Can I schedule a ride for later?';

  @override
  String get faqScheduleRideAnswer =>
      'Yes! Tap the \'Later\' button on the home screen to choose a date and time for your ride. Your request will be sent to drivers at the scheduled time.';

  @override
  String get faqHowMarketplace => 'How does the Marketplace work?';

  @override
  String get faqHowMarketplaceAnswer =>
      'You set your desired price for the ride. Drivers see your offer and can bid on it. You choose which driver to accept based on their price, rating, and ETA.';

  @override
  String get faqDriversSection => 'Drivers and favourites';

  @override
  String get faqAddFavourite => 'How do I add a driver as a favourite?';

  @override
  String get faqAddFavouriteAnswer =>
      'After completing a ride, you can tap the heart icon on the rating screen to add that driver to your favourites. You need a verified email to use favourites.';

  @override
  String get faqWhatAreFavourites => 'What are favourite drivers?';

  @override
  String get faqWhatAreFavouritesAnswer =>
      'Favourite drivers are drivers you have saved. You can book rides directly to your trusted drivers for a more personal experience.';

  @override
  String get faqBlockDriver => 'Can I block a driver?';

  @override
  String get faqBlockDriverAnswer =>
      'During an active ride chat, open the menu (⋮) and use Block driver. You can also report a driver after a ride from the rating flow.';

  @override
  String get faqPaymentSection => 'Payment';

  @override
  String get faqPaymentMethods => 'Which payment methods are available?';

  @override
  String get faqPaymentMethodsAnswer =>
      'Cash, PIN (debit card in vehicle), and Tikkie (payment request sent after the ride).';

  @override
  String get faqWhoPaysWho => 'Who pays who?';

  @override
  String get faqWhoPaysWhoAnswer =>
      'You pay the driver directly. HeyCaby takes zero commission — 100% of the fare goes to the driver.';

  @override
  String get faqWhereSeeCosts => 'Where can I see my ride costs?';

  @override
  String get faqWhereSeeCostsAnswer =>
      'On the ride complete screen and in your rides history under the Rides tab.';

  @override
  String get faqSafetySection => 'Problems and safety';

  @override
  String get faqDriverNoShow => 'What do I do if my driver doesn\'t come?';

  @override
  String get faqDriverNoShowAnswer =>
      'The waiting screen has a cancel option. If no driver is found within a few minutes, you can retry or cancel the ride.';

  @override
  String get faqReportIncident => 'How do I report an incident?';

  @override
  String get faqReportIncidentAnswer =>
      'After a ride, use the report option on the rating screen to submit details about what happened.';

  @override
  String get faqInsurance => 'Is my ride insured?';

  @override
  String get faqInsuranceAnswer =>
      'All HeyCaby drivers are professional licensed taxi drivers with valid insurance.';

  @override
  String get faqAccountSection => 'Account';

  @override
  String get faqChangeName => 'How do I change my booking name?';

  @override
  String get faqChangeNameAnswer =>
      'Go to Account and tap the name field to edit it. Your new name will be shown to drivers on future bookings.';

  @override
  String get faqVerifyEmail => 'How do I verify my email?';

  @override
  String get faqVerifyEmailAnswer =>
      'Favourites need a saved email. Open Account or Favourite drivers, tap Add Email, enter your address, and tap Continue. For App Store review, use the review email and enter the 6-digit code from App Review Information in the verification code field.';

  @override
  String get faqDeleteAccount => 'How do I delete my account?';

  @override
  String get faqDeleteAccountAnswer =>
      'Go to Account, tap Delete my account, confirm by typing DELETE. This removes your rider identity and related saved data from HeyCaby.';

  @override
  String get termsTitle => 'Terms of Service';

  @override
  String get termsWhatIsHeyCaby => '1. About HeyCaby';

  @override
  String get termsWhatIsHeyCabyBody =>
      'HeyCaby is a platform that connects riders with independent, licensed taxi drivers. We do not employ drivers and do not provide transportation services ourselves. We act solely as a matching and facilitation platform.\n\nUser roles:\n• Riders: individuals requesting transportation\n• Drivers: independent professionals providing transportation\n\nEach user is responsible for their own actions on the platform.';

  @override
  String get termsRiderResponsibilities => '2. Rider Responsibilities';

  @override
  String get termsRiderResponsibilitiesBody =>
      'As a rider, you agree to:\n• Provide accurate pickup and destination information\n• Be present at the pickup location on time\n• Treat drivers with respect and professionalism\n• Pay for completed rides using agreed methods\n• Not engage in illegal, abusive, or unsafe behavior\n\nFailure to meet these responsibilities may result in account suspension.';

  @override
  String get termsPayment => '3. Driver Responsibilities and 4. Payments';

  @override
  String get termsPaymentBody =>
      'Drivers using HeyCaby must hold valid licenses and permits required by law, provide safe and lawful transport, communicate clearly, set fair pricing, and handle payments directly with riders.\n\nPayments are made directly between rider and driver. HeyCaby does not process, hold, or guarantee payments. Available methods may include cash, card (PIN), or third-party apps (e.g. Tikkie). Payment disputes must be resolved between rider and driver.';

  @override
  String get termsCancellation => '5. Cancellations';

  @override
  String get termsCancellationBody =>
      'Riders may cancel before driver acceptance at no cost. After acceptance, cancellation fees may apply at the driver’s discretion. Repeated cancellations or no-shows may result in account restrictions.';

  @override
  String get termsSuspension => '6. Platform Usage and 8. Account Suspension';

  @override
  String get termsSuspensionBody =>
      'You agree not to misuse the platform, provide false information, attempt fraud or payment abuse, or harass/harm other users.\n\nHeyCaby may suspend or terminate accounts in cases of fraudulent activity, abuse, harassment, repeated no-shows/cancellations, or other violations of these terms.';

  @override
  String get termsDisputes => '9. Disputes and 10. Liability';

  @override
  String get termsDisputesBody =>
      'Users should first resolve disputes directly. If needed, disputes can be reported through the app. HeyCaby may assist but is not liable for outcomes between users.\n\nHeyCaby is not liable for actions of drivers or riders, ride quality/safety, or damages/losses/disputes arising from trips. Users accept that HeyCaby is a facilitator, not a transport provider.';

  @override
  String get termsGoverningLaw => '11. Changes to Terms';

  @override
  String get termsGoverningLawBody =>
      'We may update these terms at any time. Continued use of the platform means you accept the updated terms.';

  @override
  String get termsContact => '12. Contact';

  @override
  String get termsContactBody =>
      'For support or disputes, use the in-app support feature.';

  @override
  String get privacyTitle => 'Privacy Policy';

  @override
  String get privacyDataCollected => '1. Information We Collect';

  @override
  String get privacyDataCollectedBody =>
      'We collect only the data necessary to provide our services:\n• Account information: email and basic profile details for account creation and identity verification\n• Location data: used during active bookings to match riders with nearby drivers and facilitate trips\n• Trip data: pickup/drop-off locations, timestamps, and ride history for receipts and service improvement\n• Device data: app version, device type, and push notification tokens for functionality and performance\n• Support data: support ticket messages and category, which may be processed by our AI support provider when you consent in chat';

  @override
  String get privacyLocationData => '3. Location Data Usage';

  @override
  String get privacyLocationDataBody =>
      'Location is accessed only during active ride sessions. We do not track users in the background outside of bookings. Location data is not stored longer than necessary for trip completion.';

  @override
  String get privacyDataSharing => '4. Data Sharing';

  @override
  String get privacyDataSharingBody =>
      'We share limited data only when required to provide the service.\n\nDrivers receive: rider name (or alias) and pickup location.\nRiders receive: driver details necessary for the trip.\n\nSupport AI (with your consent before first message): support chat message content, ticket category, and minimal context needed to answer your support request are processed by OpenAI (ChatGPT) models.\n\nWe do not share email addresses, phone numbers (unless explicitly required by future features), or sensitive personal data for AI chat.';

  @override
  String get privacyRetention => '5. Data Retention';

  @override
  String get privacyRetentionBody =>
      'Trip data is stored for receipts and history. Account data is stored until account deletion is requested. Temporary data (like recent searches) may expire automatically.';

  @override
  String get privacyGdpr => '6. Your Rights (GDPR)';

  @override
  String get privacyGdprBody =>
      'As a user in the EU, you have the right to access your personal data, correct inaccurate data, request deletion of your account, and restrict or object to processing.\n\nYou can delete your account directly in the app: Account → Delete Account.';

  @override
  String get privacyNoAds =>
      '2/7/8/9/10/11/12. Use, AI Support (Yaz), Security, Notifications, Third Parties, Changes, Contact';

  @override
  String get privacyNoAdsBody =>
      'Your data is used strictly to operate HeyCaby: matching riders and drivers, facilitating bookings and communication, providing trip history and receipts, improving performance, and sending important notifications.\n\nAI Support (Yaz): when you choose \"Chat with Yaz\" and explicitly consent in-app, your support message content, ticket category, and limited account context are processed by OpenAI (ChatGPT) to generate support responses. AI chat is optional. You can use non-AI support instead via \"New message\".\n\nWe instruct users not to include highly sensitive data in AI chat (such as passwords, full payment card numbers, or government ID numbers). For sensitive or complex issues, users are directed to contact human support.\n\nWe do not use your data for advertising and we do not sell your data to third parties.\n\nWe apply technical and organizational security measures, though no system is 100% secure.\n\nPush notifications may include ride updates, important service messages, and occasional product updates. You can disable notifications in device settings.\n\nWe may use trusted providers (e.g., payment providers, Firebase, Supabase) only as needed to deliver services.\n\nWe may update this policy from time to time; continued use means acceptance of updates.\n\nFor privacy-related requests, contact us via the in-app support section.';

  @override
  String distanceRemaining(String km) {
    return '$km km remaining';
  }

  @override
  String get shareRideLink => 'Share ride link';

  @override
  String get rideShareCopied => 'Ride tracking link copied to clipboard';

  @override
  String get deleteMyAccount => 'Delete my account';

  @override
  String get deleteAccountConfirmTitle => 'Delete your account permanently?';

  @override
  String get deleteAccountConfirmBody =>
      'Your rider profile and data tied to this session will be removed from HeyCaby. Some trip records may be kept where the law requires. This cannot be undone.';

  @override
  String get deleteAccountTypeDeleteHint => 'Type DELETE to confirm';

  @override
  String get deleteAccountTypeDeleteError =>
      'Type the word DELETE (any letter case is fine), then tap Delete my account again.';

  @override
  String get deleteAccountFailed =>
      'Could not delete account. Try again or contact support.';

  @override
  String get deleteAccountSuccess => 'Your account was deleted.';

  @override
  String get deleteAccountSuccessModalTitle => 'Account deleted';

  @override
  String get deleteAccountSuccessModalBody =>
      'Your HeyCaby rider profile and associated personal data from this app have been permanently removed.\n\nYou can uninstall the app from your phone whenever you wish—there is nothing else you need to do here.';

  @override
  String get deleteAccountSuccessModalCta => 'Continue';

  @override
  String get deleteAccountNoSession => 'No active session to delete.';

  @override
  String get deleteAccountNoPersonalDataMessage =>
      'You have no personal information stored in our system. No email or data to delete. You can simply remove the app from your phone.';

  @override
  String get deleteAccountNoEmailMessage =>
      'You have no email associated with your account. There is no personal data to delete. You can simply remove the app from your phone.';

  @override
  String get dialogOk => 'OK';

  @override
  String get blockDriver => 'Block driver';

  @override
  String get blockDriverConfirm =>
      'You will not see new messages from this driver in this ride chat.';

  @override
  String get reportDriverTitle => 'Report this driver?';

  @override
  String get reportDriverBody =>
      'HeyCaby will review this ride chat. You can add details below (optional).';

  @override
  String get reportReasonHint => 'What happened? (optional)';

  @override
  String get chatReportSubmitted => 'Thanks — we received your report.';

  @override
  String get chatMoreOptions => 'More';

  @override
  String get chatBlockFailed => 'Could not update block list.';

  @override
  String get chatReportFailed => 'Could not send report. Try again.';

  @override
  String get saveButton => 'Save';

  @override
  String get savedAddressesSubtitle => 'Your saved destinations';

  @override
  String get savedPlacesSheetSubtitle =>
      'Tap a place to book, or save another below.';

  @override
  String get savedPlacesEmptyStartWith => 'Start with';

  @override
  String savedPlacesSectionCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count places saved',
      one: '1 place saved',
    );
    return '$_temp0';
  }

  @override
  String get savedPlacesTapToBook => 'Tap to book';

  @override
  String get savedPlacesGhostHome => 'Home';

  @override
  String get savedPlacesGhostMom => 'Mom\'s home';

  @override
  String get noSavedAddressesYet => 'Build your shortcut list';

  @override
  String get noSavedAddressesEmptyBody =>
      'Save home, work, the gym — or several homes (Mom, Dad, vacation). Same icon, different names.';

  @override
  String get addSavedAddress => 'Save a place';

  @override
  String get addSavedAddressSheetTitle => 'Save a new place';

  @override
  String get editSavedAddress => 'Edit place';

  @override
  String get editSavedAddressSheetTitle => 'Edit saved place';

  @override
  String get editSavedAddressSheetBody =>
      'Update the name, category, or address when you move or the details change.';

  @override
  String get editSavedAddressNotFound =>
      'This place was removed. Refresh your list and try again.';

  @override
  String get saveChanges => 'Save changes';

  @override
  String get savedAddressCategoryLabel => 'Category';

  @override
  String get savedAddressNameLabel => 'Name this place';

  @override
  String get savedAddressNameHint => 'e.g. Mom’s home, Office, Gym';

  @override
  String get savedAddressSearchLabel => 'Address';

  @override
  String get savedAddressSearchHint => 'Search for an address';

  @override
  String get savedAddressesEmailPrompt =>
      'Save your favourite addresses and book in one tap. Enter your email to get started.';

  @override
  String get savedAddressesGetStarted => 'Get started';

  @override
  String get savedAddressesUnlocked => 'Great! You can now save addresses.';

  @override
  String get savedAddressLabelHome => 'Home';

  @override
  String get savedAddressLabelWork => 'Work';

  @override
  String get savedAddressLabelGym => 'Gym';

  @override
  String get savedAddressLabelCustom => 'Custom';

  @override
  String get savedAddressesLimitReached =>
      'You can save up to 10 places. Remove one to add another.';

  @override
  String get savedAddressesSessionRequired =>
      'We couldn\'t verify your account. Open Account, confirm your email, then try again.';

  @override
  String get deleteSavedAddress => 'Delete';

  @override
  String get searchFactDriversKeep100 =>
      'Drivers keep 100% of their earnings. HeyCaby takes zero commission per ride.';

  @override
  String get searchFactNoSurgePricing =>
      'No surge pricing. Ever. The price you see is the price you pay.';

  @override
  String get searchFactAllVerified =>
      'HeyCaby is built for licensed taxis — professional transport, not private gig-hail cars.';

  @override
  String get searchFactMarketplace =>
      'Drivers heading home sometimes ride for less. Try TAXI TERUG for a better price.';

  @override
  String get searchFactZZP =>
      'Every Caby driver is an independent professional. You ride with someone proud of their work.';

  @override
  String get searchFactSaveAddresses =>
      'Live in Rotterdam? Tap the house icon once and your destination is filled in. Always.';

  @override
  String get searchFactPayHowYouWant =>
      'Cash, Tikkie, card or invoice — your driver will tell you which options are available.';

  @override
  String get searchDidYouKnowEyebrow => 'Did you know?';

  @override
  String get searchingTitle => 'Finding you a Caby…';

  @override
  String get matchingTitleMarketplace => 'Finding a marketplace Caby…';

  @override
  String get matchingTitleScheduled =>
      'Finding a Caby for your scheduled ride…';

  @override
  String get matchingStatusLive => 'Live';

  @override
  String get matchingStatusWindow => 'Window';

  @override
  String get matchingStatusOffers => 'Offers';

  @override
  String dispatchWave0Title(String name) {
    return 'Connecting you with $name first…';
  }

  @override
  String get dispatchWave1Title => 'Finding your driver';

  @override
  String get dispatchWave2Title => 'Still looking…';

  @override
  String get dispatchWave3Title => 'Reaching more drivers…';

  @override
  String get dispatchWave4Title => 'Searching further…';

  @override
  String get dispatchNoDriversTitle => 'No drivers available right now';

  @override
  String dispatchWaveDriversNotified(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count drivers notified',
      one: '1 driver notified',
    );
    return '$_temp0';
  }

  @override
  String dispatchWaveClosestEta(String km, int minutes) {
    return 'Closest: $km km · ~$minutes min';
  }

  @override
  String dispatchWaveExpandKm(int km) {
    return 'Expanding search to $km km';
  }

  @override
  String dispatchWaveFarEta(String km, int minutes) {
    return 'Someone $km km away could be with you in ~$minutes min';
  }

  @override
  String get dispatchSurgeBanner => 'High demand right now — searching quickly';

  @override
  String get dispatchLowDensityBanner =>
      'Searching across a wider area — fewer drivers online right now';

  @override
  String get dispatchNoDriversBody =>
      'All nearby drivers are busy or offline. Try again in a few minutes or schedule for later.';

  @override
  String get homeNearTermTitleInstant => 'Finding your Caby';

  @override
  String get homeNearTermTitleMarketplace => 'Marketplace request';

  @override
  String get homeNearTermTitleScheduled => 'Scheduled ride';

  @override
  String get homeNearTermOpenMatching =>
      'We’re still matching you with a driver. Tap to view progress.';

  @override
  String get homeNearTermOpenMatchingHint =>
      'Still matching — tap for trip details';

  @override
  String get homeNearTermTripDetails => 'Trip details';

  @override
  String get activeBookingSearchingTitle => 'Searching for your driver';

  @override
  String get activeBookingMarketplaceTitle => 'Searching for offers';

  @override
  String get activeBookingScheduledTitle => 'Scheduled ride active';

  @override
  String get activeBookingTapForDetails =>
      'Tap to view progress without losing the map.';

  @override
  String get activeBookingCollapseHome => 'Collapse to summary';

  @override
  String get activeBookingKeepAliveTitle => 'Your request keeps running';

  @override
  String get activeBookingKeepAliveBody =>
      'You can return home or lock your phone. We’ll keep searching and notify you when anything changes.';

  @override
  String activeBookingDriversNotified(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count drivers received your request',
      one: '1 driver received your request',
      zero: '0 drivers received your request',
    );
    return '$_temp0';
  }

  @override
  String activeBookingOffersReceived(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count offers received',
      one: '1 offer received',
      zero: 'No offers yet',
    );
    return '$_temp0';
  }

  @override
  String get activeBookingInstantBody =>
      'HeyCaby is new — matching can take several minutes. We\'ll keep searching and notify you when a driver accepts.';

  @override
  String get activeBookingMarketplaceBody =>
      'Independent drivers can accept, counter, or ignore. You choose who to ride with.';

  @override
  String activeBookingOffersBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Compare offers and choose your driver.',
      one: 'Review the offer and choose your driver.',
    );
    return '$_temp0';
  }

  @override
  String activeBookingBestOffer(String price, int minutes) {
    return 'Best offer €$price · $minutes min away';
  }

  @override
  String activeBookingScheduledBody(String pickup, String searchStarts) {
    return 'Pickup $pickup. Driver search starts $searchStarts.';
  }

  @override
  String get activeBookingScheduledSearchingBody =>
      'Driver search has started for your scheduled ride.';

  @override
  String activeBookingScheduledSearchStarts(String searchStarts) {
    return 'Driver search starts $searchStarts';
  }

  @override
  String get activeBookingScheduledQueuedTitle => 'Scheduled ride queued';

  @override
  String get activeBookingScheduledQueuedBody =>
      'We\'ll start searching 30 minutes before pickup and notify you.';

  @override
  String get rideMatchingTypeLabelInstant => 'Instant ride';

  @override
  String get rideMatchingTypeLabelMarketplace => 'Marketplace';

  @override
  String get rideMatchingTypeLabelTerug => 'TAXI TERUG';

  @override
  String get rideMatchingTypeLabelScheduled => 'Scheduled';

  @override
  String get activeSearchStopTitle => 'Stop searching?';

  @override
  String get activeSearchStopBody =>
      'We\'ll cancel this ride request. Drivers will stop seeing it, and you won\'t get driver notifications for it. You can book again anytime.';

  @override
  String get activeSearchStopConfirm => 'Stop ride';

  @override
  String get activeSearchStopKeep => 'Keep searching';

  @override
  String homeNearTermUntilPickup(String remaining) {
    return 'Pickup in $remaining';
  }

  @override
  String get ridesScheduledMatchingSection => 'Upcoming scheduled requests';

  @override
  String get noDriverFoundCard =>
      'No Caby found yet. What would you like to do?';

  @override
  String get searchNoSupplyInlineTitle => 'No drivers close by';

  @override
  String get searchNoSupplyInlineBody =>
      'No drivers at your pickup right now. Schedule for later — we\'ll keep searching.';

  @override
  String get searchNoSupplyTaxiTerugCardSubtitle =>
      'Drivers heading your way for less';

  @override
  String get searchNoSupplySheetTitle => 'No drivers close by';

  @override
  String get searchExpiredSheetTitle => 'No driver accepted yet';

  @override
  String searchExpiredSheetBody(int minutes) {
    return 'Your $minutes-minute search ended without a match. Pick your next step.';
  }

  @override
  String get searchKeepSearching => 'Keep searching';

  @override
  String get searchExpiredGoHome => 'Go home without booking';

  @override
  String get searchSeeOptions => 'More options';

  @override
  String get searchExpiredShareSecondary => 'Know a driver? Share HeyCaby';

  @override
  String get notifyMeWhenFound => 'Notify Me';

  @override
  String get scheduleRideInstead => 'Schedule';

  @override
  String get activeSearchBannerSubtitle =>
      'We\'ll notify you as soon as we find one.';

  @override
  String get activeSearchCardHint =>
      'HeyCaby is new and growing. This background search stops automatically after 30 minutes — you will not be left waiting silently.';

  @override
  String activeSearchMinutesLeft(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes minutes left',
      one: '$minutes minute left',
    );
    return '$_temp0';
  }

  @override
  String get noCabyFoundModalTitle => 'Sorry, no Caby found 😔';

  @override
  String get noCabyFoundModalBody =>
      'We are still a growing platform with a limited number of drivers. You can help us! Do you know a certified taxi driver? Share HeyCaby with them — together we make this platform bigger.';

  @override
  String get shareHeyCabyInvite => 'Share HeyCaby →';

  @override
  String shareHeyCabyMessage(String url) {
    return 'Try HeyCaby — fair rides, zero commission for drivers. $url';
  }

  @override
  String get growthModalClose => 'Close';

  @override
  String get riderEmailVerificationSent =>
      'We sent a 6-digit code to your email. Enter it below.';

  @override
  String get riderSplashTagline => 'Your caby, in minutes.';

  @override
  String get activeSearchWidget => 'Searching for your Caby…';

  @override
  String get driverFoundWidget => 'Caby found! Confirm your ride →';

  @override
  String get riderNameLabel => 'Your name';

  @override
  String get scheduledRideLabel => 'Scheduled for';

  @override
  String get activeRideShareError => 'Unable to share ride right now';

  @override
  String get activeRideCancelConfirmBody =>
      'Do you really want to cancel the ride? Rebooking may not get you to your destination more quickly.';

  @override
  String get activeRideWaitForDriver => 'Wait for driver';

  @override
  String get activeRidePickupNotes => 'Any pickup notes?';

  @override
  String get activeRideChatSubtitle => 'Message your driver fast';

  @override
  String get activeRidePingDriver => 'Ping driver';

  @override
  String get activeRidePingSubtitle => 'Send a quick alert';

  @override
  String get activeRidePickupNote => 'Pickup note';

  @override
  String get activeRidePingSheetSubtitle =>
      'Send a quick pickup update. Your driver gets it as a ride message.';

  @override
  String get activeRidePingAtPickup => 'I’m at pickup';

  @override
  String get activeRidePingWalkingThere => 'I’m walking there';

  @override
  String get activeRidePingCantFindYou => 'I can’t find you';

  @override
  String get activeRidePingRunningLate => 'Running 2 min late';

  @override
  String get activeRidePingConfirmPlate => 'Please confirm plate';

  @override
  String activeRidePingSent(String message) {
    return 'Ping sent: $message';
  }

  @override
  String get activeRidePingFailed => 'Could not send ping. Try again.';

  @override
  String activeRideLastPing(String message) {
    return 'Ping sent: $message · now';
  }

  @override
  String activeRidePickupIn(String minutes) {
    return 'Pickup in $minutes min';
  }

  @override
  String activeRideArrivingIn(String minutes) {
    return 'Arriving in $minutes min';
  }

  @override
  String get activeRideDriverOutside => 'Your driver is outside';

  @override
  String get activeRideDriverFound => 'Driver found';

  @override
  String get activeRideMaxFourSeats => '4 seats max';

  @override
  String activeRideSeatsMax(String seats) {
    return '$seats seats max';
  }

  @override
  String get activeRideVerifiedTaxi => 'Verified taxi driver';

  @override
  String get safety => 'Safety';

  @override
  String get activeRideFoundingShort => 'Founding';

  @override
  String get activeRideShareSubtitle => 'Share live trip link';

  @override
  String get activeRideReportSubtitle => 'Submit ride report';

  @override
  String get activeRideSupportSubtitle => 'Safety and help';

  @override
  String get safetySheetTitle => 'Safety';

  @override
  String get safetySheetShareTrip => 'Share trip';

  @override
  String get safetySheetShareTripSubtitle =>
      'Share live trip link with contacts';

  @override
  String get safetySheetReport => 'Report an issue';

  @override
  String get safetySheetReportSubtitle => 'Submit a ride report';

  @override
  String get safetySheetEmergency => 'Emergency call (112)';

  @override
  String get safetySheetEmergencySubtitle => 'Call European emergency services';

  @override
  String get safetySheetCancel => 'Cancel';

  @override
  String get activeRidePickupNotSet => 'Pickup not set';

  @override
  String get activeRideDestinationNotSet => 'Destination not set';

  @override
  String get activeRideShareDetails => 'Share ride details';

  @override
  String get activeRideContactDriver => 'Contact driver';

  @override
  String activeRideCategoryLabel(String category) {
    return 'Category: $category';
  }

  @override
  String get activeRideCancelReasonLongPickup => 'Long pickup time';

  @override
  String get activeRideCancelReasonBetterAlternative =>
      'Found better alternative';

  @override
  String get activeRideCancelReasonDriverNotCloser =>
      'Driver not getting closer';

  @override
  String get activeRideCancelReasonDriverAskedCancel =>
      'Driver asked to cancel';

  @override
  String get activeRideCancelReasonPriceDispute => 'Price dispute with driver';

  @override
  String get activeRideCancelReasonOutsideAppPayment =>
      'Driver asked to pay outside app';

  @override
  String get activeRidePlateNumber => 'Plate number';

  @override
  String get activeRideUnknownPlate => 'UNKNOWN';

  @override
  String get activeRideFoundingMember => 'Founding Member';

  @override
  String get activeRideVerifyPlate =>
      'Check the plate number matches before you get in.';

  @override
  String get activeRideVerifyPlateButton => 'Confirm plate';

  @override
  String get activeRidePlateVerifiedSaved => 'Plate verification saved';

  @override
  String get activeRidePlateVerifiedOffline =>
      'Saved on device — will sync when you\'re back online';

  @override
  String get ridePayDriverTitle => 'Pay your driver';

  @override
  String get ridePayDriverBody =>
      'Your driver just ended the trip. Pay the fare now before you leave the vehicle.';

  @override
  String get ridePayDriverAmountCaption => 'Amount to pay';

  @override
  String ridePayDriverPayVia(String method) {
    return 'Pay via $method';
  }

  @override
  String get ridePayDriverAddTip => '+ Tip';

  @override
  String get ridePayDriverTotalCaption => 'Total to pay';

  @override
  String get ridePayDriverFareLine => 'Fare';

  @override
  String get ridePayDriverTipLine => 'Tip';

  @override
  String ridePayDriverConfirmWithTotal(String amount) {
    return 'I\'ve paid $amount';
  }

  @override
  String ridePayDriverAmount(String amount) {
    return 'Fare due: $amount';
  }

  @override
  String get ridePayDriverConfirm => 'I\'ve paid';

  @override
  String get ridePayDriverDismiss => 'One moment';

  @override
  String get paymentRiderHeadline => 'Pay your driver';

  @override
  String paymentRiderCashInstruction(String amount) {
    return 'Pay $amount in cash before you leave the vehicle';
  }

  @override
  String get paymentRiderPinInstruction =>
      'Tap or insert your card on the driver\'s PIN reader';

  @override
  String get paymentRiderTikkieInstruction => 'Scan your driver\'s Tikkie QR';

  @override
  String get paymentCashPayBeforeExit => 'Pay before leaving';

  @override
  String get paymentPinTapReader => 'Debit card on driver\'s terminal';

  @override
  String get paymentTikkieScanQrHint =>
      'Open Camera and scan the QR on your driver\'s phone.';

  @override
  String get paymentWaitingForDriver => 'Waiting for driver';

  @override
  String get paymentWaitingForDriverHint =>
      'Your driver confirms when payment is received. You can confirm here after 10 minutes if needed.';

  @override
  String get paymentDriverConfirmedProceed =>
      'Driver confirmed — opening rating…';

  @override
  String get paymentThankYou => 'Thanks for paying!';

  @override
  String get paymentAddTipQuestion => 'Add a tip?';

  @override
  String get paymentNoTip => 'No tip';

  @override
  String get paymentRiderPaidConfirm => 'I\'ve paid ✓';

  @override
  String get paymentConfirmFailed => 'Could not confirm payment. Try again.';

  @override
  String get activeRideDriverNearPickup =>
      'Your driver is about 1 km away. Come downstairs soon — waiting time may be charged after arrival.';

  @override
  String get activeRideDriverAroundCorner =>
      'Get ready — your driver is around the corner!';

  @override
  String get activeRideTripProgress => 'Trip progress';

  @override
  String activeRideDistanceRemaining(String km) {
    return '$km km remaining';
  }

  @override
  String activeRideTimeRemaining(String minutes) {
    return '$minutes min to arrival';
  }

  @override
  String activeRideArrivingAround(String time) {
    return 'Arriving around $time';
  }

  @override
  String get activeRideTripInProgressHeadline => 'On your way';

  @override
  String get activeRideWaitingFeeWaived => 'Waiting fee waived';

  @override
  String get activeRideWaitingFreePickupTime => 'Free pickup time';

  @override
  String get activeRideWaitingTime => 'Waiting time';

  @override
  String get activeRideWaitingFeeWaivedBody =>
      'Your driver waived the waiting fee.';

  @override
  String get activeRideWaitingGraceBody =>
      'Waiting may be added after 2 minutes.';

  @override
  String activeRideWaitingFeeAdded(String amount) {
    return '$amount added so far';
  }

  @override
  String activeRideWaitingRate(String rate) {
    return 'Rate after grace: $rate';
  }

  @override
  String get activeRideWaitingRateNotSet => 'Waiting rate not set';

  @override
  String activeRideWaitingRateLive(String rate) {
    return '$rate · live';
  }

  @override
  String get activeRideWaitingTripTotal => 'Trip total';

  @override
  String activeRideWaitingFeeLine(String amount) {
    return '+$amount waiting';
  }

  @override
  String activeRideWaitingBaseFare(String amount) {
    return 'Base $amount';
  }

  @override
  String activeRideWaitingFreeWindow(String minutes) {
    return '$minutes min free';
  }

  @override
  String get activeRideTimelinePickup => 'Pickup';

  @override
  String get activeRideTimelineDestination => 'Drop-off';

  @override
  String get openAction => 'Open';

  @override
  String get openLinkAction => 'Open link';

  @override
  String get rideReceiptTitle => 'Ride receipt';

  @override
  String get rideReceiptUnavailable => 'Receipt not available yet.';

  @override
  String get rideReceiptSettlement => 'Settlement';

  @override
  String get rideReceiptPaidTitle => 'Paid';

  @override
  String get rideReceiptBusinessReady => 'Business-ready receipt';

  @override
  String get rideReceiptBusinessReadyBody =>
      'Keep this receipt for your trip history and expense records.';

  @override
  String get rideReceiptShareWhatsapp => 'Share via WhatsApp';

  @override
  String get rideReceiptShareEmail => 'Send via email';

  @override
  String get rideReceiptShareFailed => 'Could not share receipt';

  @override
  String get rideReceiptFareBreakdown => 'Fare breakdown';

  @override
  String get rideReceiptBaseFare => 'Ride fare';

  @override
  String get rideReceiptWaitingFee => 'Waiting time';

  @override
  String get rideReceiptWaitingWaived => 'Waiting time waived';

  @override
  String get rideReceiptChargeableWait => 'Chargeable wait';

  @override
  String rideReceiptSeconds(int seconds) {
    return '${seconds}s';
  }

  @override
  String get rideReceiptReference => 'Receipt reference';

  @override
  String get rideReceiptRideId => 'Ride ID';

  @override
  String get rideReceiptExpected => 'Expected';

  @override
  String get rideReceiptPaid => 'Paid';

  @override
  String get rideReceiptMethod => 'Method';

  @override
  String get rideReceiptNote => 'Note';

  @override
  String get rideReceiptOutstanding => 'Outstanding';

  @override
  String get rideReceiptOverpaid => 'Overpaid';

  @override
  String get rideReceiptStatus => 'Status';

  @override
  String get rideReceiptSettlementComplete => 'Settlement complete';

  @override
  String get smartBundleRideTypeOptions => 'Ride type options';

  @override
  String smartBundleEstimatedPrice(String min, String max) {
    return 'Estimated price: $min - $max';
  }

  @override
  String get smartBundleDriverPricingNote =>
      'Drivers set their own prices. We\'ll match you with the best options nearby.';

  @override
  String get smartBundleTapToHide => 'Tap to hide ride classes';

  @override
  String get taxiTerugScreenTitle => 'Taxi Terug';

  @override
  String get taxiTerugScreenSubtitle =>
      'Ride with taxis already heading your way.';

  @override
  String get taxiTerugScreenTabAvailable => 'Available taxis';

  @override
  String get taxiTerugScreenTabPostRequest => 'Post a request';

  @override
  String get taxiTerugScreenPickupPlaceholder => 'Pickup location';

  @override
  String get taxiTerugScreenDestinationPlaceholder => 'Where are you going?';

  @override
  String get taxiTerugScreenSetRoute =>
      'Set your pickup and destination to see matching taxis.';

  @override
  String get taxiTerugScreenLoadError => 'Could not load taxis. Try again.';

  @override
  String get taxiTerugScreenDisabled =>
      'Taxi Terug is not available right now.';

  @override
  String get taxiTerugScreenNoRides => 'No Taxi Terug rides found.';

  @override
  String get taxiTerugScreenNoRidesBody =>
      'Post your trip so drivers heading that way can accept.';

  @override
  String get taxiTerugScreenPostCta => 'Post Taxi Terug Request';

  @override
  String get taxiTerugScreenBook => 'Book';

  @override
  String get taxiTerugScreenPostTitle => 'Post Taxi Terug Request';

  @override
  String get taxiTerugScreenPostBody =>
      'Drivers heading your way can accept or send an offer.';

  @override
  String get taxiTerugScreenOfferLabel => 'Your offer';

  @override
  String get taxiTerugScreenPostButton => 'Post Request';

  @override
  String get taxiTerugScreenPosting => 'Posting…';

  @override
  String get taxiTerugScreenPostConfirmation =>
      'Your request will appear to drivers heading toward your destination.';

  @override
  String get taxiTerugHotDestinationsTitle => 'Drivers heading to';

  @override
  String get taxiTerugHotDestinationsSubtitle =>
      'Tap a city to see taxis on your route.';

  @override
  String get taxiTerugPickCityHint => 'Pick a city above';

  @override
  String get taxiTerugTrackerSearching => 'Finding your Taxi Terug match';

  @override
  String get taxiTerugTrackerSearchingBody =>
      'We\'re looking for taxis heading your way. You can wait here or go about your day.';

  @override
  String get taxiTerugTrackerNoMatch => 'No match found';

  @override
  String get taxiTerugTrackerNoMatchBody =>
      'No Taxi Terug drivers were found within 1 hour. Please try again later.';

  @override
  String get taxiTerugTrackerCancelTitle => 'Cancel request';

  @override
  String get taxiTerugTrackerCancelConfirm =>
      'Are you sure you want to cancel your Taxi Terug request?';

  @override
  String get taxiTerugTrackerBoost => 'Boost offer';

  @override
  String get taxiTerugTrackerBoostTitle => 'Boost your offer';

  @override
  String get taxiTerugTrackerBoostSubtitle =>
      'Increase your offer so more drivers can see it and accept faster.';

  @override
  String taxiTerugTrackerBoostSuccess(Object amount) {
    return 'Offer boosted to €$amount! Drivers can see it instantly.';
  }

  @override
  String get taxiTerugTrackerBoostFailed =>
      'Could not boost offer. Please try again.';

  @override
  String taxiTerugTrackerCurrentOffer(Object amount) {
    return 'Current offer: €$amount';
  }
}
