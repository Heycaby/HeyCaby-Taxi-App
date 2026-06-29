// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Dutch Flemish (`nl`).
class AppLocalizationsNl extends AppLocalizations {
  AppLocalizationsNl([String locale = 'nl']) : super(locale);

  @override
  String get appName => 'HeyCaby';

  @override
  String get hello => 'Hallo';

  @override
  String get rider => 'Reiziger';

  @override
  String get tagline => 'Verbind met taxichauffeurs in jouw buurt.';

  @override
  String get continueButton => 'Doorgaan';

  @override
  String get bookRide => 'Rit boeken';

  @override
  String get whereAreYouGoing => 'Waar ga je heen?';

  @override
  String get searchScheduleHint => 'Nu, of kies datum en tijd';

  @override
  String get searchStartTypingHint =>
      'Typ minimaal 3 tekens om op de kaart te zoeken.';

  @override
  String get searchBrowseSavedPlaces => 'Alle opgeslagen plekken';

  @override
  String get searchBrowseRecentPlaces => 'Recent bekijken';

  @override
  String get searchRecentOnDeviceSection => 'Recent op dit apparaat';

  @override
  String get searchRecentOnDeviceSubtitle =>
      'Laatste 10 plekken op deze telefoon — los van opgeslagen plekken.';

  @override
  String get searchNoLocalRecentsYet =>
      'Nog geen recente adressen. Zoek een plek en kies hem — we bewaren de laatste 10 hier zodat de volgende zoekslag sneller kan.';

  @override
  String get searchLocalMatchesHeader => 'Treffers op dit apparaat';

  @override
  String get whereTo => 'Waar naartoe?';

  @override
  String get homeDestinationPrompt => 'Waar wil je naartoe?';

  @override
  String get homeContinue => 'Doorgaan';

  @override
  String get homeSmartOptionsTitle => 'Hoe wil je rijden?';

  @override
  String get homeBestPriceTitle => 'Marktplaats';

  @override
  String get homeBestPriceSubtitle => 'Chauffeurs strijden om jouw rit.';

  @override
  String get homeScheduleLaterTitle => 'Later plannen';

  @override
  String get homeScheduleLaterSubtitle =>
      'Kies een ophaaltijd die voor jou werkt.';

  @override
  String get homePopularAirportsTitle => 'Populair';

  @override
  String get homeRecentTrips => 'Recente ritten';

  @override
  String get homeGreetingMorning => 'Goedemorgen,';

  @override
  String get homeGreetingAfternoon => 'Goedemiddag,';

  @override
  String get homeGreetingEvening => 'Goedenavond,';

  @override
  String get homeEnterDestination => 'Voer je bestemming in';

  @override
  String get homeNoTaxisNearbySubtitle =>
      'Je kunt een rit aanvragen — we laten het weten zodra er een chauffeur beschikbaar is.';

  @override
  String get homeRideAgainTitle => 'Opnieuw rijden';

  @override
  String get homeRideAgainViewAll => 'Alles bekijken';

  @override
  String get homeRideAgainBookAgain => 'Opnieuw boeken';

  @override
  String get homeRideAgainUsuallyAvailable => 'Meestal beschikbaar';

  @override
  String get homeRideAgainAvailableNow => 'Nu beschikbaar';

  @override
  String homeRideAgainDriverStats(String rating, int count) {
    return '$rating ★ • $count ritten';
  }

  @override
  String get homeRecentPlacesTitle => 'Recente plaatsen';

  @override
  String get homeRecentPlacesEdit => 'Bewerken';

  @override
  String get homeCompleteProfile => 'Profiel aanvullen';

  @override
  String get vehicleCategoryTitle => 'Welk type rit wil je?';

  @override
  String get homeAirportChipSchiphol => 'Schiphol';

  @override
  String get homeAirportChipRotterdam => 'Rotterdam Airport';

  @override
  String get homeAirportChipEindhoven => 'Eindhoven';

  @override
  String get homeAirportChipBrussels => 'Brussel Airport';

  @override
  String get pickup => 'Ophaallocatie';

  @override
  String get destination => 'Bestemming';

  @override
  String get findMyDriver => 'Zoek mijn chauffeur';

  @override
  String get searching => 'Chauffeur zoeken...';

  @override
  String get driverAssigned => 'Chauffeur onderweg';

  @override
  String driverReturnTripDiscount(int pct) {
    return '$pct% korting retourrit';
  }

  @override
  String get driverArrived => 'Je chauffeur is er';

  @override
  String get tripInProgress => 'Rit bezig';

  @override
  String get tripComplete => 'Rit voltooid';

  @override
  String get cancel => 'Annuleren';

  @override
  String get confirm => 'Bevestigen';

  @override
  String get confirmDestination => 'Bestemming bevestigen';

  @override
  String get rateYourDriver => 'Beoordeel je chauffeur';

  @override
  String get howWasYourRide => 'Hoe was je rit?';

  @override
  String get whatDidYouLike => 'Wat vond je goed?';

  @override
  String get additionalFeedback => 'Extra feedback (optioneel)';

  @override
  String get tellUsMore => 'Vertel ons meer over je ervaring...';

  @override
  String get submitRating => 'Beoordeling Versturen';

  @override
  String get ratingCategorySectionTitle => 'Beoordeel specifieke onderdelen';

  @override
  String get ratingCategorySubtitle =>
      'Elk onderdeel 1–5 sterren. Ze beginnen gelijk aan je totaal — pas aan wat anders voelde.';

  @override
  String get ratingDimensionPunctuality => 'Stiptheid';

  @override
  String get ratingDimensionCleanliness => 'Netheid';

  @override
  String get ratingDimensionAttitude => 'Houding';

  @override
  String get ratingDimensionDrivingSafety => 'Rijveiligheid';

  @override
  String get ratingDimensionCommunication => 'Communicatie';

  @override
  String get recentDestinations => 'Recente bestemmingen';

  @override
  String recentDestinationsShowMore(int count) {
    return 'Toon $count meer';
  }

  @override
  String get recentDestinationsShowLess => 'Toon minder';

  @override
  String get recentDestinationRemoveHint => 'Verwijder uit recent';

  @override
  String get recentDestinationRemoveFailed =>
      'Kon deze plek niet verwijderen. Probeer opnieuw.';

  @override
  String get whatWentWrong => 'Wat ging er mis?';

  @override
  String get helpUsUnderstand =>
      'Help ons het probleem te begrijpen zodat we kunnen verbeteren';

  @override
  String get additionalDetails => 'Extra details';

  @override
  String get pleaseProvideMoreDetails =>
      'Geef alstublieft meer details over het probleem...';

  @override
  String get submitReport => 'Rapport Versturen';

  @override
  String get reportSubmitted => 'Rapport succesvol verstuurd';

  @override
  String get reportSubmitFailed => 'Rapport versturen mislukt';

  @override
  String get fareEstimate => 'Geschatte prijs';

  @override
  String scheduledFor(String date) {
    return 'Gepland voor $date';
  }

  @override
  String get noDriversNearby => 'Geen chauffeurs in de buurt';

  @override
  String get connectionProblem => 'Verbindingsprobleem. Probeer opnieuw.';

  @override
  String get rideBookingFailed =>
      'De rit kon niet starten — autorisatie is door de server geweigerd. Vernieuw je sessie (uitloggen en opnieuw inloggen) en probeer daarna opnieuw.';

  @override
  String get locationPermissionRequired =>
      'Locatietoegang is nodig om ophaallocatie in te stellen en chauffeurs te vinden.';

  @override
  String get locationRequired => 'Locatie vereist';

  @override
  String get locationRequiredMessage =>
      'HeyCaby heeft je locatie nodig voor een nauwkeurig ophaalpunt, het vinden van chauffeurs in de buurt en betrouwbare aankomsttijden. Zonder locatietoegang kunnen we je niet goed helpen en kun je geen rit boeken.';

  @override
  String get enableLocation => 'Locatie inschakelen';

  @override
  String get tryAgain => 'Probeer opnieuw';

  @override
  String get enterAddressManually => 'Adres handmatig invoeren';

  @override
  String get home => 'Home';

  @override
  String get rides => 'Ritten';

  @override
  String get account => 'Account';

  @override
  String get tellAFriendNavLabel => 'Community';

  @override
  String get tellAFriendNavSemanticLabel =>
      'Groei je stad — bouw de HeyCaby-gemeenschap';

  @override
  String get tellAFriendScreenTitle => 'Groei je stad';

  @override
  String get tellAFriendSharePrompt =>
      'Deel HeyCaby met mensen die een rit nodig hebben in jouw stad. Elke nieuwe passagier helpt lokale taxichauffeurs.';

  @override
  String get tellAFriendHeroTitle => 'Vrienden uitnodigen';

  @override
  String get tellAFriendHeroSubtitle => 'Deel je link met één tik.';

  @override
  String get tellAFriendBodyLine1 => 'Vergroot je ritkring in de buurt.';

  @override
  String get tellAFriendBodyLine2 =>
      'Meer vertrouwde passagiers kan snellere matches betekenen.';

  @override
  String get tellAFriendFriendsInvitedLabel => 'Vrienden uitgenodigd';

  @override
  String get tellAFriendFriendsInvitedZeroHint =>
      'Nog niemand — deel hieronder.';

  @override
  String get tellAFriendRewardTitle => 'Waarom helpen?';

  @override
  String get tellAFriendRewardBullet1 => 'Meer passagiers in de buurt';

  @override
  String get tellAFriendRewardBullet2 => 'Meer ritverzoeken voor chauffeurs';

  @override
  String get tellAFriendRewardBullet3 => 'Kortere wachttijden';

  @override
  String get tellAFriendRewardBullet4 => 'Sterkere taxigemeenschap';

  @override
  String get tellAFriendInviteLinkLabel => 'App Store-link';

  @override
  String get tellAFriendWebsiteLinkLabel => 'Deel link';

  @override
  String get tellAFriendLinkResolving => 'Je korte uitnodigingslink ophalen…';

  @override
  String get tellAFriendCopyLink => 'Link kopiëren';

  @override
  String get tellAFriendShareLink => 'Deel HeyCaby';

  @override
  String get tellAFriendShowQr => 'QR-code';

  @override
  String get tellAFriendQrTitle => 'Scan om mee te doen op HeyCaby';

  @override
  String get tellAFriendQrHint =>
      'Scannen opent de HeyCaby Rider-app in de App Store. Gebruik Delen of Kopiëren voor je downloadlink.';

  @override
  String get tellAFriendSocialProof =>
      'Bedankt dat je helpt het grootste onafhankelijke taxinetwerk van Nederland te bouwen.';

