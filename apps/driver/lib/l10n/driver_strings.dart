/// Driver app strings. Design doc: every string from l10n.
/// Migrate to flutter gen-l10n when driver l10n is set up.
class DriverStrings {
  static const String goOnline = 'Go online';
  static const String slideToGoOnline = 'Slide to go online';
  static const String offline = 'Offline';
  static const String online = 'Online';
  static const String onBreak = 'On break';
  static const String resume = 'Resume';
  static const String today = 'Today';
  static const String thisWeek = 'This week';
  static const String acceptanceRate = 'Acceptance rate';
  static const String scheduledRides = 'Scheduled rides';
  static const String scheduledRidesSubtitle = 'rides available in your area';
  static const String driverRating = 'Driver rating';
  /// Migration 040 — shown on score screen when `drivers.avg_*` columns exist.
  static const String ratingBreakdownTitle = 'Your averages by area';
  static const String ratingPunctuality = 'Punctuality';
  static const String ratingCleanliness = 'Cleanliness';
  static const String ratingAttitude = 'Attitude';
  static const String ratingDrivingSafety = 'Driving safety';
  static const String ratingCommunication = 'Communication';
  static const String trustScoreLabel = 'Trust score';
  static const String trustScoreHint = 'Internal quality score (0–100). Passengers see your public stars.';
  static const String reviewFlagTitle = 'Review requested';
  static const String reviewFlagBody =
      'Our team may look at recent ratings. You don’t need to do anything unless we contact you.';
  static const String newDriverShieldActive = 'New driver protection active';
  static const String newDriverShieldBody =
      'Early ratings use extra protection so one rough trip does not define you.';
  static const String ratingBadges = 'Achievements';
  static const String ratingsInScore = 'ratings in your score';
  static const String todaysRides = "Today's rides";
  static const String driverTalk = 'Driver Talk';
  static const String takeABreak = 'Take a break';
  static const String shiftWorkdayActive = 'Werkdag actief';
  static const String shiftBreakActive = 'Pauze actief';
  static const String shiftTodaySummary = 'Vandaag';
  static const String shiftStatDriving = 'Rijden';
  static const String shiftStatBreak = 'Pauze';
  static const String shiftStatRides = 'Ritten';
  static const String shiftStatEarnings = 'Verdiensten';
  static const String shiftHoursShort = 'uur';
  static const String shiftBreakReminderTitle = 'Tijd voor een pauze!';
  static const String shiftBreakReminderBody =
      'Je rijdt al lang genoeg achter elkaar. Neem even rust.';
  /// Shown on the warm break banner (continuous driving ≥ reminder interval).
  static String shiftBreakReminderBodyHours(int hours) =>
      'Je rijdt al $hours uur. Neem even rust.';
  static const String pauze = 'Pauze';
  static const String hervat = 'Hervat';
  static const String stop = 'Stop';
  static const String shiftArcHint = '8 uur dienst';
  static const String endShift = 'End shift';
  static const String endShiftConfirm = 'End your shift?';
  static const String endShiftDetail =
      'You have driven X hours and completed Y rides today.';
  static const String cancel = 'Cancel';
  static const String readyToGoBackOnline = 'Ready to go back online?';
  static const String zoneView = 'Zone view';
  static const String demandZones = 'Demand zones';
  static const String demandZonesDesc =
      'See gold circles with passenger counts.';
  static const String clearMap = 'Clear map';
  static const String clearMapDesc = 'Hide zone overlays for a clean view.';
  static const String dutchBreakNotice =
      'You have been driving for X hours. Dutch regulations require a 30-minute break after 4.5 hours of driving.';
  static const String breakRecommended = 'Pauze aanbevolen over X minuten';
  static const String breakRequired = 'Wettelijke pauze vereist';
  static const String setUpRates = 'Set up your rates →';
  static const String home = 'Home';
  static const String work = 'Work';
  static const String me = 'Me';
  static const String earnings = 'Earnings';
  static const String availableRides = 'Available rides';
  static const String community = 'Community';
  static const String profile = 'Profile';
  /// Profile header when `drivers.full_name` is empty.
  static const String profileNamePlaceholder = 'Add your name';
  static const String profileEditNameTitle = 'Your name';
  static const String profileEditNameSubtitle = 'Shown to passengers when they book.';
  /// One-time profile photo confirmation (shown before upload).
  static const String profilePhotoConfirmTitle = 'Use this photo?';
  static const String profilePhotoConfirmBody =
      'Make sure this is a real, clear photo of you — you can only set it once from the app. '
      'Passengers will see it when they book a taxi.\n\n'
      'Are you sure this is what you want passengers to see?';
  static const String profilePhotoConfirmYes = 'Yes, save it';
  static const String profilePhotoLockedMessage =
      'Your profile photo is set. To change it, contact support.';
  static const String profilePhotoUploadFailed = 'Could not upload photo. Try again.';
  static const String profilePhotoUploadConnectionError =
      'Verbindingsfout bij uploaden. Controleer uw WiFi of schakel over naar mobiele data en probeer opnieuw.';
  static const String profileNameSaved = 'Name saved.';
  static const String profileNameSaveFailed = 'Could not save name.';
  static const String profilePhotoSaved = 'Profile photo saved.';
  static const String profileDriverSetupFailed =
      'Could not create your driver profile. Check your connection or try again.';
  static const String profileEditSheetTitle = 'Your profile';
  static const String profileEditSheetSubtitle =
      'Passengers see your name and photo when they book.';
  static const String profileTapHint = 'Tap to add name & photo';
  static const String profilePhotoAddHint = 'Tap the photo to choose from gallery';
  /// Web founding-driver flow — welcome after `claim-founding-driver` Edge Function.
  static const String foundingDriverWelcomeTitle = 'Founding Driver';
  static const String foundingDriverWelcomeBody =
      'Welkom terug! Je chauffeur-account is gekoppeld aan je aanmelding op heycaby.nl.';
  static String foundingDriverWelcomeNumber(int n) =>
      'Je Founding Driver-nummer is #$n. Je gegevens uit het formulier staan al in je profiel.';
  static const String foundingDriverWelcomeNext =
      'Voeg nog een profielfoto en een foto van je voertuig toe om klaar te zijn.';
  static const String foundingDriverProfilePhotoCta = 'Profielfoto';
  static const String foundingDriverVehiclePhotoCta = 'Voertuigfoto';
  static const String foundingDriverClose = 'Sluiten';
  static const String documents = 'Documents';
  static const String complianceAndDocuments = 'Compliance & documents';
  static const String complianceSubtitle =
      'Dutch taxi law (Wpv 2000) requires these items. HeyCaby verifies them with ILT, RDW, KvK, or manual review.';
  static const String complianceSubtitleV2 =
      'Dutch taxi law (Wpv 2000) requires these documents. Numbers and uploads are reviewed by our team; RDW is checked automatically for your vehicle.';
  static const String complianceFooterV2 =
      'VOG and taxidiploma are no longer required in this app. APK follows from your kenteken (RDW).';
  static const String chauffeurspasHintV2 = 'Chauffeurspas number (8–12 digits)';
  static const String insurancePhotoOnFile = 'Insurance document on file';
  static const String kvkManualVerifyHint =
      'We verify KvK details manually after you save.';
  static const String complianceOverall = 'Overall status';
  static const String docChauffeurspas = 'Chauffeurspas';
  static const String docRijbewijs = 'Driving licence';
  static const String docVog = 'VOG (certificate of conduct)';
  static const String docTaxidiploma = 'Taxidiploma';
  static const String docTaxiInsurance = 'Taxi insurance';
  static const String docKvk = 'KvK registration';
  static const String docApkVehicle = 'Vehicle & APK';
  static const String statusVerified = 'Verified';
  static const String statusPending = 'Pending review';
  static const String statusActionNeeded = 'Action needed';
  static const String statusExpired = 'Expired';
  static const String statusImplied = 'Covered by chauffeurspas';
  static const String statusNotSet = 'Not submitted';
  static const String expiresOn = 'Expires';
  static const String chauffeurspasHint = '8-digit chauffeurspas number';
  static const String verifyWithIlt = 'Verify with ILT';
  static const String verifying = 'Checking with ILT…';
  static const String chauffeurspasInvalidLength =
      'Enter the 8-digit number on your chauffeurspas.';
  static const String chauffeurspasVerifiedOk = 'Chauffeurspas verified.';
  static const String chauffeurspasVerifyFailed = 'Verification failed. Try again or contact support.';
  static const String complianceUploadPortal =
      'Complete verification with Veriff below, or uploads are handled by support when enabled.';
  static const String vehiclePlateRdw =
      'Vehicle plate is checked against RDW (taxi registration & APK).';
  static const String complianceCompliant = 'Compliant';
  static const String complianceIncomplete = 'Incomplete';
  static const String compliancePending = 'Pending review';
  static const String complianceSuspended = 'Suspended';
  static const String complianceRejected = 'Rejected';
  static const String support = 'Support';
  static const String settings = 'Settings';
  static const String instellingen = 'Instellingen';
  static const String tarieven = 'Tarieven';
  static const String uitloggen = 'Uitloggen';
  static const String logout = 'Logout';
  static const String deleteAccount = 'Delete account';
  static const String deleteAccountConfirmTitle = 'Delete account permanently?';
  static const String deleteAccountConfirmBody =
      'This removes your driver profile and sign-in from HeyCaby. This cannot be undone.';
  static const String deleteAccountTypeDeleteHint = 'Type DELETE to confirm';
  static const String deleteAccountTypeDeleteError =
      'Type the word DELETE (any letter case is fine), then tap Delete account again.';
  static const String deleteAccountFailed =
      'Could not delete account. Try again or contact support.';
  static const String deleteAccountSuccessModalTitle = 'Account deleted';
  static const String deleteAccountSuccessModalBody =
      'Your HeyCaby driver profile and associated personal data from this app have been permanently removed.\n\n'
      'You can uninstall the app from your phone whenever you wish—there is nothing else you need to do here.';
  static const String deleteAccountSuccessModalCta = 'Continue';
  static const String chatWithRiderTitle = 'Chat with rider';
  static const String chatTypeMessageHint = 'Type a message…';
  static const String blockRider = 'Block rider';
  static const String blockRiderConfirm =
      'You will no longer see new messages from this rider in this ride chat.';
  static const String reportRider = 'Report rider';
  static const String reportRiderTitle = 'Report this rider?';
  static const String reportRiderBody =
      'HeyCaby will review this ride chat. You can add details below (optional).';
  static const String reportReasonHint = 'What happened? (optional)';
  static const String reportSubmitted = 'Thanks — we received your report.';
  static const String chatBlockFailed = 'Could not update block list.';
  static const String chatReportFailed = 'Could not send report. Try again.';
  static const String logoutConfirm = 'Weet u zeker dat u wilt uitloggen?';
  /// Destructive confirm in logout dialog.
  static const String logoutConfirmAction = 'Log out';
  static const String menu = 'Menu';
  static const String ride = 'ride';
  static const String rides = 'rides';
  static const String now = 'Now';
  static const String scheduled = 'Scheduled';
  static const String requests = 'Requests';
  static const String confirmed = 'Confirmed';
  static const String marketplace = 'Marketplace';
  static const String announcements = 'Announcements';
  static const String rideSwap = 'Ride Swap';
  /// Home card + full screen subtitle.
  static const String rideSwapScreenIntro =
      'Open rides from colleagues who need someone else to drive. Pull to refresh.';
  /// Info dialog on home (how Ride Swap works).
  static const String rideSwapHelpBody =
      'When a colleague cannot drive a scheduled ride, they can list it here. '
      'You can claim it if you are available and compliant (requirements are checked).\n\n'
      'To offer your own ride for someone else to take: open Scheduled → Confirmed and tap Wisselen.';
  static String rideSwapOpenCount(int n) =>
      n == 0 ? 'No open swaps' : (n == 1 ? '1 open swap' : '$n open swaps');
  static const String swapOfferTitle = 'Rit aanbieden voor wissel';
  static const String swapOfferBullet1 =
      'Deze rit wordt zichtbaar voor andere chauffeurs in jouw netwerk.';
  static const String swapOfferBullet2 =
      'Zodra een chauffeur de rit overneemt, heb jij er geen toegang meer toe.';
  static const String swapOfferBullet3 =
      'De passagier ontvangt automatisch de gegevens van de nieuwe chauffeur.';
  static const String swapOfferBullet4 =
      'Wisselaanbiedingen verlopen automatisch als niemand ze oppakt. De rit blijft dan van jou.';
  static const String swapOfferWhy = 'Waarom kun je niet rijden?';
  static const String swapReasonPersonal = 'Persoonlijke noodstoestand';
  static const String swapReasonVehicle = 'Voertuigstoring';
  static const String swapReasonSchedule = 'Roosterconflict';
  static const String swapReasonMedical = 'Medisch';
  static const String swapReasonOther = 'Anders';
  static const String swapOfferConfirm = 'Ja, rit aanbieden';
  static const String swapEmergencyWarn =
      'Spoed: weinig tijd tot ophalen. Zorg dat de passagier op de hoogte is als niemand de rit overneemt.';
  static const String swapTooLate =
      'Het is te laat om deze rit te wisselen. Bel de passagier en neem contact op met support.';
  static const String swapListedBadge = 'Aangeboden voor wissel';
  static const String swapAction = 'Wisselen';
  static const String rideDetails = 'Rit details';
  static const String swapFeedEmpty = 'Geen open wisselritten';
  static const String swapClaim = 'Rit overnemen';
  static const String swapViewDetails = 'Bekijk details';
  static const String swapExpiresIn = 'Verloopt over';
  static const String swapUrgencyEmergency = 'SPOED';
  static const String swapUrgencyUrgent = 'URGENT';
  static const String swapUrgencyModerate = 'MATIG';
  static const String swapUrgencyStandard = 'STANDAARD';
  static const String swapDistanceToPickup = 'Jij bent';
  static const String swapKmFromPickup = 'km van ophaallocatie';
  static const String swapScheduleConflict =
      'Roosterconflict: deze wisselrit overlapt met jouw planning.';
  static const String swapConfirmTitle = 'Rit bevestigen';
  static const String swapConfirmBody =
      'Door te bevestigen neem jij deze rit volledig over. De rit staat meteen in jouw agenda.';
  static const String swapConfirmCta = 'Bevestigen';
  static const String swapCancelOffer = 'Annuleer wissel';
  static const String swapCancelledOk = 'Wissel ingetrokken. De rit blijft bij jou.';
  static const String swapCancelConfirmTitle = 'Wissel intrekken?';
  static const String swapCancelConfirmBody =
      'De rit verdwijnt uit de wissellijst. Je houdt de rit zelf.';
  static const String swapCancelConfirmCta = 'Intrekken';
  static const String swapErrorNotCompliant =
      'Je profiel moet compliant zijn om een wisselrit over te nemen.';
  static const String swapErrorExpired = 'Deze wissel is verlopen.';
  static const String swapErrorNotAvailable = 'Deze wissel is niet meer beschikbaar.';
  static const String swapErrorOwnSwap = 'Je kunt je eigen aanbod niet overnemen.';
  static const String swapClaimSuccess = 'Rit overgenomen';
  static const String claimRide = 'Claim ride';
  static const String vehicle = 'Vehicle';
  static const String pickupDistance = 'Pickup distance';
  static const String acceptsCash = 'Accepts cash';
  static const String acceptsCard = 'Card payments (pin)';
  static const String acceptsInvoice = 'Invoice (op rekening)';
  static const String acceptsTikkie = 'Accepts Tikkie';
  static const String petFriendly = 'Pet friendly';
  static const String wheelchairAccessible = 'Wheelchair accessible';
  static const String language = 'Language';
  static const String theme = 'Theme';
  static const String preferences = 'Preferences';
  static const String preferencesSubtitle =
      'Vehicle, payments, and how you appear in the app.';
  static const String preferencesSectionVehicle = 'Vehicle & range';
  static const String preferencesSectionPayments = 'Payments & accessibility';
  static const String preferencesSectionAppearance = 'Appearance';
  static const String saveAction = 'Save';
  static const String vehicleRdwTitle = 'Your vehicle';
  static const String vehicleRdwSubtitle =
      'Enter your kenteken. We fetch vehicle data from RDW automatically.';
  static const String lookupPlate = 'Look up plate';
  static const String plateNotFoundRdw =
      'Plate not found in RDW. Check for typos and try again.';
  static const String vehicleNotTaxiRdw =
      'This vehicle is in RDW but not registered as a taxi. Contact RDW or support.';
  static const String vehicleVerifiedTaxi = 'Vehicle verified as taxi';
  /// Shown when `drivers_vehicle_plate_unique` fires — plate exists on another driver row.
  static const String vehiclePlateDuplicate =
      'This license plate is already registered. If it is your taxi, another account may have it — contact support.';
  static const String saveAndContinue = 'Save and continue';
  static const String vehiclePlateLockedSubtitle =
      'This plate is saved. Contact support if you need to change your vehicle.';
  static const String chauffeurspasSave = 'Save chauffeurspas';
  static const String chauffeurspasSaved =
      'Saved. Our team will verify your number manually.';
  static const String chauffeurspasExpiryLabel = 'Expiry on card (optional)';
  static const String veriffStart = 'Verify licence with Veriff';
  /// Full-screen Veriff entry (`/driver/veriff`).
  static const String veriffScreenTitle = 'Licence verification';
  static const String veriffScreenIntro =
      'You will review the chauffeur terms, then open Veriff in your browser '
      'to verify your driving licence and identity.';
  /// Large callout on `/driver/veriff` — drivers must switch back manually from Safari/Chrome.
  static const String veriffScreenComeBackTitle = 'Come back to HeyCaby';
  static const String veriffScreenComeBackBody =
      'When you finish in Veriff, switch back to this app (app switcher or home, then open HeyCaby). '
      'Your licence status updates here — the browser cannot return you to the app automatically.';
  static const String veriffScreenContinue = 'Continue';
  static const String veriffOpenFailed =
      'Could not start Veriff. Ensure the Veriff edge function is deployed.';
  static const String veriffProcessingHint =
      'Complete verification in the browser. Status updates here when done.';
  /// Bottom sheet before opening Veriff (hosted flow + chauffeur terms art. 3).
  static const String veriffTermsGateTitle = 'Terms & identity check';
  static const String veriffTermsGateBody =
      'Verification is done by Veriff (see chauffeur terms, section 3). '
      'Read the terms before you continue.';
  static const String veriffTermsReadFull = 'Read full chauffeur terms';
  static const String veriffTermsReadVeriffOnly = 'Open Veriff section only';
  static const String veriffTermsCheckbox =
      'I have read and agree to the HeyCaby chauffeur terms and the Veriff verification process.';
  static const String veriffTermsContinue = 'Continue to Veriff';
  static const String veriffTermsCancel = 'Cancel';
  static const String kvkSave = 'Save KvK details';
  static const String insurancePickPhoto = 'Add insurance photo';
  static const String insuranceSave = 'Save insurance';
  static const String paymentMethodRequired =
      'Keep at least one payment method enabled.';
  static const String onlineBlockedCompliance =
      'You can go online after we confirm your driving licence (complete Veriff first, then we verify in our system).';
  static const String onlineBlockedPending =
      'Your profile is being reviewed…';
  /// Veriff done; waiting for ops to set `rijbewijs_verified` in Supabase.
  static const String onlineBlockedLicenseReview =
      'Your licence check is being finalised by our team. You can go online after we confirm it (usually shortly after Veriff).';
  /// Weekly HeyCaby driver platform fee (after free starter rides).
  static const String platformFeeTitle = 'Platformfee';
  static String platformFeeBody(String euros) =>
      'Je hebt je startritten gebruikt. Betaal €$euros voor 7 dagen platformtoegang om weer online te gaan.';
  static const String platformFeePay = 'Betaal nu';
  static const String platformFeeCheckoutTitle = 'Betaling';
  static const String platformFeeStartingCheckout = 'Betaling voorbereiden…';
  static const String platformFeeInvalidUrl = 'Ongeldige betaallink. Probeer opnieuw.';
  static const String platformFeeStatusError =
      'Kon je status niet ophalen. Controleer je verbinding.';
  static const String platformFeeStartError = 'Betaling starten mislukt. Probeer opnieuw.';
  static const String platformFeeStillPending =
      'Betaling nog niet bevestigd. Wacht even of probeer opnieuw.';
  static const String licenceSubmittedPendingReview =
      'Submitted — our team confirms your licence after reviewing Veriff.';
  static const String docSavePermanentTitle = 'Save permanently?';
  static const String docSavePermanentBody =
      'After you save, you cannot change this in the app. Wrong or fraudulent information can lead to being banned. '
      'To correct a mistake later, contact customer support.';
  static const String docSaveInsuranceBody =
      'After you save, you cannot change these details in the app. Taxi insurance is required; we may audit entries. '
      'To update later, contact support.';
  static const String docSaveConfirm = 'Save';
  static const String fieldLockedContactSupport =
      'Saved — contact support to change this.';
  static const String insuranceAccuracyWarning =
      'Enter accurate insurer, policy number, and expiry. Upload a clear photo of your insurance document.';
  /// Home banner when `profile_status` is pending admin review.
  static const String verificationPendingTitle = 'Documents under review';
  static const String verificationPendingBody =
      'Our team is checking your chauffeur card and KvK details. You will be able to go online when your profile is verified.';
  static const String congratsTitle = 'Welcome to HeyCaby!';
  static String congratsTitleWithName(String name) => 'Welcome to HeyCaby, $name!';
  static const String congratsBody =
      'Your profile is approved. You can now receive ride requests.';
  static const String congratsStart = 'Start my first ride';
  static const String congratsInvite = 'Invite friends';
  static const String recentPassengerComments = 'Recent passenger comments';
  static const String whatReducedMyScore = 'What reduced my score?';
  static const String scoreFactorsDesc =
      'Your score is based on passenger ratings and your acceptance rate. Declined ride requests and lower ratings from passengers can reduce your score.';
  static const String ridesThisWeek = "Rides this week";
  static const String taxSummary = "Tax summary";
  static const String viewDetails = "View details";
  static const String goBackOnline = "Go back online";
  static const String locationRequired = 'Location required';
  static const String locationRequiredMessage =
      'HeyCaby needs your location to show the map, find rides, and navigate. '
      'Without location you cannot use the driver app.';
  static const String enableLocation = 'Enable location';
  static const String tryAgain = 'Try again';

