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
  String get whatDidYouLike => 'What did you like?';

  @override
  String get additionalFeedback => 'Additional feedback (optional)';

  @override
  String get tellUsMore => 'Tell us more about your experience...';

  @override
  String get submitRating => 'Submit Rating';

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
  String scheduledFor(String date) {
    return 'Scheduled for $date';
  }

  @override
  String get noDriversNearby => 'No drivers nearby';

  @override
  String get connectionProblem => 'Connection problem. Please try again.';

  @override
  String get rideBookingFailed =>
      'Couldn’t start your ride — the server rejected the request. On a local build, check SUPABASE_URL and SUPABASE_ANON_KEY in your .env (Supabase Dashboard → Settings → API), then try Find driver again.';

  @override
  String get locationPermissionRequired =>
      'Location access is needed to set pickup and find nearby drivers.';

  @override
  String get locationRequired => 'Location required';

  @override
  String get locationRequiredMessage =>
      'HeyCaby needs your location to set your pickup point and find nearby drivers. Without it you cannot book a ride.';

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
  String get tellAFriendNavLabel => 'TAF';

  @override
  String get tellAFriendNavSemanticLabel =>
      'Invite friends — grow your ride circle';

  @override
  String get tellAFriendScreenTitle => 'Invite friends';

  @override
  String get tellAFriendSharePrompt =>
      'Send your link. Friends join free — you’ll see them here when they sign up.';

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
  String get tellAFriendRewardTitle => 'Why it helps';

  @override
  String get tellAFriendRewardBullet1 =>
      'More riders nearby can speed up matching.';

  @override
  String get tellAFriendRewardBullet2 =>
      'Perks may unlock as your circle grows.';

  @override
  String get tellAFriendRewardBullet3 => 'Weekend discounts when available';

  @override
  String get tellAFriendRewardBullet4 =>
      'Helps drivers see demand in your area';

  @override
  String get tellAFriendInviteLinkLabel => 'Your link';

  @override
  String get tellAFriendLinkResolving => 'Getting your short invite link…';

  @override
  String get tellAFriendCopyLink => 'Copy link';

  @override
  String get tellAFriendShareLink => 'Share invite';

  @override
  String get tellAFriendShowQr => 'Show QR code';

  @override
  String get tellAFriendQrTitle => 'Scan to join HeyCaby';

  @override
  String get tellAFriendQrHint =>
      'Scanning opens heycaby.nl in the browser. Use Share or Copy for your personal invite link.';

  @override
  String get tellAFriendSocialProof =>
      'Thanks for helping HeyCaby grow locally.';

  @override
  String get tellAFriendShareDoneSnackbar =>
      'Invite sent — thanks for spreading the word!';

  @override
  String get tellAFriendLinkCopied => 'Copied — ready to paste anywhere';

  @override
  String get tellAFriendShareSubject => 'Join me on HeyCaby';

  @override
  String get tellAFriendShareMessage =>
      'I\'m building my ride circle on HeyCaby — want in? Tap my invite:';

  @override
  String get tellAFriendLinkUnavailable => 'Link not ready yet';

  @override
  String get tellAFriendLinkUnavailableHint =>
      'Open this screen again in a moment, or restart the app.';

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
  String get favouriteDrivers => 'Favourite drivers';

  @override
  String get favouriteDriversSubtitle => 'Book a driver you trust';

  @override
  String favouriteDriversSubtitleWithCount(int count) {
    return '$count favourite drivers';
  }

  @override
  String get noFavouritesYet => 'No favourites yet';

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
  String get marketplace => 'Marketplace';

  @override
  String get marketplaceSubtitle => 'Drivers heading your way — save up to 40%';

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
  String get accountProfilePreferencesLabel => 'Language & theme';

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
  String get accountLocationNeededBody => 'Location access needed';

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
      'Name your price — drivers accept or suggest a counter.';

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
  String get searchFactVerifiedDrivers => 'All drivers are verified';

  @override
  String get searchFactFavorites =>
      'We notify your saved drivers first, then open the ride to everyone nearby if none accept.';

  @override
  String get searchEnterPickupHint => 'Enter pickup location';

  @override
  String get goWhereverWhenever => 'Go wherever, whenever.';

  @override
  String get noTaxisInZone => 'No taxis in your zone';

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
  String get favouriteDriversAccountSubtitle =>
      'Save trusted drivers and send rides directly to them.';

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
  String get vehicleStandard => 'Standard';

  @override
  String get vehicleStandardDesc => 'Affordable rides for everyday trips';

  @override
  String get vehicleComfort => 'Comfort';

  @override
  String get vehicleComfortDesc => 'Premium vehicles with extra space';

  @override
  String get vehicleTaxibus => 'Taxibus';

  @override
  String get vehicleTaxibusDesc => 'Up to 8 passengers with luggage';

  @override
  String get vehicleWheelchair => 'Wheelchair';

  @override
  String get vehicleWheelchairDesc => 'Accessible vehicles with ramps';

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
  String get termsWhatIsHeyCaby => 'What is HeyCaby';

  @override
  String get termsWhatIsHeyCabyBody =>
      'HeyCaby is a zero-commission platform that connects riders with professional, licensed Dutch taxi drivers. HeyCaby does not employ drivers and does not set fares. The platform facilitates matching only.';

  @override
  String get termsRiderResponsibilities => 'Rider responsibilities';

  @override
  String get termsRiderResponsibilitiesBody =>
      'Riders must provide accurate booking information including correct pickup location and destination. Respectful conduct toward drivers is required at all times. Riders must be present at the pickup location when the driver arrives.';

  @override
  String get termsPayment => 'Payment';

  @override
  String get termsPaymentBody =>
      'All payments are made directly from rider to driver. HeyCaby does not process, hold, or take a percentage of any payment. Available methods are cash, PIN (debit card), and Tikkie.';

  @override
  String get termsCancellation => 'Cancellation';

  @override
  String get termsCancellationBody =>
      'Rides can be cancelled free of charge before a driver accepts the request. Once a driver has accepted, the driver may charge a cancellation fee at their discretion.';

  @override
  String get termsSuspension => 'Account suspension';

  @override
  String get termsSuspensionBody =>
      'HeyCaby reserves the right to suspend accounts in cases of fraud, abuse, repeated no-shows, or false reports against drivers.';

  @override
  String get termsDisputes => 'Dispute resolution';

  @override
  String get termsDisputesBody =>
      'Any disputes between riders and drivers should first be reported through the in-app report feature. HeyCaby will review reports and mediate where possible.';

  @override
  String get termsGoverningLaw => 'Governing law';

  @override
  String get termsGoverningLawBody =>
      'These terms are governed by the laws of the Netherlands. Any legal proceedings shall be brought before the competent courts in the Netherlands.';

  @override
  String get termsContact => 'Contact';

  @override
  String get termsContactBody =>
      'For questions about these terms, contact support through the Account screen in the app.';

  @override
  String get privacyTitle => 'Privacy Policy';

  @override
  String get privacyDataCollected => 'Data collected';

  @override
  String get privacyDataCollectedBody =>
      'HeyCaby collects your email address (for identity verification), location data (during active bookings only), and trip history (for receipts and ride history).';

  @override
  String get privacyLocationData => 'Location data';

  @override
  String get privacyLocationDataBody =>
      'Location data is used only during active booking and ride sessions. Your location is never stored beyond the duration of the trip and is not used for tracking outside of rides.';

  @override
  String get privacyDataSharing => 'Data sharing';

  @override
  String get privacyDataSharingBody =>
      'When you book a ride, the driver receives only your booking name and pickup location. Your email address, phone number, and other personal data are never shared with drivers.';

  @override
  String get privacyRetention => 'Data retention';

  @override
  String get privacyRetentionBody =>
      'Trip history is kept for receipt and history purposes. Account data is retained until you request deletion. Recent destinations expire automatically after 120 hours.';

  @override
  String get privacyGdpr => 'Your rights (GDPR)';

  @override
  String get privacyGdprBody =>
      'Under GDPR, you have the right to access, rectify, and delete your personal data. You can delete your rider account in-app from Account → Delete my account. For other requests, contact support through the Account screen.';

  @override
  String get privacyNoAds => 'No advertising';

  @override
  String get privacyNoAdsBody =>
      'HeyCaby does not display advertising and does not sell your data to third parties. Your data is used exclusively for providing the ride-matching service.';

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
  String get noSavedAddressesYet => 'Build your shortcut list';

  @override
  String get noSavedAddressesEmptyBody =>
      'Save home, work, the gym — or several homes (Mom, Dad, vacation). Same icon, different names.';

  @override
  String get addSavedAddress => 'Save a place';

  @override
  String get addSavedAddressSheetTitle => 'Save a new place';

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
  String get deleteSavedAddress => 'Delete';

  @override
  String get searchFactDriversKeep100 =>
      'Drivers keep 100% of their earnings. HeyCaby takes zero commission per ride.';

  @override
  String get searchFactNoSurgePricing =>
      'No surge pricing. Ever. The price you see is the price you pay.';

  @override
  String get searchFactAllVerified =>
      'Every licence, every insurance, every chauffeurspas — checked by us before going online.';

  @override
  String get searchFactMarketplace =>
      'Drivers heading home sometimes ride for less. Check the marketplace for the best price.';

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
  String get searchingTitle => 'Finding you a Caby…';

  @override
  String get matchingTitleMarketplace => 'Finding a marketplace Caby…';

  @override
  String get matchingTitleScheduled =>
      'Finding a Caby for your scheduled ride…';

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
  String get rideMatchingTypeLabelInstant => 'Instant ride';

  @override
  String get rideMatchingTypeLabelMarketplace => 'Marketplace';

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
}