  @override
  String get tellAFriendShareDoneSnackbar =>
      'Bedankt voor het delen van HeyCaby!';

  @override
  String get tellAFriendLinkCopied => 'Gekopieerd — plakken waar je wilt';

  @override
  String get tellAFriendShareSubject => 'Doe mee met HeyCaby — groei je stad';

  @override
  String get tellAFriendShareMessage =>
      'Download HeyCaby Rider — de onafhankelijke taxi-app voor Nederland:';

  @override
  String get tellAFriendLinkUnavailable => 'App Store-link niet geconfigureerd';

  @override
  String get tellAFriendLinkUnavailableHint =>
      'Voeg RIDER_IOS_APP_STORE_URL toe aan je build-omgeving en bouw de app opnieuw.';

  @override
  String growCityHeroTitle(String cityName) {
    return 'Laat HeyCaby groeien in $cityName';
  }

  @override
  String get growCityHeroBody1 =>
      'Nodig vrienden en familie uit die betrouwbaar taxivervoer nodig hebben in jouw stad.';

  @override
  String get growCityHeroBody2 =>
      'Meer passagiers in de buurt betekent meer ritten voor lokale chauffeurs en kortere wachttijden voor iedereen.';

  @override
  String get growCityHeroMission =>
      'Help ons het grootste onafhankelijke taxinetwerk van Nederland te bouwen.';

  @override
  String growCityCommunityTitle(String cityName) {
    return '$cityName-gemeenschap';
  }

  @override
  String get growCityDriversLabel => 'Chauffeurs';

  @override
  String get growCityRidersLabel => 'Passagiers';

  @override
  String get growCityMonthlyRidersLabel => 'Maandelijkse passagiers';

  @override
  String get growCityMonthlyDriversLabel => 'Maandelijkse chauffeurs';

  @override
  String get growCityMilestoneLabel => 'Volgende mijlpaal';

  @override
  String get growCityDriverCapLabel => 'Chauffeursnetwerk-limiet';

  @override
  String get growCityRiderCapLabel => 'Maandelijkse passagiers-visie';

  @override
  String growCityProgressCount(String current, String milestone) {
    return '$current / $milestone';
  }

  @override
  String growCityMilestoneHint(String remaining, String milestone) {
    return 'Nog $remaining maandelijkse passagiers tot we $milestone vieren.';
  }

  @override
  String get growCityFinalGoalReached =>
      'We hebben 1 miljoen maandelijkse passagiers in Nederland bereikt. Bedankt dat je HeyCaby met ons laat groeien.';

  @override
  String get growCityMilestoneCelebrationTitle => 'Mijlpaal bereikt!';

  @override
  String growCityMilestoneCelebrationBody(String milestone) {
    return 'De HeyCaby-community heeft $milestone maandelijkse passagiers in Nederland bereikt. Bedankt voor je hulp — door naar de volgende mijlpaal!';
  }

  @override
  String get growCityMilestoneCelebrationCta => 'Laten we doorgroeien';

  @override
  String get growCityImpactTitle => 'Jouw impact';

  @override
  String get growCityPeopleInvited => 'Passagiers uitgenodigd';

  @override
  String get growCityJoined => 'Aangemeld';

  @override
  String get growCityCompletedRides => 'Voltooide ritten';

  @override
  String get growCityBadgesTitle => 'Community-badges';

  @override
  String get growCityBadgeSupporter => 'Community Supporter';

  @override
  String get growCityBadgeBuilder => 'Community Builder';

  @override
  String get growCityBadgeAmbassador => 'Stadsambassadeur';

  @override
  String get growCityBadgeTopPromoter => 'Top Promoter';

  @override
  String get growCityWhyHelpTitle => 'Waarom helpen?';

  @override
  String get growCityWhyHelpBullet1 => 'Meer passagiers in de buurt';

  @override
  String get growCityWhyHelpBullet2 => 'Meer werk voor lokale taxichauffeurs';

  @override
  String get growCityWhyHelpBullet3 => 'Kortere wachttijden';

  @override
  String get growCityWhyHelpBullet4 => 'Sterkere taxigemeenschap';

  @override
  String get growCityPitchLine =>
      'Nodig mensen uit die taxi nodig hebben in jouw stad.';

  @override
  String get growCityPitchBenefit =>
      'Meer passagiers in de buurt → meer chauffeurs en kortere wachttijden.';

  @override
  String growCityProgressHeader(
      String region, String current, String milestone) {
    return '$region · $current / $milestone maandelijkse passagiers';
  }

  @override
  String growCityCompactDrivers(String count) {
    return '$count chauffeurs';
  }

  @override
  String growCityCompactRiders(String count) {
    return '$count passagiers';
  }

  @override
  String get growCityLearnMore => 'Waarom dit helpt';

  @override
  String growCityImpactCompact(int invited, int joined) {
    return '$invited uitgenodigd · $joined aangemeld';
  }

  @override
  String get growCityWhySheetDone => 'Begrepen';

  @override
  String get growCityRegionNetherlands => 'Nederland';

  @override
  String get iosUpdateRequiredTitle => 'Werk iOS bij';

  @override
  String iosUpdateRequiredBody(String minimumVersion, String currentVersion) {
    return 'HeyCaby vereist iOS $minimumVersion of nieuwer. Deze iPhone draait iOS $currentVersion. Ga naar Instellingen → Algemeen → Software-update om de nieuwste iOS voor je toestel te installeren.';
  }

  @override
  String iosUpdateRequiredFooter(String minimumVersion) {
    return 'Als je toestel niet kan upgraden naar iOS $minimumVersion, heb je een nieuwere iPhone nodig voor HeyCaby.';
  }

  @override
  String get scheduledCommitmentDisclosure =>
      'Je chauffeur kan tot 40 minuten voor je rit om een kleine bevestigingsbijdrage van maximaal €5 vragen. Dit bedrag wordt afgetrokken van je rijtotaal. Als jij of de chauffeur daarna annuleert, gelden de annuleringsregels.';

  @override
  String get prerideBannerTitle => 'Bevestig je rit';

  @override
  String get prerideBannerSubtitle =>
      'Je chauffeur wacht op je bevestiging vóór de rit.';

  @override
  String get prerideOpenTikkie => 'Open Tikkie';

  @override
  String get prerideConfirmAttending => 'Ik kom';

  @override
  String get prerideConfirmedThanks => 'Bedankt — je bent bevestigd.';

  @override
  String get myRides => 'Mijn ritten';

  @override
  String get myDrivers => 'Mijn chauffeurs';

  @override
  String get myDriversHomeSubtitle => 'Rijd met iemand die je vertrouwt';

  @override
  String get favouriteDrivers => 'Mijn chauffeurs';

  @override
  String get favouriteDriversSubtitle =>
      'Jouw netwerk van vertrouwde chauffeurs';

  @override
  String favouriteDriversSubtitleWithCount(int count) {
    return '$count chauffeurs in jouw netwerk';
  }

  @override
  String get noFavouritesYet => 'Nog geen favorieten';

  @override
  String get paymentMethod => 'Betaalmethode';

  @override
  String get cash => 'Contant';

  @override
  String get pin => 'PIN';

  @override
  String get tikkie => 'Tikkie';

  @override
  String get instantRide => 'Direct';

  @override
  String get scheduledRide => 'Plannen';

  @override
  String get marketplace => 'Marktplaats';

  @override
  String get marketplaceTagline => 'Chauffeurs strijden om jouw rit.';

  @override
  String get makeAnOffer => 'Marktplaats';

  @override
  String get marketplacePostRequest => 'Plaats verzoek';

  @override
  String get marketplaceOfferHeadline => 'Kies wat je wilt betalen.';

  @override
  String get marketplaceOfferExplanation =>
      'Chauffeurs die al jouw richting op rijden kunnen je bod accepteren of een ander prijsvoorstel doen.';

  @override
  String get marketplaceDriversAcceptHint =>
      'Chauffeurs kunnen accepteren, tegenbieden of negeren — HeyCaby bepaalt niet de prijs.';

  @override
  String marketplaceDriversOnline(int count) {
    return '$count chauffeurs online';
  }

  @override
  String get marketplaceWhereAreYouGoing => 'Waar ga je naartoe?';

  @override
  String get marketplaceYouAreHere => 'Je bent hier';

  @override
  String marketplaceYouAreHereIn(String area) {
    return 'Je bent hier in $area';
  }

  @override
  String marketplaceYouAreHereOn(String street) {
    return 'Je bent op $street';
  }

  @override
  String get marketplaceLocatingYou => 'Locatie ophalen…';

  @override
  String get marketplaceLocationNeeded =>
      'Zet locatie aan om te zien waar je bent';

  @override
  String get marketplaceNameYourPrice => 'Noem je prijs';

  @override
  String get marketplaceNameYourPriceSubtitle =>
      'Chauffeurs zien je bod en reageren.';

  @override
  String marketplaceTypicalRangeLabel(String range) {
    return 'Typisch bereik: $range';
  }

  @override
  String get marketplaceControlBanner =>
      'Jij bepaalt. Chauffeurs kunnen accepteren, tegenbieden of negeren.';

  @override
  String get marketplaceFasterOffersTip =>
      'Sneller reacties? Verhoog je prijs voor meer aanbiedingen.';

  @override
  String get marketplaceEnterCustomPrice => 'Tik om een bedrag in te typen';

  @override
  String get marketplacePriceHint => '50';

  @override
  String marketplaceBidRangeHint(int min, int max) {
    return 'Je kunt bieden tussen €$min en €$max';
  }

  @override
  String get marketplaceTypicalFareTitle => 'Gebruikelijke prijs';

  @override
  String get marketplaceYourOfferTitle => 'Jouw bod';

  @override
  String get marketplaceRequestOffers => 'Vraag aanbiedingen';

  @override
  String get marketplaceMatchingTitle => 'Marktplaats';

  @override
  String get marketplaceMatchingHeadline => 'Chauffeurs zoeken…';

  @override
  String get marketplaceMatchingNotifySubtitle =>
      'We sturen je een melding zodra er aanbiedingen zijn.';

  @override
  String marketplaceDriversReceivedRequest(int count) {
    return '$count chauffeurs hebben je verzoek ontvangen';
  }

  @override
  String get marketplaceExpectedWait => 'Verwachte wachttijd: 1 – 2 min';

  @override
  String get marketplaceOffersFromDrivers => 'Aanbiedingen van chauffeurs';

  @override
  String get marketplaceRecommended => 'Aanbevolen';

  @override
  String get marketplaceViewProfile => 'Profiel bekijken';

  @override
  String get marketplaceOfferAcceptsYourPrice => 'Accepteert je bod';

  @override
  String get marketplaceOfferCounterLabel => 'Tegenbod';