  // Rate profiles / Driver Hub
  static const String activeRates = 'Active rates';
  static const String manageRates = 'Manage rates';
  static const String driverHub = 'Driver hub';
  static const String driverHubSubtitle =
      'Beheer je doelen, tarieven en veiligheid.';
  static const String goalsSectionTitle = 'Doelen';
  static const String goalsSectionHelper =
      'Stel een doel in en zie hoeveel je nog nodig hebt.';
  static const String earnedLabel = 'verdiend';
  static String remainingToGoal(String amount) => 'Nog €$amount tot je doel';
  static const String setGoalButton = 'Doel instellen';
  static const String earningsTarget = 'Dagdoel';
  static const String setTarget = 'Doel instellen →';
  static const String daily = 'Dag';
  static const String weekly = 'Week';
  static const String dailyLong = 'Dagelijks';
  static const String weeklyLong = 'Wekelijks';
  static const String ratesSectionTitle = 'Jouw tarieven';
  static const String ratesSectionHelper =
      'Dit rekenen passagiers: start + per km + per minuut + wachten.';
  static const String rateStart = 'Start';
  static const String ratePerKm = 'Per km';
  static const String ratePerMin = 'Per min';
  static const String rateWaiting = 'Wachten';
  static const String manageRatesLink = 'Tarieven beheren →';
  static const String safetySectionTitle = 'Veiligheid';
  static const String call112 = '112 bellen';
  static const String safetyToolkit = 'Veiligheidskit';
  static const String emergencyCall = 'Alarmnummer bellen';
  static const String emergencyCallSubtitle = '112 — politie en ambulance';
  static const String shareTripDetails = 'Rit details delen';
  static const String shareTripSubtitleActive = 'Deel je huidige rit';
  static const String shareTripSubtitleInactive =
      'Beschikbaar tijdens actieve rit';
  static const String audioRecording = 'Audio opname';
  static const String audioRecordingSubtitleActive = 'Opname starten';
  static const String audioRecordingSubtitleInactive =
      'Beschikbaar tijdens actieve rit';
  static const String recordingInProgress = 'Opname loopt…';
  static const String helpSectionTitle = 'Hulp';
  static const String chatWithSupport = 'Chat met support';
  static const String chatWithSupportHelper =
      'We reageren meestal binnen enkele uren.';
  static const String recentTickets = 'Recente tickets';
  static const String helpAndSupport = 'Help & ondersteuning';
  static const String seeAllTickets = 'Alles zien →';
  static const String sendMessage = 'Stuur een bericht';
  static const String messages = 'Berichten';
  static const String helpArticles = 'Help artikelen';
  static const String proToolsTitle = 'Pro tools';
  static const String ticketStatusNoResponse = 'U heeft niet gereageerd';
  static const String ticketStatusInProgress = 'In behandeling';
  static const String ticketStatusResolved = 'Opgelost';
  static const String driverPowerMode = 'Driver Power Mode';
  static const String driverPowerModeSubtitle =
      'AI-suggesties om meer te verdienen';
  static const String driverUnionMode = 'Driver Union Mode';
  static const String driverUnionModeSubtitle = 'Live marktintelligentie';
  static const String save = 'Opslaan';

  // Return trips
  static const String returnTrips = 'Retourritten';
  static const String yourReturnDiscount = 'Jouw retourkorting';
  static const String returnDiscountSharedCosts =
      'Reiskosten gedeeld met passagier';
  static const String matchChance = 'Match kans';
  static const String accept = 'Accepteren';

  // Status timestamps
  static const String onlineSince = 'Online · since';
  static const String onBreakSince = 'On break · since';

  // Support chat (our additions)
  static const String ondersteuning = 'Ondersteuning';
  static const String nieuwBericht = 'Nieuw bericht';
  static const String berichten = 'Berichten';
  static const String helpArtikelen = 'Help artikelen';
  static const String veelgesteldeVragen = 'Veelgestelde vragen';
  static const String recenteRitten = 'Recente ritten met problemen';
  static const String alleZien = 'Alles zien';
  static const String versturen = 'Versturen';
  static const String geenBerichten = 'Geen berichten';
  static const String berichtTypen = 'Typ een bericht...';
  static const String supportChatSendFailed =
      'Bericht kon niet worden verstuurd. Probeer opnieuw.';
  static const String supportAiAssistantName = 'Lee';
  static const String ritProbleem = 'Rit probleem';
  static const String betaling = 'Betaling';
  static const String account = 'Account';
  static const String overige = 'Overige';
  static const String open = 'Open';