  @override
  String get marketplaceOffersExpireIn => 'Aanbiedingen verlopen over';

  @override
  String get marketplaceBoostOffer => 'Verhoog je bod';

  @override
  String get marketplaceBoostOfferSubtitle =>
      'Verhoog de prijs voor meer aanbiedingen';

  @override
  String get marketplaceCancelRequest => 'Verzoek annuleren';

  @override
  String get marketplaceCancelRequestConfirm =>
      'Chauffeurs zien je bod niet meer. Dit verzoek annuleren?';

  @override
  String get marketplaceReceiveChooseTitle => 'Ontvang & kies aanbiedingen';

  @override
  String get marketplaceReceiveChooseBullet1 =>
      'Chauffeurs accepteren of bieden tegen';

  @override
  String get marketplaceReceiveChooseBullet2 =>
      'Vergelijk prijs, rating en ETA';

  @override
  String get marketplaceReceiveChooseBullet3 => 'Kies de beste match';

  @override
  String marketplaceMatchingSubhead(int nearby, int received) {
    return '$nearby in de buurt · $received aanbiedingen';
  }

  @override
  String get marketplaceMatchingWaiting => 'Wachten op reacties';

  @override
  String get marketplaceMatchingWaitingBody =>
      'Onafhankelijke chauffeurs kunnen accepteren, tegenbieden of negeren. Jij kiest met wie je rijdt.';

  @override
  String marketplaceOfferAccepts(String price) {
    return 'Accepteert $price';
  }

  @override
  String marketplaceOfferCounter(String price) {
    return 'Tegenbod $price';
  }

  @override
  String marketplaceOfferMinutesAway(int minutes) {
    return '$minutes min verwijderd';
  }

  @override
  String marketplaceOfferExpiresIn(String time) {
    return 'Aanbod verloopt $time';
  }

  @override
  String get marketplaceDriverUsuallyAccepts =>
      'Accepteert meestal riderprijzen';

  @override
  String get marketplaceDriverOftenCounters => 'Stuurt vaak tegenbiedingen';

  @override
  String get marketplaceDriverMayCounter => 'Kan accepteren of tegenbieden';

  @override
  String get declineBid => 'Weiger';

  @override
  String get marketplaceDriverScopeTitle => 'Wie ziet je verzoek?';

  @override
  String get marketplaceDriverScopeEveryone => 'Iedereen';

  @override
  String get marketplaceDriverScopeMyDriversFirst => 'Mijn chauffeurs eerst';

  @override
  String get marketplaceDriverScopeMyDriversOnly => 'Alleen mijn chauffeurs';

  @override
  String get marketplaceAcceptanceGood => 'Goede kans op acceptatie';

  @override
  String get marketplaceAcceptanceFair =>
      'Redelijk bod — chauffeurs kunnen accepteren of tegenbieden';

  @override
  String get marketplaceAcceptanceLow =>
      'Bod is vrij laag — verwacht tegenbiedingen';

  @override
  String get marketplaceDemandLowTitle => 'Lage vraag';

  @override
  String get marketplaceDemandHighTitle => 'Hoge vraag';

  @override
  String get marketplaceDemandLowHint =>
      'Chauffeurs accepteren waarschijnlijk lagere biedingen.';

  @override
  String get marketplaceDemandHighHint =>
      'Iets meer bieden kan snellere reacties geven.';

  @override
  String get marketplaceSubtitle =>
      'Kies je prijs — onafhankelijke chauffeurs beslissen.';

  @override
  String get homeAirportBookingTitle => 'Naar de luchthaven';

  @override
  String get homeAirportBookingSubtitle =>
      'Schiphol, Zaventem, Luxemburg & meer — één tik';

  @override
  String get homeAirportBookingBadge => 'Snel';

  @override
  String get airportBookingScreenTitle => 'Rit naar de luchthaven';

  @override
  String get airportBookingScreenSubtitle =>
      'Kies je luchthaven. Ophaaladres blijft je huidige locatie, tenzij je het in de volgende stap wijzigt.';

  @override
  String get airportBookingSearchHint => 'Zoek op luchthaven, stad of code';

  @override
  String get airportBookingNoResults => 'Geen luchthaven gevonden.';

  @override
  String get airportSectionNetherlands => 'NEDERLAND';

  @override
  String get airportSectionBelgium => 'BELGIË';

  @override
  String get airportSectionLuxembourg => 'LUXEMBURG';

  @override
  String get favouritesOnly => 'Favoriete chauffeurs eerst';

  @override
  String get offerFare => 'Bied je prijs';

  @override
  String get bids => 'Biedingen';

  @override
  String get acceptBid => 'Accepteren';

  @override
  String get notifyMe => 'Meld me als beschikbaar';

  @override
  String get rideHistory => 'Ritgeschiedenis';

  @override
  String get reportDriver => 'Chauffeur melden';

  @override
  String get support => 'Ondersteuning';

  @override
  String get settings => 'Instellingen';

  @override
  String get language => 'Taal';

  @override
  String get languageFollowDevice => 'Taal van apparaat';

  @override
  String get languageFollowDeviceSubtitle =>
      'Volgt de instellingen van je telefoon';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageDutch => 'Nederlands';

  @override
  String get languageArabic => 'العربية';

  @override
  String get theme => 'Thema';

  @override
  String get homeAddress => 'Thuisadres';

  @override
  String get savedAddresses => 'Opgeslagen plaatsen';

  @override
  String get logout => 'Uitloggen';

  @override
  String distance(String km) {
    return '$km km';
  }

  @override
  String duration(String min) {
    return '$min min';
  }

  @override
  String get bestPrice => 'Beste prijs';

  @override
  String get howHeyCabyWorks => 'Hoe HeyCaby werkt';

  @override
  String get zeroCommission => 'Nul commissie — eerlijk voor iedereen';

  @override
  String get driverEarns100 => 'Je chauffeur verdient 100% van de rit';

  @override
  String get noShowWarning => 'Boek alleen als je klaar staat op je locatie';

  @override
  String get communityPledge =>
      'Boek alleen als je klaar staat op je locatie. Onze chauffeurs betalen brandstof per oproep.';

  @override
  String get namePlaceholder => 'Hoe moet de chauffeur je noemen?';

  @override
  String get welcomeProfileModalTitle => 'Welkom bij HeyCaby!';

  @override
  String get welcomeProfileModalBody =>
      'Om je rit makkelijk en snel te maken, raden we aan je profiel in te stellen. Zo boek je veel sneller.';

  @override
  String get setUpProfileNow => 'Nu instellen';

  @override
  String get welcomeDriverCallYouModalTitle =>
      'Hoe moet de chauffeur je noemen?';

  @override
  String get welcomeSkipDriverName => 'Niet nu';

  @override
  String get onboardingProfileBannerMessage =>
      'Vul je profiel aan om sneller te boeken.';

  @override
  String get saveAndContinue => 'Opslaan en doorgaan';

  @override
  String get onboardingNextAddEmail =>
      'Daarna: voeg je e-mail toe om adressen en favorieten op te slaan.';

  @override
  String get onboardingNameRequired => 'Vul je naam in om door te gaan.';

  @override
  String riderProfileCompletionPercent(String percent) {
    return 'Profiel $percent% compleet';
  }

  @override
  String get riderProfileCompleteTitle => 'Profiel compleet';

  @override
  String get riderProfileMeterName => 'Boekingsnaam';

  @override
  String get riderProfileMeterEmail => 'E-mail';

  @override
  String get riderProfileHomeNudgeTitle => 'Vul je profiel aan';

  @override
  String get riderProfileHomeNudgeBoth =>
      'Voeg naam en e-mail toe bij Account — elk telt voor 50%.';

  @override
  String get riderProfileHomeNudgeNameOnly =>
      'Voeg je boekingsnaam toe bij Account voor 100%.';

  @override
  String get riderProfileHomeNudgeEmailOnly =>
      'Voeg je e-mail toe bij Account voor 100%.';

  @override
  String get yourRoute => 'Jouw route';

  @override
  String get howDoYouWantToBook => 'Hoe wil je boeken?';

  @override
  String get howWillYouPay => 'Hoe betaal je?';

  @override
  String get laterButton => 'Later';

  @override
  String get tripSummary => 'Rit samenvatting';

  @override
  String get loading => 'Laden...';

  @override
  String get retry => 'Opnieuw proberen';

  @override
  String get error => 'Er is iets misgegaan';

  @override
  String get driverOnTheWay => 'Chauffeur onderweg';

  @override
  String eta(String min) {
    return 'Aankomsttijd $min min';
  }

  @override
  String get shareRide => 'Rit delen';

  @override
  String get chat => 'Chat';

  @override
  String get reportIssue => 'Probleem melden';

  @override
  String get rideComplete => 'Rit voltooid';

  @override
  String get leaveAComment => 'Laat een opmerking achter (optioneel)';

  @override
  String get submit => 'Verzenden';

  @override
  String get skip => 'Overslaan';

  @override
  String get back => 'Terug';

  @override
  String get next => 'Volgende';

  @override
  String get notifyMeWhenDriverFound =>
      'Je krijgt een melding wanneer een chauffeur is gevonden';

  @override
  String get cancelBookingTitle => 'Boeking annuleren?';

  @override
  String get cancelBookingMessage =>
      'Weet je zeker dat je wilt annuleren? Je ritgegevens gaan verloren.';

  @override
  String get keepGoing => 'Doorgaan';

  @override
  String get nameSavedSuccess => 'Naam succesvol opgeslagen';

  @override
  String get ridesFilterActive => 'Actief';

  @override
  String get ridesFilterBidding => 'Biedingen';

  @override
  String get ridesFilterCompleted => 'Voltooid';

  @override
  String get ridesFilterCancelled => 'Geannuleerd';

  @override
  String get ridesScreenSubtitle =>
      'Geplande ritten, live matching en je geschiedenis';

  @override
  String get ridesTabUpcoming => 'Aankomend';

  @override
  String get ridesTabHistory => 'Geschiedenis';

  @override
  String get upcomingRideDetailTitle => 'Ritdetails';

  @override
  String get upcomingRideMatchingProgressTitle => 'Zoeken naar een chauffeur';

  @override
  String get upcomingRideMatchingProgressBody =>
      'We matchen je met chauffeurs in de buurt. Open het live zoekscherm voor de radar en updates.';

  @override
  String get upcomingRideOpenLiveSearch => 'Open live zoeken';

  @override
  String get upcomingRideEditBookAgain => 'Adressen wijzigen';

  @override
  String get upcomingRideEditBookAgainSubtitle =>
      'Hiermee annuleer je dit verzoek, zodat je opnieuw kunt boeken met een andere ophaal- of bestemmingslocatie.';