  // Profile settings
  static const String mijnVoertuig = 'Mijn voertuig';
  static const String documenten = 'Documenten';
  static const String werkgebied = 'Werkgebied';
  static const String taal = 'Taal';
  static const String thema = 'Thema';
  static const String meldingen = 'Meldingen';
  static const String privacyBeleid = 'Privacy beleid';
  static const String gebruiksvoorwaarden = 'Gebruiksvoorwaarden';

  // FAQ / Terms / Privacy
  static const String faq = 'Veelgestelde vragen';
  static const String termsOfService = 'Gebruiksvoorwaarden';
  static const String privacyPolicy = 'Privacy beleid';

  // Today's rides
  static const String geenRittenVandaag = 'Geen ritten vandaag';

  static String scheduledRidesCount(int count) =>
      count == 1 ? '1 $ride' : '$count $rides';

  static String endShiftBody(String hours, String minutes, int rideCount) =>
      'Je hebt $hours uur $minutes minuten gereden en $rideCount ritten voltooid vandaag.';
  static const String dienstBeeindigen = 'Dienst beëindigen';

  // Pre-ride confirmation (scheduled rides, optional €1–5 via Tikkie)
  static const String prerideReliabilityNew = 'Nieuw';
  static const String prerideReliabilityReliable = 'Betrouwbaar';
  static const String prerideReliabilityAmber = 'Weinig historie';
  static const String prerideReliabilityRisk = 'Let op: annuleringen';
  static const String prerideAskWithFee = 'Bevestiging vragen →';
  static const String prerideAskNoFee = 'Bevestig zonder bijdrage';
  static const String prerideReleaseRide = 'Rit vrijgeven';
  static const String prerideMarkTikkieReceived = 'Tikkie ontvangen';
  static const String prerideAwaitingRider = 'Wacht op reiziger';
  static const String prerideRiderConfirmed = 'Reiziger bevestigd';
  static const String prerideModalTitle = 'Bevestigingsverzoek';
  static const String prerideModalTikkieHint =
      'Je ontvangt een Tikkie-link om te delen met de reiziger in de chat.';
  static const String prerideTikkieUrlLabel = 'Tikkie-link (plakken)';
  static const String prerideSendRequest = 'Stuur bevestigingsverzoek';
  static const String prerideFeeLabel = 'Bijdrage (max €5)';
  static const String prerideErrorGeneric = 'Kon actie niet uitvoeren. Probeer opnieuw.';
  static const String prerideErrorOutsideWindow =
      'Alleen ongeveer 16–40 minuten voor de rit kun je dit versturen.';
  static const String prerideErrorDeadlineNotPassed =
      'Je kunt pas vrijgeven na de deadline van de reiziger.';
  static const String myAssignedScheduled = 'Mijn geplande ritten';
  static const String openScheduledRequests = 'Open aanvragen';
}