  @override
  String get upcomingRideGoToActive => 'Ga naar live rit';

  @override
  String get upcomingRideDriverSection => 'Chauffeur';

  @override
  String get ridesUpcomingScheduledBadge => 'Gepland';

  @override
  String get ridesUpcomingMatchingBadge => 'Zoeken';

  @override
  String get ridesUpcomingEmptyTitle => 'Niets aankomend';

  @override
  String get ridesUpcomingEmptyBody =>
      'Boek een rit of plan er een — die verschijnt hier terwijl we je Caby zoeken.';

  @override
  String get ridesHistorySectionTitle => 'Eerdere ritten';

  @override
  String get searchAddressCouldNotResolve =>
      'We konden dit adres niet gebruiken. Kies een andere suggestie of zoek opnieuw.';

  @override
  String get saveBookingForLater => 'Bewaar voor later';

  @override
  String get searchAddressesContinue => 'Doorgaan';

  @override
  String get saveTripForNextTimeLabel =>
      'Deze rit bewaren voor de volgende keer';

  @override
  String get saveTripForNextTimeSubtitle =>
      'Slaat ophaal- en afzetadres op bij je recente plekken (als je bent ingelogd).';

  @override
  String get scheduledMatchingHeadline => 'We zoeken een chauffeur voor je.';

  @override
  String get scheduledMatchingSubhead =>
      'Chauffeurs zien je geplande rit en kunnen accepteren wanneer ze beschikbaar zijn.';

  @override
  String get matchingAlternativesTitleScheduled =>
      'Nog geen chauffeur. Probeer iets anders.';

  @override
  String get matchingTryMarketplace => 'Marktplaats';

  @override
  String get matchingAlternativesFabTooltip =>
      'Meer opties om een chauffeur te vinden';

  @override
  String get scheduledMatchingBackToHome => 'Start';

  @override
  String get scheduledMatchingCancelRide => 'Rit annuleren';

  @override
  String get scheduledMatchingMoreMenuTooltip => 'Meer';

  @override
  String get scheduledRideDetailsSheetTitle => 'Details geplande rit';

  @override
  String get marketplaceMatchingBannerTitle => 'Marktplaatsrit';

  @override
  String get marketplaceMatchingBannerBody =>
      'Chauffeurs kunnen bieden op je route. We matchen zodra iemand accepteert.';

  @override
  String get continueSavedBooking => 'Ga verder met opgeslagen boeking';

  @override
  String get continueSavedBookingHint => 'Ga verder waar je gebleven was.';

  @override
  String get scheduledRideQueuedTitle => 'Rit in de wachtrij';

  @override
  String get scheduledRideQueuedSubtitle =>
      'Chauffeurs zien je geplande rit en kunnen accepteren. We laten het weten zodra iemand is toegewezen.';

  @override
  String scheduledRideQueuedSubtitleWithTime(String when) {
    return 'Ophalen $when. Chauffeurs zien je rit en kunnen accepteren — we laten het weten zodra iemand is toegewezen.';
  }

  @override
  String get tripSummaryDropoffLabel => 'Afzet';

  @override
  String get tripSummarySubtitle => 'Controleer voordat je een chauffeur zoekt';

  @override
  String get tripSummaryPassengerRideSection => 'Passagier & rit';

  @override
  String get tripSummaryPaymentSection => 'Betaling';

  @override
  String get tripSummaryEdit => 'Bewerken';

  @override
  String get tripSummaryNameNotSet =>
      'Nog geen naam — voeg toe voor wie de chauffeur het moet vragen';

  @override
  String get smartBundleTitle => 'JE RITKLASSEN';

  @override
  String smartBundleIncludes(Object names) {
    return 'Inbegrepen: $names';
  }

  @override
  String get smartBundleExpandHint => 'Aanpassen';

  @override
  String get smartBundleTapToExpand => 'Tik om alle ritklassen te bekijken';

  @override
  String get smartBundleExpandSubtitle =>
      'Standaard, Comfort, taxibus, rolstoel en prijzen.';

  @override
  String get smartBundleFootnoteWide =>
      'Meer klassen — meestal sneller een match. De eerste chauffeur die accepteert bepaalt het tarief voor die klasse.';

  @override
  String get smartBundleFootnoteNarrow =>
      'Minder klassen — kan iets langer duren om een chauffeur te vinden.';

  @override
  String get smartBundleFootnoteSingle =>
      'Eén klasse — vaste schatting voor deze rit.';

  @override
  String smartBundlePriceBand(Object min, Object max) {
    return '€$min–€$max';
  }

  @override
  String smartBundlePriceSingle(Object price) {
    return '€$price';
  }

  @override
  String get smartBundlePetRowTitle => 'Huisdiervriendelijk';

  @override
  String get smartBundleLoadError =>
      'Prijzen per klasse laden mislukt. Kies hieronder een voertuig.';

  @override
  String get smartBundleRetry => 'Opnieuw proberen';

  @override
  String get favoriteDriversFirstTripDetail => 'Favoriete chauffeurs eerst';

  @override
  String get bookDriver => 'Boek chauffeur';

  @override
  String get postToAllDrivers => 'Plaats bij alle chauffeurs';

  @override
  String get vehiclePreferredCategoryUnavailable =>
      'Je opgeslagen voertuigtype is niet beschikbaar. We hebben Standaard gekozen.';

  @override
  String get vehiclePreferredNoDriversNearby =>
      'Geen chauffeurs voor je gebruikelijke voertuig in de buurt. We schakelden over naar een beschikbare optie.';

  @override
  String bookingUsualVehicleChip(String vehicle) {
    return 'Je gebruikelijk: $vehicle';
  }

  @override
  String get noRidesInCategory => 'Geen ritten in deze categorie';

  @override
  String get tryDifferentFilter => 'Probeer een ander filter';

  @override
  String get rideStatusCancelled => 'Geannuleerd';

  @override
  String get rideStatusSearching => 'Zoeken';

  @override
  String get rideStatusDriverAssigned => 'Chauffeur toegewezen';

  @override
  String get rideStatusDriverArrived => 'Chauffeur gearriveerd';

  @override
  String get rideStatusInProgress => 'Bezig';

  @override
  String get selectAllThatApply => 'Selecteer alles dat van toepassing is';

  @override
  String get morePaymentOptionsHint =>
      'Meer betaalopties = grotere kans op een chauffeur';

  @override
  String get chooseYourRide => 'Kies je rit';

  @override
  String get driverPayment => 'Chauffeur betaling';

  @override
  String get searchEnterDestinationHint => 'Voer bestemming in';

  @override
  String get whenRowLabel => 'Wanneer';

  @override
  String get accountProfileHeading => 'Profiel';

  @override
  String get accountProfileCardSubtitle =>
      'Je boekingsnaam, e-mail en hoe de app eruitziet.';

  @override
  String get accountProfilePreferencesLabel => 'Taal en thema';

  @override
  String get accountBookingNameLabel => 'Boekingsnaam';

  @override
  String get accountBookingNameHint => 'Hoe moeten chauffeurs je noemen?';

  @override
  String get accountBookingNameDescription =>
      'Deze naam wordt getoond aan chauffeurs wanneer je een rit boekt.';

  @override
  String get accountSettingsHeading => 'Instellingen';

  @override
  String get accountLocationNeededBody =>
      'Locatietoegang is nodig voor een nauwkeurig ophaalpunt, matching met chauffeurs in de buurt en betrouwbare ritupdates.';

  @override
  String get accountManageLocation => 'Beheer locatietoegang';

  @override
  String get accountNotificationsNeededBody => 'Meldingen nodig';

  @override
  String get accountManageNotifications => 'Beheer meldingen';

  @override
  String get toggleOn => 'Aan';

  @override
  String get toggleOff => 'Uit';

  @override
  String get marketplaceYourSavings => 'Jouw besparing';

  @override
  String get marketplaceStandardPrice => 'Gebruikelijke prijs';

  @override
  String get marketplaceTypicalPriceTitle => 'Gebruikelijk voor deze route';

  @override
  String marketplaceTypicalPriceBody(String amount) {
    return 'Op basis van Cabys in de buurt kost een rit als deze meestal rond $amount.';
  }

  @override
  String get marketplaceMatchChanceTitle => 'Kans op match';

  @override
  String marketplaceMatchChanceBody(String bid, String percent) {
    return 'Met $bid schatten we ongeveer $percent% kans dat een chauffeur accepteert.';
  }

  @override
  String get marketplaceMatchChanceStrong =>
      'Sterk bod — je zit op of boven de gebruikelijke prijs, chauffeurs accepteren sneller.';

  @override
  String get marketplacePricingLoading =>
      'Live tarieven van chauffeurs ophalen…';

  @override
  String get marketplaceTypicalUnavailable =>
      'We konden nog geen gebruikelijke prijs laden. Probeer het zo opnieuw.';

  @override
  String marketplaceSavingsVsTypicalPercent(String percent) {
    return '$percent% onder de gebruikelijke prijs';
  }

  @override
  String marketplaceSavingsBanner(String percent) {
    return 'Bespaar tot $percent% op deze rit';
  }

  @override
  String get marketplaceYourBid => 'Jouw bod';

  @override
  String get marketplaceQuickSelect => 'Snel selecteren';

  @override
  String get marketplaceHeroTagline =>
      'Bied je prijs — chauffeurs die al jouw kant op rijden kunnen accepteren of tegenbieden.';

  @override
  String get marketplaceYourRoute => 'Jouw route';

  @override
  String get marketplaceDragToAdjustHint => 'Schuif om aan te passen';

  @override
  String get marketplaceSetPickupDestinationHint =>
      'Voeg ophaal- en bestemmingsadres toe om te plaatsen op de marktplaats.';

  @override
  String get marketplaceLiveBadge => 'LIVE';

  @override
  String get marketplaceQuickBudget => 'Budget';

  @override
  String get marketplaceQuickPopular => 'Populair';

  @override
  String get marketplaceQuickFaster => 'Sneller';

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
      'Bewaar chauffeurs die je vertrouwt voor snel boeken';

  @override
  String get favoritesSelectAllDrivers => 'Selecteer alle chauffeurs';

  @override
  String favoritesPostRideTo(int count) {
    return 'Plaats rit naar $count favorieten';
  }

  @override
  String get searchFactIndependentDrivers =>
      'Onafhankelijke chauffeurs bepalen hun eigen prijzen';

  @override
  String get searchFactOwnPrices => 'Geen surge prijzen - ooit';

  @override
  String get searchFactOwnFuel => 'Chauffeurs betalen hun eigen brandstof';

  @override
  String get searchFactVerifiedDrivers => 'Alle chauffeurs zijn geverifieerd';

  @override
  String get searchFactFavorites =>
      'We sturen eerst naar je opgeslagen chauffeurs; geen reactie? Dan naar iedereen in de buurt.';

  @override
  String get searchEnterPickupHint => 'Voer ophaallocatie in';

  @override
  String get goWhereverWhenever => 'Ga waarheen, wanneer je wilt.';

  @override
  String get noTaxisInZone => 'Geen taxi\'s in je zone';

  @override
  String get oneTaxiInZone => '1 taxi in je zone';

  @override
  String taxisInZone(int count) {
    return '$count+ taxi\'s in je zone';
  }

  @override
  String get favouriteDriver => 'Favoriete chauffeur';

  @override
  String get email => 'E-mail';

  @override
  String get verified => 'Geverifieerd';

  @override
  String get addEmail => 'E-mail toevoegen';

  @override
  String get add => 'Toevoegen';

  @override
  String get reportARide => 'Rit melden';

  @override
  String get reportARideSubtitle => 'Meld een voltooide rit binnen 24 uur.';

  @override
  String get reportSelectRideTitle => 'Welke rit?';

  @override
  String get reportSelectRideHint =>
      'Kies een voltooide rit zodat we je melding aan de juiste boeking koppelen.';

  @override
  String get reportNoRidesToReport =>
      'Geen voltooide ritten in de afgelopen twee weken. Bij een oudere rit: neem contact op met support.';

  @override
  String get reportSelectThisRide => 'Kies';

  @override
  String get reportChangeRide => 'Wijzigen';

  @override
  String get reportSelectedRideLabel => 'Rit geselecteerd';

  @override
  String get reportSelectedRideFallback =>
      'Deze rit is gekoppeld aan je melding. Beschrijf hieronder wat er misging.';

  @override
  String get reportActiveTripBanner =>
      'Je meldt iets over je huidige rit. Leg hieronder uit wat er gebeurde.';

  @override
  String get ridesCardReportRide => 'Rit melden';

  @override
  String get supportSubtitle => 'Vraag of probleem? Chat met ondersteuning';

  @override
  String get supportHubContact => 'Contact';

  @override
  String get supportNewThread => 'Nieuw bericht';

  @override
  String get supportAllThreads => 'Alle berichten';

  @override
  String get supportChatSendFailed =>
      'Versturen mislukt. Controleer je verbinding en probeer opnieuw.';

  @override
  String get supportNoThreads => 'Nog geen gesprekken.';

  @override
  String get supportThreadsTitle => 'Berichten';

  @override
  String get supportTypeMessage => 'Typ een bericht';

  @override
  String get supportTicketOpen => 'Open';

  @override
  String get supportTicketResolved => 'Afgehandeld';

  @override
  String get supportRecentHeading => 'Recent';

  @override
  String get supportSeeAll => 'Alles bekijken';

  @override
  String get supportOtherCategory => 'Overige';

  @override
  String get supportHelpArticles => 'Helpartikelen';

  @override
  String get supportPickCategory => 'Categorie';

  @override
  String get supportStartChat => 'Start gesprek';

  @override
  String get supportSectionOngoing => 'Lopend';

  @override
  String get supportSectionClosed => 'Afgesloten';

  @override
  String get supportResolutionSummary => 'Reden';

  @override
  String get supportResolutionOutcome => 'Hoe opgelost';

  @override
  String get supportChatOfflineSaved =>
      'Je bericht is opgeslagen. De assistent is offline — support kan het nog steeds lezen.';

  @override
  String get supportAiConsentTitle =>
      'Maak kennis met Yaz, je AI-supportassistent';

  @override
  String get supportAiConsentIntro =>
      'Yaz is de AI-klantenserviceassistent van HeyCaby. Haar taak is om je klacht te begrijpen en eenvoudige supportproblemen snel op te lossen.';

  @override
  String get supportAiConsentDataSent =>
      'Om je te helpen sturen we: je bericht, je supportticket-categorie en beperkte accountcontext die nodig is om je vraag te beantwoorden.';

  @override
  String get supportAiConsentThirdParty =>
      'AI-verwerking: Yaz gebruikt OpenAI (ChatGPT)-modellen om antwoorden te genereren.';

  @override
  String get supportAiConsentPolicy =>
      'Bij serieuze of gevoelige kwesties: deel geen privégegevens in AI-chat. Mail support via hello@heycaby.nl.';

  @override
  String get supportAiConsentEmailOption =>
      'Deel geen wachtwoorden, volledige betaalkaartnummers, overheids-ID\'s of andere zeer gevoelige gegevens in AI-chat.';

  @override
  String get supportAiConsentCheckbox =>
      'Ik begrijp welke gegevens worden gedeeld, wie ze verwerkt, en ik geef HeyCaby toestemming om deze supportchat-gegevens te delen met Yaz AI-support.';

  @override
  String get supportAiConsentContinue => 'Ik ga akkoord en ga verder';

  @override
  String get supportAiConsentSendEmail => 'Stuur liever een e-mail';

  @override
  String get supportCategoryRideIssue => 'Rit probleem';

  @override
  String get supportCategoryPayment => 'Betaling';

  @override
  String get supportCategoryAccount => 'Account';

  @override
  String get supportMessageSentTitle => 'Bericht verzonden';

  @override
  String get supportMessageSentBody =>
      'Bedankt voor je bericht. Ons supportteam bekijkt het en neemt zo snel mogelijk contact met je op.\n\nIs je probleem urgent? Dan kun je chatten met Yaz (AI-supportassistent). Deel geen gevoelige persoonsgegevens in AI-chat.';

  @override
  String get supportMessageSendFailedTitle =>
      'Bericht kon niet worden verzonden';

  @override
  String get supportMessageSendFailedBody =>
      'We konden je supportbericht nu niet verzenden. Probeer het zo opnieuw, of gebruik Chat met Yaz voor urgente hulp.';

  @override
  String get supportChatWithYaz => 'Chat met Yaz';

  @override
  String get supportSendMessageButton => 'Verstuur bericht';

  @override
  String get supportYazUnavailableGuestAuthDisabled =>
      'Yaz-chat is tijdelijk niet beschikbaar omdat gastchat-auth op de server is uitgeschakeld.';

  @override
  String get supportYazUnavailableTemporary =>
      'Yaz-chat is tijdelijk niet beschikbaar. Probeer het zo opnieuw.';

  @override
  String get supportYazFallbackReply =>
      'Ik kan nu geen antwoord geven. Probeer opnieuw of stuur een e-mail naar support.';

  @override
  String get supportEmailSupport => 'E-mail support';

  @override
  String get supportYazAssistantTitle => 'Yaz AI-supportassistent';

  @override
  String get supportYazAssistantSubtitle =>
      'Stel vragen over je rit, account of betaling.';

  @override
  String get supportYazMessageHint => 'Bericht aan Yaz...';

  @override
  String get favouriteDriversAccountSubtitle =>
      'Bouw je netwerk van vertrouwde chauffeurs op.';

  @override
  String get openLocationSettings => 'Open locatie-instellingen';

  @override
  String get openNotificationSettings => 'Open meldingsinstellingen';

  @override
  String get cashSubtitle => 'Betaal contant aan de chauffeur';

  @override
  String get pinSubtitle => 'Betaal met pinpas in het voertuig';

  @override
  String get tikkieSubtitle => 'Betaal via Tikkie betaalverzoek';

  @override
  String get yourName => 'Je naam';

  @override
  String paymentMethodsSelected(int count) {
    return '$count betaalmethode(n) geselecteerd';
  }

  @override
  String get vehicleStandard => 'Standaard';

  @override
  String get vehicleStandardDesc => 'Betaalbare ritten voor dagelijks gebruik';

  @override
  String get vehicleComfort => 'Comfort';

  @override
  String get vehicleComfortDesc => 'Premium voertuigen met extra ruimte';

  @override
  String get vehicleTaxibus => 'Taxibus';

  @override
  String get vehicleTaxibusDesc => 'Tot 8 passagiers met bagage';

  @override
  String get vehicleWheelchair => 'Rolstoel';

  @override
  String get vehicleWheelchairDesc =>
      'Toegankelijke voertuigen met oprijplaten';

  @override
  String get petFriendly => 'Huisdieren welkom';

  @override
  String get petFriendlyDesc => 'Chauffeurs die huisdieren accepteren';

  @override
  String get vehicleSupplyCountCaption => 'chauffeurs beschikbaar';

  @override
  String vehicleSupplyDriversCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count chauffeurs in de buurt',
      one: '1 chauffeur in de buurt',
      zero: 'Geen chauffeurs in de buurt',
    );
    return '$_temp0';
  }

  @override
  String vehicleSupplyNearestKm(String km) {
    return 'Dichtstbij ~$km km';
  }

  @override
  String vehicleSupplyFromPrice(String price) {
    return 'Vanaf €$price';
  }

  @override
  String get vehicleSupplyShowDrivers => 'Toon chauffeurs';

  @override
  String get vehicleSupplyHideDrivers => 'Verberg chauffeurs';

  @override
  String get vehicleSupplyEstimatesNote =>
      'Prijzen en beschikbaarheid zijn schattingen en kunnen veranderen bij het boeken.';

  @override
  String get returnTripFareEstimatesTitle => 'Retourritten';

  @override
  String get returnTripFareEstimatesSubtitle =>
      'Toon chauffeursprijzen met hun actieve retourkorting. Zet uit voor prijzen op het standaardtarief.';

  @override
  String get returnTripFareEstimatesRequiresRoute =>
      'Voeg ophaal- en bestemming toe om retourprijzen te zien.';

  @override
  String get vehicleSupplyNoPickup =>
      'Stel een ophaallocatie in om chauffeurs in de buurt te zien.';

  @override
  String get vehicleSupplyLoading => 'Chauffeurs in de buurt controleren…';

  @override
  String get vehicleSupplyNoDriversInCategory =>
      'Geen chauffeurs in deze categorie op dit moment.';

  @override
  String vehicleDriverOfferRow(String distanceKm, String price) {
    return '~$distanceKm km · €$price';
  }

  @override
  String vehicleDriverNumbered(int n) {
    return 'Chauffeur $n';
  }

  @override
  String get ratingGreatDriver => 'Goede chauffeur';

  @override
  String get ratingCleanVehicle => 'Schoon voertuig';

  @override
  String get ratingSafeDriving => 'Veilig rijden';

  @override
  String get ratingFriendly => 'Vriendelijk';

  @override
  String get ratingOnTime => 'Op tijd';

  @override
  String get ratingProfessional => 'Professioneel';

  @override
  String get failedToSubmitRating => 'Beoordeling versturen mislukt';

  @override
  String get reportDriverBehavior => 'Chauffeur gedrag';

  @override
  String get reportVehicleCondition => 'Voertuig staat';

  @override
  String get reportRouteIssue => 'Route probleem';

  @override
  String get reportSafetyConcern => 'Veiligheidsprobleem';

  @override
  String get reportPricingDispute => 'Prijsgeschil';

  @override
  String get reportOther => 'Anders';

  @override
  String get driver => 'Chauffeur';

  @override
  String get errorLoadingMessages => 'Fout bij laden berichten';

  @override
  String get typeAMessage => 'Typ een bericht...';

  @override
  String get noMessagesYet => 'Nog geen berichten';

  @override
  String get startConversation => 'Start een gesprek met je chauffeur';

  @override
  String get faq => 'Veelgestelde vragen';

  @override
  String get termsOfService => 'Algemene voorwaarden';

  @override
  String get privacyPolicy => 'Privacybeleid';

  @override
  String get logoutConfirmTitle => 'Uitloggen?';

  @override
  String get logoutConfirmMessage =>
      'Je moet je gegevens opnieuw invoeren om weer te boeken.';

  @override
  String get linkCopied => 'Link gekopieerd naar klembord';

  @override
  String get cancelRide => 'Rit annuleren';

  @override
  String get cancelRideConfirm =>
      'Weet je zeker dat je deze rit wilt annuleren?';

  @override
  String get noDriverFound => 'Geen chauffeur gevonden';

  @override
  String get noDriverFoundMessage =>
      'We konden geen chauffeur vinden voor je rit.';

  @override
  String get retrySearch => 'Opnieuw proberen';

  @override
  String get youHaveArrived => 'Je bent gearriveerd!';

  @override
  String get payDriverCash => 'Betaal contant aan de chauffeur';

  @override
  String get payDriverPin => 'Betaal per pin aan de chauffeur';

  @override
  String get payDriverTikkie => 'Je ontvangt een Tikkie van de chauffeur';

  @override
  String get rateDriver => 'Beoordeel chauffeur';

  @override
  String get addToFavourites => 'Voeg toe aan favorieten';

  @override
  String get addComment => 'Voeg een opmerking toe...';

  @override
  String etaToDestination(String min) {
    return '$min min naar bestemming';
  }

  @override
  String get rideDetails => 'Ritdetails';

  @override
  String get rideDetailViewReceipt => 'Bekijk bon';

  @override
  String get rideDetailReceiptLoadFailed => 'Bon kon nu niet worden geladen.';

  @override
  String get rebookRide => 'Opnieuw boeken';

  @override
  String get scheduleYourRide => 'Plan je rit';

  @override
  String get selectDate => 'Selecteer datum';

  @override
  String get selectTime => 'Selecteer tijd';

  @override
  String get confirmSchedule => 'Schema bevestigen';

  @override
  String get postToMarketplace => 'Plaats op Marktplaats';

  @override
  String get addYourEmail => 'Voeg je e-mail toe';

  @override
  String get emailOnlyUsedFor =>
      'We gebruiken je e-mail alleen om je identiteit te verifiëren voor favoriete chauffeurs.';

  @override
  String get enterYourEmail => 'Voer je e-mailadres in';

  @override
  String get sendCode => 'Code versturen';

  @override
  String get invalidEmail => 'Voer een geldig e-mailadres in';

  @override
  String get failedToSaveEmail => 'E-mail opslaan mislukt. Probeer opnieuw.';

  @override
  String get riderEmailReviewCodeHint =>
      'Verificatiecode (alleen App Store-review — leeg laten voor een normaal account)';

  @override
  String get riderEmailReviewCodeFieldHint =>
      '6-cijferige code uit App Store-notities';

  @override
  String get riderEmailReviewCredentialsError =>
      'Deze e-mail en code komen niet overeen met de review-login. Laat de code leeg als je geen reviewaccount gebruikt.';

  @override
  String get riderEmailReviewOtpSixDigitsOrEmpty =>
      'Voer 6 cijfers in of laat het codeveld leeg.';

  @override
  String get addYourHome => 'Voeg je thuisadres toe';

  @override
  String get homeAddressDesc => 'Sla je thuisadres op voor snelle toegang.';

  @override
  String get enterHomeAddress => 'Voer je thuisadres in';

  @override
  String get saving => 'Opslaan...';

  @override
  String get failedToSaveHome => 'Thuisadres opslaan mislukt';

  @override
  String get faqBookingSection => 'Boeken';

  @override
  String get faqHowToBook => 'Hoe boek ik een rit?';

  @override
  String get faqHowToBookAnswer =>
      'Open de app, tik op \'Waar naartoe?\', voer je bestemming in, kies een boekingsmodus (Direct of Marktplaats), selecteer een betaalmethode en tik op \'Zoek mijn chauffeur\'. Een chauffeur in de buurt wordt aan je rit gekoppeld.';

  @override
  String get faqInstantVsMarketplace =>
      'Wat is het verschil tussen Direct en Marktplaats?';

  @override
  String get faqInstantVsMarketplaceAnswer =>
      'Direct stuurt je ritverzoek meteen naar chauffeurs in de buurt. Marktplaats laat je je eigen prijs bepalen en chauffeurs kunnen bieden op je rit, waardoor je mogelijk geld bespaart.';

  @override
  String get faqScheduleRide => 'Kan ik een rit plannen voor later?';

  @override
  String get faqScheduleRideAnswer =>
      'Ja! Tik op de knop \'Later\' op het startscherm om een datum en tijd te kiezen. Je verzoek wordt op het geplande tijdstip naar chauffeurs gestuurd.';

  @override
  String get faqHowMarketplace => 'Hoe werkt de Marktplaats?';

  @override
  String get faqHowMarketplaceAnswer =>
      'Je stelt je gewenste prijs voor de rit in. Chauffeurs zien je aanbod en kunnen erop bieden. Je kiest welke chauffeur je accepteert op basis van prijs, beoordeling en aankomsttijd.';

  @override
  String get faqDriversSection => 'Chauffeurs en favorieten';

  @override
  String get faqAddFavourite => 'Hoe voeg ik een chauffeur toe als favoriet?';

  @override
  String get faqAddFavouriteAnswer =>
      'Na het voltooien van een rit kun je op het hartje tikken op het beoordelingsscherm om die chauffeur aan je favorieten toe te voegen. Je hebt een geverifieerd e-mailadres nodig.';

  @override
  String get faqWhatAreFavourites => 'Wat zijn favoriete chauffeurs?';

  @override
  String get faqWhatAreFavouritesAnswer =>
      'Favoriete chauffeurs zijn chauffeurs die je hebt opgeslagen. Je kunt ritten direct naar je vertrouwde chauffeurs sturen voor een persoonlijkere ervaring.';

  @override
  String get faqBlockDriver => 'Kan ik een chauffeur blokkeren?';

  @override
  String get faqBlockDriverAnswer =>
      'Tijdens een actieve rit-chat: open het menu (⋮) en kies Chauffeur blokkeren. Je kunt een chauffeur ook na de rit melden via het beoordelingsscherm.';

  @override
  String get faqPaymentSection => 'Betalen';

  @override
  String get faqPaymentMethods => 'Welke betaalmethoden zijn beschikbaar?';

  @override
  String get faqPaymentMethodsAnswer =>
      'Contant, PIN (betaalpas in het voertuig) en Tikkie (betaalverzoek na de rit).';

  @override
  String get faqWhoPaysWho => 'Wie betaalt wie?';

  @override
  String get faqWhoPaysWhoAnswer =>
      'Je betaalt de chauffeur rechtstreeks. HeyCaby neemt nul commissie — 100% van de prijs gaat naar de chauffeur.';

  @override
  String get faqWhereSeeCosts => 'Waar zie ik mijn ritkosten?';

  @override
  String get faqWhereSeeCostsAnswer =>
      'Op het scherm na voltooiing van de rit en in je ritgeschiedenis onder het tabblad Ritten.';

  @override
  String get faqSafetySection => 'Problemen en veiligheid';

  @override
  String get faqDriverNoShow => 'Wat doe ik als mijn chauffeur niet komt?';

  @override
  String get faqDriverNoShowAnswer =>
      'Het wachtscherm heeft een annuleringsoptie. Als er binnen een paar minuten geen chauffeur is gevonden, kun je opnieuw proberen of annuleren.';

  @override
  String get faqReportIncident => 'Hoe meld ik een incident?';

  @override
  String get faqReportIncidentAnswer =>
      'Na een rit kun je het meldingsformulier op het beoordelingsscherm gebruiken om details te versturen.';

  @override
  String get faqInsurance => 'Is mijn rit verzekerd?';

  @override
  String get faqInsuranceAnswer =>
      'Alle HeyCaby-chauffeurs zijn professionele gelicentieerde taxichauffeurs met een geldige verzekering.';

  @override
  String get faqAccountSection => 'Account';

  @override
  String get faqChangeName => 'Hoe wijzig ik mijn boeknaam?';

  @override
  String get faqChangeNameAnswer =>
      'Ga naar Account en tik op het naamveld om het te bewerken. Je nieuwe naam wordt getoond aan chauffeurs bij toekomstige boekingen.';

  @override
  String get faqVerifyEmail => 'Hoe verifieer ik mijn e-mail?';

  @override
  String get faqVerifyEmailAnswer =>
      'Favorieten vereisen een opgeslagen e-mail. Open Account of Favoriete chauffeurs, tik E-mail toevoegen, voer je adres in en tik Doorgaan. Voor App Store-review: gebruik het review-e-mailadres en de 6-cijferige code uit App Review Information in het codeveld.';

  @override
  String get faqDeleteAccount => 'Hoe verwijder ik mijn account?';

  @override
  String get faqDeleteAccountAnswer =>
      'Ga naar Account, tik op Mijn account verwijderen en bevestig door DELETE te typen. Hiermee wordt je passagiersidentiteit en bijbehorende gegevens bij HeyCaby verwijderd.';

  @override
  String get termsTitle => 'Algemene voorwaarden';

  @override
  String get termsWhatIsHeyCaby => '1. Over HeyCaby';

  @override
  String get termsWhatIsHeyCabyBody =>
      'HeyCaby is een platform dat reizigers koppelt aan onafhankelijke, gelicentieerde taxichauffeurs. Wij nemen chauffeurs niet in dienst en leveren zelf geen vervoersdienst. We faciliteren alleen matching en communicatie.\n\nGebruikersrollen:\n• Reizigers: personen die vervoer aanvragen\n• Chauffeurs: zelfstandige professionals die vervoer uitvoeren\n\nIedere gebruiker is verantwoordelijk voor eigen gedrag op het platform.';

  @override
  String get termsRiderResponsibilities =>
      '2. Verantwoordelijkheden van reizigers';

  @override
  String get termsRiderResponsibilitiesBody =>
      'Als reiziger ga je akkoord met:\n• Correcte ophaal- en bestemmingsinformatie geven\n• Op tijd aanwezig zijn op de ophaallocatie\n• Respectvol en professioneel omgaan met chauffeurs\n• Voltooide ritten betalen via afgesproken methoden\n• Geen illegaal, beledigend of onveilig gedrag\n\nNiet naleven kan leiden tot accountbeperkingen of schorsing.';

  @override
  String get termsPayment =>
      '3. Verantwoordelijkheden van chauffeurs en 4. Betalingen';

  @override
  String get termsPaymentBody =>
      'Chauffeurs op HeyCaby moeten geldige vergunningen hebben, veilig en wettig vervoer leveren, duidelijk communiceren, eerlijke prijzen hanteren en betalingen direct met reizigers afhandelen.\n\nBetalingen verlopen direct tussen reiziger en chauffeur. HeyCaby verwerkt, bewaart of garandeert geen betalingen. Mogelijke methoden zijn contant, pin (kaart) of externe apps (zoals Tikkie). Betaalgeschillen worden opgelost tussen reiziger en chauffeur.';

  @override
  String get termsCancellation => '5. Annuleringen';

  @override
  String get termsCancellationBody =>
      'Reizigers kunnen kosteloos annuleren vóórdat een chauffeur accepteert. Na acceptatie kunnen annuleringskosten gelden naar inzicht van de chauffeur. Herhaalde annuleringen of no-shows kunnen tot beperkingen leiden.';

  @override
  String get termsSuspension => '6. Platformgebruik en 8. Accountschorsing';

  @override
  String get termsSuspensionBody =>
      'Je gaat ermee akkoord het platform niet te misbruiken, geen valse informatie te geven, geen fraude/betaalmisbruik te plegen en andere gebruikers niet te intimideren of te schaden.\n\nHeyCaby kan accounts schorsen of beëindigen bij fraude, misbruik, intimidatie, herhaalde no-shows/annuleringen of andere schendingen van deze voorwaarden.';

  @override
  String get termsDisputes => '9. Geschillen en 10. Aansprakelijkheid';

  @override
  String get termsDisputesBody =>
      'Gebruikers proberen geschillen eerst onderling op te lossen. Indien nodig kunnen geschillen in de app worden gemeld. HeyCaby kan ondersteunen, maar is niet aansprakelijk voor uitkomsten tussen gebruikers.\n\nHeyCaby is niet aansprakelijk voor gedrag van chauffeurs of reizigers, kwaliteit/veiligheid van ritten, of schade/verlies/geschillen die uit ritten voortkomen. HeyCaby is een facilitator, geen vervoerder.';

  @override
  String get termsGoverningLaw => '11. Wijzigingen van voorwaarden';

  @override
  String get termsGoverningLawBody =>
      'We kunnen deze voorwaarden op elk moment aanpassen. Door het platform te blijven gebruiken, accepteer je de bijgewerkte voorwaarden.';

  @override
  String get termsContact => '12. Contact';

  @override
  String get termsContactBody =>
      'Voor ondersteuning of geschillen gebruik je de supportfunctie in de app.';

  @override
  String get privacyTitle => 'Privacybeleid';

  @override
  String get privacyDataCollected => '1. Welke informatie we verzamelen';

  @override
  String get privacyDataCollectedBody =>
      'We verzamelen alleen gegevens die nodig zijn om de dienst te leveren:\n• Accountgegevens: e-mail en basisprofiel voor accountaanmaak en verificatie\n• Locatiegegevens: tijdens actieve boekingen om reizigers met chauffeurs te matchen\n• Ritgegevens: ophaal/afzetlocaties, tijdstempels en rithistorie voor bonnen en verbetering\n• Apparaatgegevens: appversie, apparaattype en push-tokens voor werking en prestaties\n• Supportgegevens: supportticket-berichten en categorie, die bij jouw toestemming in chat door onze AI-supportprovider kunnen worden verwerkt';

  @override
  String get privacyLocationData => '3. Gebruik van locatiegegevens';

  @override
  String get privacyLocationDataBody =>
      'Locatie wordt alleen gebruikt tijdens actieve ritten/boekingen. We volgen gebruikers niet op de achtergrond buiten boekingen. Locatiegegevens worden niet langer bewaard dan nodig voor het afronden van de rit.';

  @override
  String get privacyDataSharing => '4. Delen van gegevens';

  @override
  String get privacyDataSharingBody =>
      'We delen beperkte gegevens alleen wanneer dat nodig is voor de dienst.\n\nChauffeurs ontvangen: reizigersnaam (of alias) en ophaallocatie.\nReizigers ontvangen: chauffeursgegevens die nodig zijn voor de rit.\n\nSupport-AI (na jouw toestemming vóór het eerste bericht): inhoud van supportchat-berichten, ticketcategorie en minimale context die nodig is om je verzoek te beantwoorden worden verwerkt door OpenAI (ChatGPT)-modellen.\n\nWe delen geen e-mailadressen, telefoonnummers (tenzij in toekomstige functies expliciet nodig), of gevoelige persoonsgegevens voor AI-chat.';

  @override
  String get privacyRetention => '5. Bewaartermijnen';

  @override
  String get privacyRetentionBody =>
      'Ritgegevens worden bewaard voor bonnen en historie. Accountgegevens worden bewaard totdat verwijdering wordt aangevraagd. Tijdelijke gegevens (zoals recente zoekopdrachten) kunnen automatisch verlopen.';

  @override
  String get privacyGdpr => '6. Jouw rechten (AVG)';

  @override
  String get privacyGdprBody =>
      'Als EU-gebruiker heb je recht op inzage, correctie, verwijdering, beperking en bezwaar tegen verwerking.\n\nJe kunt je account direct in de app verwijderen: Account → Delete Account.';

  @override
  String get privacyNoAds =>
      '2/7/8/9/10/11/12. Gebruik, AI-support (Yaz), beveiliging, meldingen, derden, wijzigingen, contact';

  @override
  String get privacyNoAdsBody =>
      'Je gegevens worden uitsluitend gebruikt om HeyCaby te laten werken: matching, boekingen, communicatie, ritoverzichten, prestatieverbetering en belangrijke meldingen.\n\nAI-support (Yaz): wanneer je kiest voor \"Chat met Yaz\" en in de app expliciet toestemming geeft, worden je supportbericht-inhoud, ticketcategorie en beperkte accountcontext verwerkt door OpenAI (ChatGPT) om supportantwoorden te genereren. AI-chat is optioneel. Je kunt ook niet-AI support gebruiken via \"Nieuw bericht\".\n\nWe instrueren gebruikers om geen zeer gevoelige gegevens in AI-chat te delen (zoals wachtwoorden, volledige betaalkaartnummers of overheids-ID-nummers). Voor gevoelige of complexe kwesties verwijzen we gebruikers naar menselijke support.\n\nWe gebruiken je gegevens niet voor advertenties en verkopen geen gegevens aan derden.\n\nWe nemen technische en organisatorische maatregelen om gegevens te beveiligen, maar geen systeem is 100% veilig.\n\nPushmeldingen kunnen gaan over ritupdates, belangrijke servicemeldingen en incidentele productupdates. Je kunt meldingen altijd uitschakelen in je toestelinstellingen.\n\nWe gebruiken vertrouwde dienstverleners (bijv. betaalproviders, Firebase, Supabase) alleen waar nodig voor de dienst.\n\nWe kunnen dit beleid periodiek aanpassen; door de app te blijven gebruiken accepteer je updates.\n\nVoor privacyverzoeken: neem contact op via support in de app.';

  @override
  String distanceRemaining(String km) {
    return '$km km resterend';
  }

  @override
  String get shareRideLink => 'Deel ritlink';

  @override
  String get rideShareCopied => 'Rit tracking link gekopieerd naar klembord';

  @override
  String get deleteMyAccount => 'Mijn account verwijderen';

  @override
  String get deleteAccountConfirmTitle => 'Account permanent verwijderen?';

  @override
  String get deleteAccountConfirmBody =>
      'Je passagiersprofiel en gegevens van deze sessie worden bij HeyCaby verwijderd. Sommige ritgegevens kunnen bewaard blijven waar de wet dat vereist. Dit kan niet ongedaan worden gemaakt.';

  @override
  String get deleteAccountTypeDeleteHint => 'Typ DELETE om te bevestigen';

  @override
  String get deleteAccountTypeDeleteError =>
      'Typ het woord DELETE (hoofdletters maakt niet uit) en tik daarna opnieuw op Mijn account verwijderen.';

  @override
  String get deleteAccountFailed =>
      'Account verwijderen mislukt. Probeer opnieuw of neem contact op.';

  @override
  String get deleteAccountSuccess => 'Je account is verwijderd.';

  @override
  String get deleteAccountSuccessModalTitle => 'Account verwijderd';

  @override
  String get deleteAccountSuccessModalBody =>
      'Je passagiersprofiel en bijbehorende persoonsgegevens uit deze app zijn definitief verwijderd bij HeyCaby.\n\nJe kunt de app van je telefoon verwijderen wanneer je wilt—verder is er niets dat je hoeft te doen.';

  @override
  String get deleteAccountSuccessModalCta => 'Verder';

  @override
  String get deleteAccountNoSession => 'Geen actieve sessie om te verwijderen.';

  @override
  String get deleteAccountNoPersonalDataMessage =>
      'Er zijn geen persoonsgegevens opgeslagen. Geen e-mail of gegevens om te verwijderen. Je kunt de app van je telefoon verwijderen.';

  @override
  String get deleteAccountNoEmailMessage =>
      'Er is geen e-mail gekoppeld aan je account. Er zijn geen persoonsgegevens om te verwijderen. Je kunt de app van je telefoon verwijderen.';

  @override
  String get dialogOk => 'OK';

  @override
  String get blockDriver => 'Chauffeur blokkeren';

  @override
  String get blockDriverConfirm =>
      'Je ziet geen nieuwe berichten meer van deze chauffeur in deze rit-chat.';

  @override
  String get reportDriverTitle => 'Deze chauffeur melden?';

  @override
  String get reportDriverBody =>
      'HeyCaby beoordeelt deze rit-chat. Je kunt hieronder details toevoegen (optioneel).';

  @override
  String get reportReasonHint => 'Wat is er gebeurd? (optioneel)';

  @override
  String get chatReportSubmitted => 'Bedankt — we hebben je melding ontvangen.';

  @override
  String get chatMoreOptions => 'Meer';

  @override
  String get chatBlockFailed => 'Blokkeerlijst bijwerken mislukt.';

  @override
  String get chatReportFailed => 'Melding versturen mislukt. Probeer opnieuw.';

  @override
  String get saveButton => 'Opslaan';

  @override
  String get savedAddressesSubtitle => 'Jouw opgeslagen bestemmingen';

  @override
  String get savedPlacesSheetSubtitle =>
      'Tik om te boeken of sla hieronder nog een plek op.';

  @override
  String get noSavedAddressesYet => 'Jouw snelkoppelingen';

  @override
  String get noSavedAddressesEmptyBody =>
      'Sla thuis, werk of sportschool op — of meerdere thuisadressen (mama, papa, vakantie). Hetzelfde icoon, elke keer een eigen naam.';

  @override
  String get addSavedAddress => 'Plaats opslaan';

  @override
  String get addSavedAddressSheetTitle => 'Nieuwe plaats opslaan';

  @override
  String get savedAddressCategoryLabel => 'Categorie';

  @override
  String get savedAddressNameLabel => 'Geef een naam';

  @override
  String get savedAddressNameHint => 'bijv. Mama thuis, Kantoor, Sportschool';

  @override
  String get savedAddressSearchLabel => 'Adres';

  @override
  String get savedAddressSearchHint => 'Zoek een adres';

  @override
  String get savedAddressesEmailPrompt =>
      'Sla je favoriete adressen op en boek in één tik. Voer je e-mailadres in om te beginnen.';

  @override
  String get savedAddressesGetStarted => 'Beginnen';

  @override
  String get savedAddressesUnlocked => 'Geweldig! Je kunt nu adressen opslaan.';

  @override
  String get savedAddressLabelHome => 'Thuis';

  @override
  String get savedAddressLabelWork => 'Werk';

  @override
  String get savedAddressLabelGym => 'Gym';

  @override
  String get savedAddressLabelCustom => 'Aangepast';

  @override
  String get savedAddressesLimitReached =>
      'Je kunt maximaal 10 plekken opslaan. Verwijder er een om een nieuwe toe te voegen.';

  @override
  String get deleteSavedAddress => 'Verwijderen';

  @override
  String get searchFactDriversKeep100 =>
      'Alle chauffeurs houden 100% van hun verdiensten. HeyCaby neemt geen commissie per rit.';

  @override
  String get searchFactNoSurgePricing =>
      'Geen surge pricing. Ooit. De prijs die je ziet is de prijs die je betaalt.';

  @override
  String get searchFactAllVerified =>
      'Elk rijbewijs, elke verzekering, elke chauffeurspas — door ons gecheckt voordat ze online gaan.';

  @override
  String get searchFactMarketplace =>
      'Chauffeurs die teruggaan naar hun stad rijden soms voor minder. Check de marketplace voor de beste prijs.';

  @override
  String get searchFactZZP =>
      'Elke Caby-chauffeur is een zelfstandige professional. Je rijdt met iemand die trots is op zijn werk.';

  @override
  String get searchFactSaveAddresses =>
      'Woon in Rotterdam? Tik één keer op het huis-icoontje en je bestemming is ingevuld. Altijd.';

  @override
  String get searchFactPayHowYouWant =>
      'Contant, Tikkie, pin of factuur — jouw chauffeur vertelt je welke opties beschikbaar zijn.';

  @override
  String get searchingTitle => 'We zoeken de dichtstbijzijnde Caby…';

  @override
  String get matchingTitleMarketplace => 'We zoeken een marketplace-Caby…';

  @override
  String get matchingTitleScheduled =>
      'We zoeken een Caby voor je geplande rit…';

  @override
  String get homeNearTermTitleInstant => 'We zoeken je Caby';

  @override
  String get homeNearTermTitleMarketplace => 'Marketplace-aanvraag';

  @override
  String get homeNearTermTitleScheduled => 'Geplande rit';

  @override
  String get homeNearTermOpenMatching =>
      'We matchen je nog met een chauffeur. Tik om voortgang te zien.';

  @override
  String get homeNearTermOpenMatchingHint =>
      'Nog aan het matchen — tik voor ritdetails';

  @override
  String get homeNearTermTripDetails => 'Ritdetails';

  @override
  String get rideMatchingTypeLabelInstant => 'Directe rit';

  @override
  String get rideMatchingTypeLabelMarketplace => 'Marktplaats';

  @override
  String get rideMatchingTypeLabelScheduled => 'Gepland';

  @override
  String get activeSearchStopTitle => 'Zoeken stoppen?';

  @override
  String get activeSearchStopBody =>
      'We annuleren deze ritaanvraag. Chauffeurs zien hem niet meer en je krijgt geen meldingen meer. Je kunt opnieuw boeken wanneer je wilt.';

  @override
  String get activeSearchStopConfirm => 'Rit stoppen';

  @override
  String get activeSearchStopKeep => 'Doorgaan met zoeken';

  @override
  String homeNearTermUntilPickup(String remaining) {
    return 'Ophalen over $remaining';
  }

  @override
  String get ridesScheduledMatchingSection => 'Geplande aanvragen';

  @override
  String get noDriverFoundCard => 'Nog geen Caby gevonden. Wat wil je doen?';

  @override
  String get notifyMeWhenFound => 'Meld mij';

  @override
  String get scheduleRideInstead => 'Inplannen';

  @override
  String get activeSearchBannerSubtitle =>
      'We sturen je een melding zodra we er een hebben.';

  @override
  String get activeSearchCardHint =>
      'HeyCaby is nieuw en groeit. Deze achtergrondzoektocht stopt automatisch na 30 minuten — je blijft niet eindeloos wachten.';

  @override
  String activeSearchMinutesLeft(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: 'nog $minutes minuten',
      one: 'nog $minutes minuut',
    );
    return '$_temp0';
  }

  @override
  String get noCabyFoundModalTitle => 'Sorry, geen Caby gevonden 😔';

  @override
  String get noCabyFoundModalBody =>
      'We zijn nog een groeiend platform met een beperkt aantal chauffeurs. Jij kunt ons helpen! Ken jij een gecertificeerde taxichauffeur? Deel HeyCaby met hen — samen maken we dit platform groter.';

  @override
  String get shareHeyCabyInvite => 'Deel HeyCaby →';

  @override
  String shareHeyCabyMessage(String url) {
    return 'Probeer HeyCaby — eerlijke ritten, geen commissie voor chauffeurs. $url';
  }

  @override
  String get growthModalClose => 'Sluiten';

  @override
  String get riderEmailVerificationSent =>
      'We hebben een 6-cijferige code naar je e-mail gestuurd. Vul die hieronder in.';

  @override
  String get riderSplashTagline => 'Jouw caby, in minuten.';

  @override
  String get activeSearchWidget => 'Zoeken naar jouw Caby…';

  @override
  String get driverFoundWidget => 'Caby gevonden! Bevestig je rit →';

  @override
  String get riderNameLabel => 'Je naam';

  @override
  String get scheduledRideLabel => 'Gepland voor';

  @override
  String get activeRideShareError => 'Rit delen lukt nu niet';

  @override
  String get activeRideCancelConfirmBody =>
      'Weet je zeker dat je deze rit wilt annuleren? Opnieuw boeken brengt je mogelijk niet sneller op je bestemming.';

  @override
  String get activeRideWaitForDriver => 'Wacht op chauffeur';

  @override
  String get activeRidePickupNotes => 'Nog ophaalnotities?';

  @override
  String get activeRideChatSubtitle =>
      'Stuur snel een bericht naar je chauffeur';

  @override
  String get activeRideFoundingShort => 'Founding';

  @override
  String get activeRideShareSubtitle => 'Deel je live ritlink';

  @override
  String get activeRideReportSubtitle => 'Dien een ritmelding in';

  @override
  String get activeRideSupportSubtitle => 'Veiligheid en hulp';

  @override
  String get activeRidePickupNotSet => 'Ophaallocatie niet ingesteld';

  @override
  String get activeRideDestinationNotSet => 'Bestemming niet ingesteld';

  @override
  String get activeRideShareDetails => 'Deel ritdetails';

  @override
  String get activeRideContactDriver => 'Contacteer chauffeur';

  @override
  String activeRideCategoryLabel(String category) {
    return 'Categorie: $category';
  }

  @override
  String get activeRideCancelReasonLongPickup => 'Lange ophaaltijd';

  @override
  String get activeRideCancelReasonBetterAlternative => 'Betere optie gevonden';

  @override
  String get activeRideCancelReasonDriverNotCloser =>
      'Chauffeur komt niet dichterbij';

  @override
  String get activeRideCancelReasonDriverAskedCancel =>
      'Chauffeur vroeg om te annuleren';

  @override
  String get activeRideCancelReasonPriceDispute =>
      'Prijsdiscussie met chauffeur';

  @override
  String get activeRideCancelReasonOutsideAppPayment =>
      'Chauffeur vroeg betaling buiten de app';

  @override
  String get activeRidePlateNumber => 'Kenteken';

  @override
  String get activeRideUnknownPlate => 'ONBEKEND';

  @override
  String get activeRideFoundingMember => 'Founding Member';

  @override
  String get activeRideVerifyPlate =>
      'Controleer dit kenteken voordat je instapt.';

  @override
  String get openAction => 'Openen';

  @override
  String get openLinkAction => 'Link openen';

  @override
  String get rideReceiptTitle => 'Ritbon';

  @override
  String get rideReceiptUnavailable => 'Bon is nog niet beschikbaar.';

  @override
  String get rideReceiptSettlement => 'Afrekening';

  @override
  String get rideReceiptRideId => 'Rit-ID';

  @override
  String get rideReceiptExpected => 'Verwacht';

  @override
  String get rideReceiptPaid => 'Betaald';

  @override
  String get rideReceiptMethod => 'Methode';

  @override
  String get rideReceiptNote => 'Notitie';

  @override
  String get rideReceiptOutstanding => 'Openstaand';

  @override
  String get rideReceiptOverpaid => 'Te veel betaald';

  @override
  String get rideReceiptStatus => 'Status';

  @override
  String get rideReceiptSettlementComplete => 'Afrekening voltooid';

  @override
  String get smartBundleRideTypeOptions => 'Ritopties';

  @override
  String smartBundleEstimatedPrice(String min, String max) {
    return 'Geschatte prijs: $min - $max';
  }

  @override
  String get smartBundleDriverPricingNote =>
      'Chauffeurs bepalen hun eigen prijzen. Wij matchen je met de beste opties in de buurt.';

  @override
  String get smartBundleTapToHide => 'Tik om ritklassen te verbergen';
}
