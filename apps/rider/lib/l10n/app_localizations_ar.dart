// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appName => 'HeyCaby';

  @override
  String get hello => 'مرحبا';

  @override
  String get rider => 'الراكب';

  @override
  String get tagline => 'تواصل مع سائقي التاكسي في حيك.';

  @override
  String get continueButton => 'متابعة';

  @override
  String get bookRide => 'احجز رحلة';

  @override
  String get whereAreYouGoing => 'إلى أين تريد الذهاب؟';

  @override
  String get searchScheduleHint => 'الآن، أو اختر التاريخ والوقت';

  @override
  String get searchStartTypingHint =>
      'اكتب 3 أحرف على الأقل للبحث على الخريطة.';

  @override
  String get searchBrowseSavedPlaces => 'تصفح كل الأماكن المحفوظة';

  @override
  String get searchBrowseRecentPlaces => 'تصفح الأخيرة';

  @override
  String get searchRecentOnDeviceSection => 'الأخيرة على هذا الجهاز';

  @override
  String get searchRecentOnDeviceSubtitle =>
      'آخر 10 أماكن استخدمتها على هذا الهاتف — منفصلة عن الأماكن المحفوظة.';

  @override
  String get searchNoLocalRecentsYet =>
      'لا توجد عناوين أخيرة بعد. ابحث عن مكان واختره — نحتفظ بآخر 10 هنا لتسريع البحث لاحقًا.';

  @override
  String get searchLocalMatchesHeader => 'تطابقات على هذا الجهاز';

  @override
  String get whereTo => 'إلى أين؟';

  @override
  String get homeDestinationPrompt => 'إلى أين تريد الذهاب؟';

  @override
  String get homeContinue => 'متابعة';

  @override
  String get homeSmartOptionsTitle => 'كيف تريد أن تركب؟';

  @override
  String get homeBestPriceTitle => 'السوق';

  @override
  String get homeBestPriceSubtitle => 'السائقون يتنافسون على رحلتك.';

  @override
  String get homeScheduleLaterTitle => 'جدولة لاحقاً';

  @override
  String get homeScheduleLaterSubtitle => 'اختر وقت الالتقاط المناسب لك.';

  @override
  String get homePopularAirportsTitle => 'شائع';

  @override
  String get homeRecentTrips => 'رحلات حديثة';

  @override
  String get homeAirportChipSchiphol => 'Schiphol';

  @override
  String get homeAirportChipRotterdam => 'مطار روتردام';

  @override
  String get homeAirportChipEindhoven => 'آيندهوفن';

  @override
  String get homeAirportChipBrussels => 'مطار بروكسل';

  @override
  String get pickup => 'نقطة الانطلاق';

  @override
  String get destination => 'الوجهة';

  @override
  String get findMyDriver => 'ابحث عن سائقي';

  @override
  String get searching => 'جارٍ البحث عن سائق...';

  @override
  String get driverAssigned => 'السائق في الطريق';

  @override
  String driverReturnTripDiscount(int pct) {
    return 'خصم $pct% على رحلة العودة';
  }

  @override
  String get driverArrived => 'وصل سائقك';

  @override
  String get tripInProgress => 'الرحلة جارية';

  @override
  String get tripComplete => 'اكتملت الرحلة';

  @override
  String get cancel => 'إلغاء';

  @override
  String get confirm => 'تأكيد';

  @override
  String get confirmDestination => 'تأكيد الوجهة';

  @override
  String get rateYourDriver => 'قيّم سائقك';

  @override
  String get howWasYourRide => 'كيف كانت رحلتك؟';

  @override
  String get whatDidYouLike => 'ما الذي أعجبك؟';

  @override
  String get additionalFeedback => 'ملاحظات إضافية (اختياري)';

  @override
  String get tellUsMore => 'أخبرنا المزيد عن تجربتك...';

  @override
  String get submitRating => 'إرسال التقييم';

  @override
  String get ratingCategorySectionTitle => 'قيّم جوانب محددة';

  @override
  String get ratingCategorySubtitle =>
      'كل جانب من 1 إلى 5 نجوم. تبدأ بنفس تقييمك العام — عدّل ما اختلف.';

  @override
  String get ratingDimensionPunctuality => 'الالتزام بالوقت';

  @override
  String get ratingDimensionCleanliness => 'النظافة';

  @override
  String get ratingDimensionAttitude => 'السلوك';

  @override
  String get ratingDimensionDrivingSafety => 'أمان القيادة';

  @override
  String get ratingDimensionCommunication => 'التواصل';

  @override
  String get recentDestinations => 'الوجهات الأخيرة';

  @override
  String recentDestinationsShowMore(int count) {
    return 'عرض $count إضافية';
  }

  @override
  String get recentDestinationsShowLess => 'عرض أقل';

  @override
  String get recentDestinationRemoveHint => 'إزالة من الأخيرة';

  @override
  String get recentDestinationRemoveFailed =>
      'تعذّر إزالة هذا المكان. حاول مرة أخرى.';

  @override
  String get whatWentWrong => 'ما الذي حدث؟';

  @override
  String get helpUsUnderstand => 'ساعدنا في فهم المشكلة حتى نتمكن من التحسن';

  @override
  String get additionalDetails => 'تفاصيل إضافية';

  @override
  String get pleaseProvideMoreDetails =>
      'يرجى تقديم المزيد من التفاصيل حول المشكلة...';

  @override
  String get submitReport => 'إرسال التقرير';

  @override
  String get reportSubmitted => 'تم إرسال التقرير بنجاح';

  @override
  String get reportSubmitFailed => 'فشل إرسال التقرير';

  @override
  String get fareEstimate => 'الأجرة التقديرية';

  @override
  String scheduledFor(String date) {
    return 'مجدول في $date';
  }

  @override
  String get noDriversNearby => 'لا يوجد سائقون قريبون';

  @override
  String get connectionProblem => 'مشكلة في الاتصال. حاول مجدداً.';

  @override
  String get rideBookingFailed =>
      'تعذّر بدء الرحلة — تم رفض التفويض من الخادم. يُرجى تحديث الجلسة (تسجيل الخروج ثم تسجيل الدخول) ثم المحاولة مرة أخرى.';

  @override
  String get locationPermissionRequired =>
      'مطلوب الوصول إلى الموقع لتحديد نقطة الانطلاق وإيجاد السائقين القريبين.';

  @override
  String get locationRequired => 'الموقع مطلوب';

  @override
  String get locationRequiredMessage =>
      'تحتاج HeyCaby إلى موقعك لتحديد نقطة انطلاق دقيقة، والعثور على السائقين القريبين، وتقديم أوقات وصول موثوقة. بدون الوصول إلى الموقع لا يمكننا خدمتك بشكل جيد ولا يمكنك حجز رحلة.';

  @override
  String get enableLocation => 'تفعيل الموقع';

  @override
  String get tryAgain => 'حاول مرة أخرى';

  @override
  String get enterAddressManually => 'إدخال العنوان يدوياً';

  @override
  String get home => 'الرئيسية';

  @override
  String get rides => 'الرحلات';

  @override
  String get account => 'الحساب';

  @override
  String get tellAFriendNavLabel => 'Community';

  @override
  String get tellAFriendNavSemanticLabel => 'نمِّ مدينتك — ابنِ مجتمع HeyCaby';

  @override
  String get tellAFriendScreenTitle => 'Grow Your City';

  @override
  String get tellAFriendSharePrompt =>
      'شارك HeyCaby مع من يحتاجون رحلات موثوقة في مدينتك. كل راكب جديد يساعد سائقي التaxi المحليين.';

  @override
  String get tellAFriendHeroTitle => 'ادعُ الأصدقاء';

  @override
  String get tellAFriendHeroSubtitle => 'شارك الرابط بلمسة واحدة.';

  @override
  String get tellAFriendBodyLine1 => 'وسّع دائرة الرحلات قربك.';

  @override
  String get tellAFriendBodyLine2 =>
      'المزيد من الركاب الموثوقين قد يعني مطابقة أسرع للجميع.';

  @override
  String get tellAFriendFriendsInvitedLabel => 'الأصدقاء المدعوون';

  @override
  String get tellAFriendFriendsInvitedZeroHint => 'لا انضمام بعد — شارك أدناه.';

  @override
  String get tellAFriendRewardTitle => 'لماذا المساعدة؟';

  @override
  String get tellAFriendRewardBullet1 => 'المزيد من الركاب قربك';

  @override
  String get tellAFriendRewardBullet2 => 'المزيد من طلبات الرحلات للسائقين';

  @override
  String get tellAFriendRewardBullet3 => 'أوقات انتظار أقصر';

  @override
  String get tellAFriendRewardBullet4 => 'مجتمع تaxi أقوى';

  @override
  String get tellAFriendInviteLinkLabel => 'رابط App Store';

  @override
  String get tellAFriendWebsiteLinkLabel => 'رابط المشاركة';

  @override
  String get tellAFriendLinkResolving => 'جاري إعداد رابط الدعوة القصير…';

  @override
  String get tellAFriendCopyLink => 'نسخ الرابط';

  @override
  String get tellAFriendShareLink => 'Share HeyCaby';

  @override
  String get tellAFriendShowQr => 'QR code';

  @override
  String get tellAFriendQrTitle => 'امسح لتحميل HeyCaby';

  @override
  String get tellAFriendQrHint =>
      'يفتح المسح تطبيق HeyCaby Rider في App Store. استخدم مشاركة أو نسخ لإرسال رابط التحميل.';

  @override
  String get tellAFriendSocialProof =>
      'شكرًا لمساعدتك في بناء أكبر شبكة تaxi مستقلة في هولندا.';

  @override
  String get tellAFriendShareDoneSnackbar => 'شكرًا لمشاركة HeyCaby!';

  @override
  String get tellAFriendLinkCopied => 'تم النسخ — جاهز للصق في أي مكان';

  @override
  String get tellAFriendShareSubject => 'انضم إلى HeyCaby — نمِّ مدينتك';

  @override
  String get tellAFriendShareMessage =>
      'حمّل HeyCaby Rider — تطبيق التaxi المستقل في هولندا:';

  @override
  String get tellAFriendLinkUnavailable => 'رابط App Store غير مُعدّ';

  @override
  String get tellAFriendLinkUnavailableHint =>
      'أضف RIDER_IOS_APP_STORE_URL إلى بيئة البناء ثم أعد بناء التطبيق.';

  @override
  String growCityHeroTitle(String cityName) {
    return 'Grow HeyCaby in $cityName';
  }

  @override
  String get growCityHeroBody1 =>
      'ادعُ الأصدقاء والعائلة ممن يحتاجون تaxi موثوقًا في مدينتك.';

  @override
  String get growCityHeroBody2 =>
      'المزيد من الركاب قربك يعني المزيد من طلبات الرحلات للسائقين المحليين وأوقات انتظار أقصر للجميع.';

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
  String get growCityPeopleInvited => 'الركاب المدعوون';

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
  String get growCityWhyHelpTitle => 'Why help?';

  @override
  String get growCityWhyHelpBullet1 => 'More riders nearby';

  @override
  String get growCityWhyHelpBullet2 => 'المزيد من العمل لسائقي التaxi المحليين';

  @override
  String get growCityWhyHelpBullet3 => 'Shorter waiting times';

  @override
  String get growCityWhyHelpBullet4 => 'Stronger taxi community';

  @override
  String get iosUpdateRequiredTitle => 'يُرجى تحديث iOS';

  @override
  String iosUpdateRequiredBody(String minimumVersion, String currentVersion) {
    return 'يتطلب HeyCaby iOS $minimumVersion أو أحدث. هذا الـ iPhone يعمل بـ iOS $currentVersion. افتح الإعدادات → عام → تحديث البرنامج لتثبيت أحدث إصدار يدعمه جهازك.';
  }

  @override
  String iosUpdateRequiredFooter(String minimumVersion) {
    return 'إذا لم يستطع جهازك الترقية إلى iOS $minimumVersion، ستحتاج إلى iPhone أحدث لاستخدام HeyCaby.';
  }

  @override
  String get scheduledCommitmentDisclosure =>
      'قد يطلب منك السائق مساهمة تأكيد صغيرة تصل إلى ٥ يورو قبل موعد الرحلة بحد أقصى ٤٠ دقيقة. تُخصم من إجمالي الرحلة. إذا ألغيت أنت أو السائق لاحقًا، تسري قواعد الإلغاء المعتادة.';

  @override
  String get prerideBannerTitle => 'يُرجى تأكيد رحلتك';

  @override
  String get prerideBannerSubtitle => 'السائق في انتظار تأكيدك قبل الاستلام.';

  @override
  String get prerideOpenTikkie => 'فتح Tikkie';

  @override
  String get prerideConfirmAttending => 'أنا قادم';

  @override
  String get prerideConfirmedThanks => 'شكرًا — تم التأكيد.';

  @override
  String get myRides => 'رحلاتي';

  @override
  String get myDrivers => 'سائقوني';

  @override
  String get myDriversHomeSubtitle => 'اركب مع شخص تثق به';

  @override
  String get favouriteDrivers => 'سائقوني';

  @override
  String get favouriteDriversSubtitle => 'شبكتك من السائقين الموثوقين';

  @override
  String favouriteDriversSubtitleWithCount(int count) {
    return '$count سائق في شبكتك';
  }

  @override
  String get noFavouritesYet => 'لا يوجد مفضلون بعد';

  @override
  String get paymentMethod => 'طريقة الدفع';

  @override
  String get cash => 'نقداً';

  @override
  String get pin => 'بطاقة';

  @override
  String get tikkie => 'تيكي';

  @override
  String get instantRide => 'فوري';

  @override
  String get scheduledRide => 'مجدول';

  @override
  String get marketplace => 'السوق';

  @override
  String get marketplaceTagline => 'السائقون يتنافسون على رحلتك.';

  @override
  String get makeAnOffer => 'السوق';

  @override
  String get marketplacePostRequest => 'نشر الطلب';

  @override
  String get marketplaceOfferHeadline => 'اختر ما تريد دفعه.';

  @override
  String get marketplaceOfferExplanation =>
      'السائقون المتجهون في اتجاهك يمكنهم قبول عرضك أو اقتراح سعر آخر.';

  @override
  String get marketplaceDriversAcceptHint =>
      'يمكن للسائقين القبول أو المقابلة أو التجاهل — HeyCaby لا تحدد الأجرة.';

  @override
  String marketplaceDriversOnline(int count) {
    return '$count سائق متصل';
  }

  @override
  String get marketplaceWhereAreYouGoing => 'إلى أين تذهب؟';

  @override
  String get marketplaceYouAreHere => 'أنت هنا';

  @override
  String marketplaceYouAreHereIn(String area) {
    return 'أنت هنا في $area';
  }

  @override
  String marketplaceYouAreHereOn(String street) {
    return 'أنت في $street';
  }

  @override
  String get marketplaceLocatingYou => 'جاري تحديد موقعك…';

  @override
  String get marketplaceLocationNeeded => 'فعّل الموقع لمعرفة مكانك';

  @override
  String get marketplaceNameYourPrice => 'حدد سعرك';

  @override
  String get marketplaceNameYourPriceSubtitle => 'سيرى السائقون عرضك ويردون.';

  @override
  String marketplaceTypicalRangeLabel(String range) {
    return 'النطاق المعتاد: $range';
  }

  @override
  String get marketplaceControlBanner =>
      'أنت المتحكم. يمكن للسائقين القبول أو المقابلة أو التجاهل.';

  @override
  String get marketplaceFasterOffersTip =>
      'تريد عروضاً أسرع؟ ارفع سعرك للحصول على المزيد من الردود.';

  @override
  String get marketplaceEnterCustomPrice => 'اضغط لكتابة أي مبلغ';

  @override
  String get marketplacePriceHint => '50';

  @override
  String marketplaceBidRangeHint(int min, int max) {
    return 'يمكنك العرض بين €$min و €$max';
  }

  @override
  String get marketplaceTypicalFareTitle => 'الأجرة المعتادة';

  @override
  String get marketplaceYourOfferTitle => 'عرضك';

  @override
  String get marketplaceRequestOffers => 'اطلب عروضاً';

  @override
  String get marketplaceMatchingTitle => 'السوق';

  @override
  String get marketplaceMatchingHeadline => 'البحث عن سائقين…';

  @override
  String get marketplaceMatchingNotifySubtitle => 'سنُعلمك عند وصول العروض.';

  @override
  String marketplaceDriversReceivedRequest(int count) {
    return 'استلم $count سائقاً طلبك';
  }

  @override
  String get marketplaceExpectedWait => 'الانتظار المتوقع: 1 – 2 دقيقة';

  @override
  String get marketplaceOffersFromDrivers => 'عروض من السائقين';

  @override
  String get marketplaceRecommended => 'موصى به';

  @override
  String get marketplaceViewProfile => 'عرض الملف';

  @override
  String get marketplaceOfferAcceptsYourPrice => 'يقبل عرضك';

  @override
  String get marketplaceOfferCounterLabel => 'عرض مضاد';

  @override
  String get marketplaceOffersExpireIn => 'تنتهي العروض خلال';

  @override
  String get marketplaceBoostOffer => 'عزّز عرضك';

  @override
  String get marketplaceBoostOfferSubtitle =>
      'ارفع السعر للحصول على المزيد من العروض';

  @override
  String get marketplaceCancelRequest => 'إلغاء الطلب';

  @override
  String get marketplaceCancelRequestConfirm =>
      'لن يرى السائقون عرضك بعد الآن. إلغاء هذا الطلب؟';

  @override
  String get marketplaceReceiveChooseTitle => 'استلم واختر العروض';

  @override
  String get marketplaceReceiveChooseBullet1 => 'السائقون يقبلون أو يقابلون';

  @override
  String get marketplaceReceiveChooseBullet2 =>
      'قارن السعر والتقييم ووقت الوصول';

  @override
  String get marketplaceReceiveChooseBullet3 => 'اختر الأنسب لك';

  @override
  String marketplaceMatchingSubhead(int nearby, int received) {
    return '$nearby قريب · $received عروض';
  }

  @override
  String get marketplaceMatchingWaiting => 'في انتظار ردود السائقين';

  @override
  String get marketplaceMatchingWaitingBody =>
      'السائقون المستقلون يمكنهم القبول أو المقابلة أو التجاهل. أنت تختار من تركب معه.';

  @override
  String marketplaceOfferAccepts(String price) {
    return 'يقبل $price';
  }

  @override
  String marketplaceOfferCounter(String price) {
    return 'عرض مضاد $price';
  }

  @override
  String marketplaceOfferMinutesAway(int minutes) {
    return 'على بعد $minutes د';
  }

  @override
  String marketplaceOfferExpiresIn(String time) {
    return 'ينتهي العرض $time';
  }

  @override
  String get marketplaceDriverUsuallyAccepts => 'يقبل عادة أسعار الراكب';

  @override
  String get marketplaceDriverOftenCounters => 'يرسل غالباً عروضاً مضادة';

  @override
  String get marketplaceDriverMayCounter => 'قد يقبل أو يقترح سعراً آخر';

  @override
  String get declineBid => 'رفض';

  @override
  String get marketplaceDriverScopeTitle => 'من يرى طلبك؟';

  @override
  String get marketplaceDriverScopeEveryone => 'الجميع';

  @override
  String get marketplaceDriverScopeMyDriversFirst => 'سائقوني أولاً';

  @override
  String get marketplaceDriverScopeMyDriversOnly => 'سائقوني فقط';

  @override
  String get marketplaceAcceptanceGood => 'فرصة جيدة للقبول';

  @override
  String get marketplaceAcceptanceFair =>
      'عرض معقول — قد يقبل السائق أو يقترح سعراً آخر';

  @override
  String get marketplaceAcceptanceLow => 'العرض منخفض — توقّع عروضاً مضادة';

  @override
  String get marketplaceDemandLowTitle => 'طلب منخفض';

  @override
  String get marketplaceDemandHighTitle => 'طلب مرتفع';

  @override
  String get marketplaceDemandLowHint =>
      'من المرجح أن يقبل السائقون عروضاً أقل.';

  @override
  String get marketplaceDemandHighHint =>
      'تقديم مبلغ أعلى قليلاً قد يسرّع الرد.';

  @override
  String get marketplaceSubtitle => 'اختر سعرك — السائقون المستقلون يقررون.';

  @override
  String get homeAirportBookingTitle => 'توصيل للمطار';

  @override
  String get homeAirportBookingSubtitle =>
      'سخيبول، بروكسل، لوكسمبورغ وغيرها — بنقرة واحدة';

  @override
  String get homeAirportBookingBadge => 'سريع';

  @override
  String get airportBookingScreenTitle => 'حجز إلى المطار';

  @override
  String get airportBookingScreenSubtitle =>
      'اختر المطار. يبقى موقع الاستلام كموقعك الحالي ما لم تغيّره في الخطوة التالية.';

  @override
  String get airportBookingSearchHint => 'ابحث بالمطار أو المدينة أو الرمز';

  @override
  String get airportBookingNoResults => 'لا يوجد مطار يطابق البحث.';

  @override
  String get airportSectionNetherlands => 'هولندا';

  @override
  String get airportSectionBelgium => 'بلجيكا';

  @override
  String get airportSectionLuxembourg => 'لوكسمبورغ';

  @override
  String get favouritesOnly => 'السائقون المفضّلون أولاً';

  @override
  String get offerFare => 'اعرض سعرك';

  @override
  String get bids => 'العروض';

  @override
  String get acceptBid => 'قبول';

  @override
  String get notifyMe => 'أخبرني عند التوفر';

  @override
  String get rideHistory => 'سجل الرحلات';

  @override
  String get reportDriver => 'الإبلاغ عن السائق';

  @override
  String get support => 'الدعم';

  @override
  String get settings => 'الإعدادات';

  @override
  String get language => 'اللغة';

  @override
  String get theme => 'المظهر';

  @override
  String get homeAddress => 'عنوان المنزل';

  @override
  String get savedAddresses => 'الأماكن المحفوظة';

  @override
  String get logout => 'تسجيل الخروج';

  @override
  String distance(String km) {
    return '$km كم';
  }

  @override
  String duration(String min) {
    return '$min دقيقة';
  }

  @override
  String get bestPrice => 'أفضل سعر';

  @override
  String get howHeyCabyWorks => 'كيف يعمل HeyCaby';

  @override
  String get zeroCommission => 'بدون عمولة — عادل للجميع';

  @override
  String get driverEarns100 => 'سائقك يكسب 100% من الأجرة';

  @override
  String get noShowWarning => 'احجز فقط عندما تكون مستعداً في موقعك';

  @override
  String get communityPledge =>
      'احجز فقط عندما تكون مستعداً في موقعك. سائقونا يدفعون الوقود في كل نداء.';

  @override
  String get namePlaceholder => 'ماذا يجب أن يناديك السائق؟';

  @override
  String get welcomeProfileModalTitle => 'مرحبًا بك في HeyCaby!';

  @override
  String get welcomeProfileModalBody =>
      'لنجعل رحلتك أسهل وأسرع، ننصحك بإعداد ملفك الشخصي. سيجعل الحجز أسرع بكثير.';

  @override
  String get setUpProfileNow => 'إعداد الآن';

  @override
  String get welcomeDriverCallYouModalTitle => 'ماذا يجب أن يناديك السائق؟';

  @override
  String get welcomeSkipDriverName => 'ليس الآن';

  @override
  String get onboardingProfileBannerMessage => 'أكمل ملفك لجعل الحجز أسرع.';

  @override
  String get saveAndContinue => 'حفظ ومتابعة';

  @override
  String get onboardingNextAddEmail =>
      'التالي: أضف بريدك الإلكتروني لحفظ العناوين والمفضّلين.';

  @override
  String get onboardingNameRequired => 'أدخل اسمك للمتابعة.';

  @override
  String riderProfileCompletionPercent(String percent) {
    return 'اكتمال الملف $percent٪';
  }

  @override
  String get riderProfileCompleteTitle => 'الملف مكتمل';

  @override
  String get riderProfileMeterName => 'اسم الحجز';

  @override
  String get riderProfileMeterEmail => 'البريد الإلكتروني';

  @override
  String get riderProfileHomeNudgeTitle => 'أكمل ملفك';

  @override
  String get riderProfileHomeNudgeBoth =>
      'أضف اسمك وبريدك من الحساب — كل منهما 50٪.';

  @override
  String get riderProfileHomeNudgeNameOnly =>
      'أضف اسم الحجز من الحساب للوصول إلى 100٪.';

  @override
  String get riderProfileHomeNudgeEmailOnly =>
      'أضف بريدك من الحساب للوصول إلى 100٪.';

  @override
  String get yourRoute => 'مسارك';

  @override
  String get howDoYouWantToBook => 'كيف تريد الحجز؟';

  @override
  String get howWillYouPay => 'كيف ستدفع؟';

  @override
  String get laterButton => 'لاحقاً';

  @override
  String get tripSummary => 'ملخص الرحلة';

  @override
  String get loading => 'جارٍ التحميل...';

  @override
  String get retry => 'إعادة المحاولة';

  @override
  String get error => 'حدث خطأ ما';

  @override
  String get driverOnTheWay => 'السائق في الطريق';

  @override
  String eta(String min) {
    return 'وقت الوصول $min دقيقة';
  }

  @override
  String get shareRide => 'مشاركة الرحلة';

  @override
  String get chat => 'محادثة';

  @override
  String get reportIssue => 'الإبلاغ عن مشكلة';

  @override
  String get rideComplete => 'اكتملت الرحلة';

  @override
  String get leaveAComment => 'اترك تعليقاً (اختياري)';

  @override
  String get submit => 'إرسال';

  @override
  String get skip => 'تخطي';

  @override
  String get back => 'رجوع';

  @override
  String get next => 'التالي';

  @override
  String get notifyMeWhenDriverFound => 'سيتم إعلامك عند العثور على سائق';

  @override
  String get cancelBookingTitle => 'إلغاء الحجز؟';

  @override
  String get cancelBookingMessage =>
      'هل أنت متأكد من الإلغاء؟ ستفقد تفاصيل رحلتك.';

  @override
  String get keepGoing => 'متابعة';

  @override
  String get nameSavedSuccess => 'تم حفظ الاسم بنجاح';

  @override
  String get ridesFilterActive => 'نشطة';

  @override
  String get ridesFilterBidding => 'مزايدة';

  @override
  String get ridesFilterCompleted => 'مكتملة';

  @override
  String get ridesFilterCancelled => 'ملغاة';

  @override
  String get ridesScreenSubtitle => 'الرحلات المجدولة والبحث الجاري وسجلّك';

  @override
  String get ridesTabUpcoming => 'القادمة';

  @override
  String get ridesTabHistory => 'السجل';

  @override
  String get upcomingRideDetailTitle => 'تفاصيل الرحلة';

  @override
  String get upcomingRideMatchingProgressTitle => 'جارٍ البحث عن سائق';

  @override
  String get upcomingRideMatchingProgressBody =>
      'نطابقك مع السائقين القريبين. افتح شاشة البحث المباشر لعرض الرادار والتحديثات.';

  @override
  String get upcomingRideOpenLiveSearch => 'فتح البحث المباشر';

  @override
  String get upcomingRideEditBookAgain => 'تغيير العناوين';

  @override
  String get upcomingRideEditBookAgainSubtitle =>
      'يلغي هذا طلبك الحالي حتى تحجز من جديد بنقطة استلام أو وجهة جديدة.';

  @override
  String get upcomingRideGoToActive => 'الانتقال إلى الرحلة المباشرة';

  @override
  String get upcomingRideDriverSection => 'السائق';

  @override
  String get ridesUpcomingScheduledBadge => 'مجدولة';

  @override
  String get ridesUpcomingMatchingBadge => 'جارٍ البحث';

  @override
  String get ridesUpcomingEmptyTitle => 'لا شيء قادم';

  @override
  String get ridesUpcomingEmptyBody =>
      'احجز رحلة أو جدولها لاحقًا — ستظهر هنا أثناء البحث عن Caby.';

  @override
  String get ridesHistorySectionTitle => 'النشاط السابق';

  @override
  String get searchAddressCouldNotResolve =>
      'تعذّر استخدام هذا العنوان. جرّب نتيجة أخرى أو أعد البحث.';

  @override
  String get saveBookingForLater => 'احفظ لاحقًا';

  @override
  String get searchAddressesContinue => 'متابعة';

  @override
  String get saveTripForNextTimeLabel => 'احفظ هذه الرحلة للمرة القادمة';

  @override
  String get saveTripForNextTimeSubtitle =>
      'يحفظ نقطة الاستلام والوجهة في أماكنك الأخيرة عند تسجيل الدخول.';

  @override
  String get scheduledMatchingHeadline => 'سنبحث لك عن سائق.';

  @override
  String get scheduledMatchingSubhead =>
      'السائقون يرون رحلتك المجدولة ويمكنهم قبولها عند توفرهم.';

  @override
  String get matchingAlternativesTitleScheduled =>
      'ما زلنا ننتظر سائقًا. جرّب خيارًا آخر.';

  @override
  String get matchingTryMarketplace => 'السوق';

  @override
  String get matchingAlternativesFabTooltip => 'خيارات أخرى للعثور على سائق';

  @override
  String get scheduledMatchingBackToHome => 'الرئيسية';

  @override
  String get scheduledMatchingCancelRide => 'إلغاء الرحلة';

  @override
  String get scheduledMatchingMoreMenuTooltip => 'المزيد';

  @override
  String get scheduledRideDetailsSheetTitle => 'تفاصيل الرحلة المجدولة';

  @override
  String get marketplaceMatchingBannerTitle => 'رحلة السوق';

  @override
  String get marketplaceMatchingBannerBody =>
      'يمكن للسائقين تقديم عروض على مسارك. سنربطك بأقرب قبول.';

  @override
  String get continueSavedBooking => 'متابعة الحجز المحفوظ';

  @override
  String get continueSavedBookingHint => 'أكمل من حيث توقّفت.';

  @override
  String get scheduledRideQueuedTitle => 'الرحلة في قائمة الانتظار';

  @override
  String get scheduledRideQueuedSubtitle =>
      'يرى السائقون رحلتك المجدولة ويمكنهم قبولها. سنُعلمك عند تعيين سائق.';

  @override
  String scheduledRideQueuedSubtitleWithTime(String when) {
    return 'الاستلام $when. يرى السائقون رحلتك ويمكنهم قبولها — سنُعلمك عند تعيين سائق.';
  }

  @override
  String get tripSummaryDropoffLabel => 'نقطة النزول';

  @override
  String get tripSummarySubtitle => 'راجع التفاصيل قبل طلب سائق';

  @override
  String get tripSummaryPassengerRideSection => 'الراكب ونوع الرحلة';

  @override
  String get tripSummaryPaymentSection => 'الدفع';

  @override
  String get tripSummaryEdit => 'تعديل';

  @override
  String get tripSummaryNameNotSet =>
      'لا يوجد اسم بعد — أضف من يطلب السائق عنه عند الاستلام';

  @override
  String get smartBundleTitle => 'فئات الرحلة';

  @override
  String smartBundleIncludes(Object names) {
    return 'يشمل: $names';
  }

  @override
  String get smartBundleExpandHint => 'تعديل';

  @override
  String get smartBundleTapToExpand => 'اضغط لعرض جميع فئات الرحلة';

  @override
  String get smartBundleExpandSubtitle =>
      'قياسي، مريح، حافلة، كرسي متحرك والأسعار.';

  @override
  String get smartBundleFootnoteWide =>
      'فئات أكثر — عادةً تطابق أسرع. أول سائق يقبل يحدد السعر لفئته.';

  @override
  String get smartBundleFootnoteNarrow =>
      'فئات أقل — قد يستغرق العثور على سائق وقتاً أطول قليلاً.';

  @override
  String get smartBundleFootnoteSingle => 'فئة واحدة — تقدير ثابت لهذه الرحلة.';

  @override
  String smartBundlePriceBand(Object min, Object max) {
    return '€$min–€$max';
  }

  @override
  String smartBundlePriceSingle(Object price) {
    return '€$price';
  }

  @override
  String get smartBundlePetRowTitle => 'رحلة مناسبة للحيوانات';

  @override
  String get smartBundleLoadError =>
      'تعذّر تحميل الأسعار. اختر نوع المركبة أدناه.';

  @override
  String get smartBundleRetry => 'إعادة المحاولة';

  @override
  String get favoriteDriversFirstTripDetail => 'السائقون المفضّلون أولاً';

  @override
  String get bookDriver => 'احجز السائق';

  @override
  String get postToAllDrivers => 'أرسل لجميع السائقين';

  @override
  String get vehiclePreferredCategoryUnavailable =>
      'نوع المركبة المحفوظ غير متاح. تم اختيار قياسي.';

  @override
  String get vehiclePreferredNoDriversNearby =>
      'لا يوجد سائقون لمركبتك المعتادة قريبًا. تم التبديل إلى خيار متاح.';

  @override
  String bookingUsualVehicleChip(String vehicle) {
    return 'معتادك: $vehicle';
  }

  @override
  String get noRidesInCategory => 'لا توجد رحلات في هذه الفئة';

  @override
  String get tryDifferentFilter => 'جرب فلتر مختلف';

  @override
  String get rideStatusCancelled => 'ملغاة';

  @override
  String get rideStatusSearching => 'بحث';

  @override
  String get rideStatusDriverAssigned => 'تم تعيين سائق';

  @override
  String get rideStatusDriverArrived => 'وصل السائق';

  @override
  String get rideStatusInProgress => 'جارية';

  @override
  String get selectAllThatApply => 'اختر كل ما ينطبق';

  @override
  String get morePaymentOptionsHint =>
      'المزيد من خيارات الدفع = فرصة أفضل للعثور على سائق';

  @override
  String get chooseYourRide => 'اختر رحلتك';

  @override
  String get driverPayment => 'دفع السائق';

  @override
  String get searchEnterDestinationHint => 'أدخل الوجهة';

  @override
  String get whenRowLabel => 'متى';

  @override
  String get accountProfileHeading => 'الملف الشخصي';

  @override
  String get accountProfileCardSubtitle => 'اسم الحجز والبريد ومظهر التطبيق.';

  @override
  String get accountProfilePreferencesLabel => 'اللغة والمظهر';

  @override
  String get accountBookingNameLabel => 'اسم الحجز';

  @override
  String get accountBookingNameHint => 'ما الذي يجب أن يناديك به السائق؟';

  @override
  String get accountBookingNameDescription =>
      'سيظهر هذا الاسم للسائقين عند حجزك لرحلة.';

  @override
  String get accountSettingsHeading => 'الإعدادات';

  @override
  String get accountLocationNeededBody =>
      'الوصول إلى الموقع مطلوب لتحديد نقطة انطلاق دقيقة، ومطابقتك مع السائقين القريبين، وتحديثات رحلة موثوقة.';

  @override
  String get accountManageLocation => 'إدارة الوصول إلى الموقع';

  @override
  String get accountNotificationsNeededBody => 'الإشعارات مطلوبة';

  @override
  String get accountManageNotifications => 'إدارة الإشعارات';

  @override
  String get toggleOn => 'مفعّل';

  @override
  String get toggleOff => 'معطّل';

  @override
  String get marketplaceYourSavings => 'توفيرك';

  @override
  String get marketplaceStandardPrice => 'السعر المعتاد';

  @override
  String get marketplaceTypicalPriceTitle => 'المعتاد لهذا المسار';

  @override
  String marketplaceTypicalPriceBody(String amount) {
    return 'بناءً على السائقين القريبين، تكلفة رحلة مثل هذه عادةً حوالي $amount.';
  }

  @override
  String get marketplaceMatchChanceTitle => 'فرصة القبول';

  @override
  String marketplaceMatchChanceBody(String bid, String percent) {
    return 'مع عرض $bid، نقدّر احتمال قبول سائق بحوالي $percent٪.';
  }

  @override
  String get marketplaceMatchChanceStrong =>
      'عرض قوي — سعرك يساوي أو يتجاوز المعتاد، فالسائقون أكثر ميلاً للقبول.';

  @override
  String get marketplacePricingLoading =>
      'جارٍ التحقق من أسعار السائقين المباشرة…';

  @override
  String get marketplaceTypicalUnavailable =>
      'تعذّر تحميل سعر معتاد بعد. حاول مرة أخرى قريبًا.';

  @override
  String marketplaceSavingsVsTypicalPercent(String percent) {
    return 'أقل $percent% عن المعتاد';
  }

  @override
  String marketplaceSavingsBanner(String percent) {
    return 'وفر حتى $percent% على هذه الرحلة';
  }

  @override
  String get marketplaceYourBid => 'عرضك';

  @override
  String get marketplaceQuickSelect => 'اختيار سريع';

  @override
  String get marketplaceHeroTagline =>
      'حدّد سعرك — يقبل السائق أو يقترح سعرًا مقابلًا.';

  @override
  String get marketplaceYourRoute => 'مسارك';

  @override
  String get marketplaceDragToAdjustHint => 'اسحب للتعديل';

  @override
  String get marketplaceSetPickupDestinationHint =>
      'أضف نقطة الالتقاط والوجهة لنشر رحلتك في السوق.';

  @override
  String get marketplaceLiveBadge => 'مباشر';

  @override
  String get marketplaceQuickBudget => 'اقتصادي';

  @override
  String get marketplaceQuickPopular => 'شائع';

  @override
  String get marketplaceQuickFaster => 'أسرع';

  @override
  String get marketplaceQuickExpress => 'سريع';

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
      'احفظ السائقين الموثوقين للحجز السريع';

  @override
  String get favoritesSelectAllDrivers => 'اختر جميع السائقين';

  @override
  String favoritesPostRideTo(int count) {
    return 'انشر الرحلة إلى $count من المفضلين';
  }

  @override
  String get searchFactIndependentDrivers =>
      'السائقون المستقلون يحددون أسعارهم';

  @override
  String get searchFactOwnPrices => 'لا رسوم مبالغ فيها - أبداً';

  @override
  String get searchFactOwnFuel => 'السائقون يدفعون ثمن وقودهم';

  @override
  String get searchFactVerifiedDrivers => 'جميع السائقين موثقون';

  @override
  String get searchFactFavorites =>
      'نرسل طلبك أولاً لسائقيك المحفوظين، ثم لأي سائق متاح قريباً إن لم يقبل أحد.';

  @override
  String get searchEnterPickupHint => 'أدخل موقع الالتقاط';

  @override
  String get goWhereverWhenever => 'اذهب أينما تشاء، متى تشاء.';

  @override
  String get noTaxisInZone => 'لا توجد سيارات أجرة في منطقتك';

  @override
  String get oneTaxiInZone => 'سيارة أجرة واحدة في منطقتك';

  @override
  String taxisInZone(int count) {
    return '$count+ سيارة أجرة في منطقتك';
  }

  @override
  String get favouriteDriver => 'سائق مفضل';

  @override
  String get email => 'البريد الإلكتروني';

  @override
  String get verified => 'موثّق';

  @override
  String get addEmail => 'إضافة بريد إلكتروني';

  @override
  String get add => 'إضافة';

  @override
  String get reportARide => 'الإبلاغ عن رحلة';

  @override
  String get reportARideSubtitle => 'أبلغ عن رحلة مكتملة خلال 24 ساعة.';

  @override
  String get reportSelectRideTitle => 'أي رحلة؟';

  @override
  String get reportSelectRideHint =>
      'اختر رحلة مكتملة لنربط بلاغك بالحجز الصحيح.';

  @override
  String get reportNoRidesToReport =>
      'لا توجد رحلات مكتملة خلال الأسبوعين الماضيين. للمشاكل في رحلة أقدم، تواصل مع الدعم.';

  @override
  String get reportSelectThisRide => 'اختيار';

  @override
  String get reportChangeRide => 'تغيير';

  @override
  String get reportSelectedRideLabel => 'تم اختيار الرحلة';

  @override
  String get reportSelectedRideFallback =>
      'هذه الرحلة مرتبطة ببلاغك. واصل أدناه لوصف المشكلة.';

  @override
  String get reportActiveTripBanner =>
      'أنت تُبلغ عن مشكلة في رحلتك الحالية. صف ما حدث أدناه.';

  @override
  String get ridesCardReportRide => 'الإبلاغ عن الرحلة';

  @override
  String get supportSubtitle => 'سؤال أو مشكلة؟ تحدث مع الدعم';

  @override
  String get supportHubContact => 'تواصل';

  @override
  String get supportNewThread => 'رسالة جديدة';

  @override
  String get supportAllThreads => 'كل الرسائل';

  @override
  String get supportChatSendFailed =>
      'تعذّر الإرسال. تحقق من الاتصال وحاول مرة أخرى.';

  @override
  String get supportNoThreads => 'لا محادثات بعد.';

  @override
  String get supportThreadsTitle => 'الرسائل';

  @override
  String get supportTypeMessage => 'اكتب رسالة';

  @override
  String get supportTicketOpen => 'مفتوح';

  @override
  String get supportTicketResolved => 'مُغلق';

  @override
  String get supportRecentHeading => 'الأحدث';

  @override
  String get supportSeeAll => 'عرض الكل';

  @override
  String get supportOtherCategory => 'أخرى';

  @override
  String get supportHelpArticles => 'مقالات المساعدة';

  @override
  String get supportPickCategory => 'الفئة';

  @override
  String get supportStartChat => 'بدء المحادثة';

  @override
  String get supportSectionOngoing => 'قيد المعالجة';

  @override
  String get supportSectionClosed => 'مغلقة';

  @override
  String get supportResolutionSummary => 'السبب';

  @override
  String get supportResolutionOutcome => 'كيف تم الحل';

  @override
  String get supportChatOfflineSaved =>
      'تم حفظ رسالتك. المساعد غير متصل — يمكن للدعم قراءتها.';

  @override
  String get supportAiConsentTitle => 'تعرّف على ياز، مساعدتك الذكية للدعم';

  @override
  String get supportAiConsentIntro =>
      'ياز هي مساعدة خدمة العملاء بالذكاء الاصطناعي في HeyCaby. مهمتها الاستماع لشكواك والمساعدة في حل المشكلات البسيطة بسرعة.';

  @override
  String get supportAiConsentDataSent =>
      'لمساعدتك، نرسل: نص الرسالة التي تكتبها، وفئة تذكرة الدعم، وسياق حساب محدود لازم للرد على طلبك.';

  @override
  String get supportAiConsentThirdParty =>
      'معالجة الذكاء الاصطناعي: تستخدم ياز نماذج OpenAI (ChatGPT) لتوليد الردود.';

  @override
  String get supportAiConsentPolicy =>
      'للاستفسارات الجادة أو الحساسة، لا تشارك بيانات خاصة في دردشة الذكاء الاصطناعي. يُرجى مراسلة الدعم عبر hello@heycaby.nl.';

  @override
  String get supportAiConsentEmailOption =>
      'لا تشارك كلمات المرور أو أرقام البطاقات الكاملة أو أرقام الهويات الرسمية أو أي بيانات شديدة الحساسية في دردشة الذكاء الاصطناعي.';

  @override
  String get supportAiConsentCheckbox =>
      'أفهم ما هي البيانات التي سيتم إرسالها ومن سيعالجها، وأسمح لـ HeyCaby بمشاركة بيانات محادثة الدعم هذه مع ياز للدعم الذكي.';

  @override
  String get supportAiConsentContinue => 'أوافق وأتابع';

  @override
  String get supportAiConsentSendEmail => 'إرسال بريد إلكتروني بدلاً من ذلك';

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
      'احفظ السائقين الموثوقين وأرسل الرحلات إليهم مباشرة.';

  @override
  String get openLocationSettings => 'فتح إعدادات الموقع';

  @override
  String get openNotificationSettings => 'فتح إعدادات الإشعارات';

  @override
  String get cashSubtitle => 'ادفع نقداً للسائق مباشرة';

  @override
  String get pinSubtitle => 'الدفع ببطاقة الخصم في المركبة';

  @override
  String get tikkieSubtitle => 'ادفع عبر طلب دفع تيكي';

  @override
  String get yourName => 'اسمك';

  @override
  String paymentMethodsSelected(int count) {
    return '$count طريقة دفع محددة';
  }

  @override
  String get vehicleStandard => 'عادي';

  @override
  String get vehicleStandardDesc => 'رحلات بأسعار معقولة للاستخدام اليومي';

  @override
  String get vehicleComfort => 'مريح';

  @override
  String get vehicleComfortDesc => 'مركبات فاخرة بمساحة إضافية';

  @override
  String get vehicleTaxibus => 'تاكسي باص';

  @override
  String get vehicleTaxibusDesc => 'حتى 8 ركاب مع الأمتعة';

  @override
  String get vehicleWheelchair => 'كرسي متحرك';

  @override
  String get vehicleWheelchairDesc => 'مركبات يمكن الوصول إليها بمنحدرات';

  @override
  String get petFriendly => 'صديق للحيوانات';

  @override
  String get petFriendlyDesc => 'سائقون يقبلون الحيوانات الأليفة';

  @override
  String get vehicleSupplyCountCaption => 'سائقون متاحون';

  @override
  String vehicleSupplyDriversCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count سائقين قريبين',
      one: 'سائق واحد قريب',
      zero: 'لا يوجد سائقون قريبون',
    );
    return '$_temp0';
  }

  @override
  String vehicleSupplyNearestKm(String km) {
    return 'الأقرب ~$km كم';
  }

  @override
  String vehicleSupplyFromPrice(String price) {
    return 'من €$price';
  }

  @override
  String get vehicleSupplyShowDrivers => 'عرض السائقين';

  @override
  String get vehicleSupplyHideDrivers => 'إخفاء السائقين';

  @override
  String get vehicleSupplyEstimatesNote =>
      'الأسعار والتوفر تقديرية وقد تتغير عند الحجز.';

  @override
  String get returnTripFareEstimatesTitle => 'عروض العودة';

  @override
  String get returnTripFareEstimatesSubtitle =>
      'عرض أسعار السائقين مع خصم العودة النشط. عطّل لعرض التعرفة العادية.';

  @override
  String get returnTripFareEstimatesRequiresRoute =>
      'أضف نقطة الالتقاط والوجهة لمعاينة أسعار العودة.';

  @override
  String get vehicleSupplyNoPickup =>
      'حدد نقطة الالتقاط لرؤية السائقين القريبين.';

  @override
  String get vehicleSupplyLoading => 'جارٍ التحقق من السائقين القريبين…';

  @override
  String get vehicleSupplyNoDriversInCategory =>
      'لا يوجد سائقون في هذه الفئة حاليًا.';

  @override
  String vehicleDriverOfferRow(String distanceKm, String price) {
    return '~$distanceKm كم · €$price';
  }

  @override
  String vehicleDriverNumbered(int n) {
    return 'سائق $n';
  }

  @override
  String get ratingGreatDriver => 'سائق ممتاز';

  @override
  String get ratingCleanVehicle => 'مركبة نظيفة';

  @override
  String get ratingSafeDriving => 'قيادة آمنة';

  @override
  String get ratingFriendly => 'ودود';

  @override
  String get ratingOnTime => 'في الموعد';

  @override
  String get ratingProfessional => 'محترف';

  @override
  String get failedToSubmitRating => 'فشل إرسال التقييم';

  @override
  String get reportDriverBehavior => 'سلوك السائق';

  @override
  String get reportVehicleCondition => 'حالة المركبة';

  @override
  String get reportRouteIssue => 'مشكلة في المسار';

  @override
  String get reportSafetyConcern => 'مخاوف أمنية';

  @override
  String get reportPricingDispute => 'نزاع على السعر';

  @override
  String get reportOther => 'أخرى';

  @override
  String get driver => 'السائق';

  @override
  String get errorLoadingMessages => 'خطأ في تحميل الرسائل';

  @override
  String get typeAMessage => 'اكتب رسالة...';

  @override
  String get noMessagesYet => 'لا توجد رسائل بعد';

  @override
  String get startConversation => 'ابدأ محادثة مع سائقك';

  @override
  String get faq => 'الأسئلة الشائعة';

  @override
  String get termsOfService => 'شروط الخدمة';

  @override
  String get privacyPolicy => 'سياسة الخصوصية';

  @override
  String get logoutConfirmTitle => 'تسجيل الخروج؟';

  @override
  String get logoutConfirmMessage =>
      'ستحتاج لإعادة إدخال بياناتك للحجز مرة أخرى.';

  @override
  String get linkCopied => 'تم نسخ الرابط إلى الحافظة';

  @override
  String get cancelRide => 'إلغاء الرحلة';

  @override
  String get cancelRideConfirm => 'هل أنت متأكد من إلغاء هذه الرحلة؟';

  @override
  String get noDriverFound => 'لم يتم العثور على سائق';

  @override
  String get noDriverFoundMessage => 'لم نتمكن من العثور على سائق لرحلتك.';

  @override
  String get retrySearch => 'حاول مرة أخرى';

  @override
  String get youHaveArrived => 'لقد وصلت!';

  @override
  String get payDriverCash => 'ادفع نقداً للسائق';

  @override
  String get payDriverPin => 'ادفع بالبطاقة للسائق';

  @override
  String get payDriverTikkie => 'ستتلقى تيكي من السائق';

  @override
  String get rateDriver => 'قيّم السائق';

  @override
  String get addToFavourites => 'أضف إلى المفضلة';

  @override
  String get addComment => 'أضف تعليقاً...';

  @override
  String etaToDestination(String min) {
    return '$min دقيقة إلى الوجهة';
  }

  @override
  String get rideDetails => 'تفاصيل الرحلة';

  @override
  String get rideDetailViewReceipt => 'View receipt';

  @override
  String get rideDetailReceiptLoadFailed => 'Could not load receipt right now.';

  @override
  String get rebookRide => 'احجز مرة أخرى';

  @override
  String get scheduleYourRide => 'جدولة رحلتك';

  @override
  String get selectDate => 'اختر التاريخ';

  @override
  String get selectTime => 'اختر الوقت';

  @override
  String get confirmSchedule => 'تأكيد الجدول';

  @override
  String get postToMarketplace => 'انشر في السوق';

  @override
  String get addYourEmail => 'أضف بريدك الإلكتروني';

  @override
  String get emailOnlyUsedFor =>
      'نستخدم بريدك الإلكتروني فقط للتحقق من هويتك للسائقين المفضلين.';

  @override
  String get enterYourEmail => 'أدخل عنوان بريدك الإلكتروني';

  @override
  String get sendCode => 'إرسال الرمز';

  @override
  String get invalidEmail => 'يرجى إدخال عنوان بريد إلكتروني صالح';

  @override
  String get failedToSaveEmail => 'فشل حفظ البريد الإلكتروني. حاول مرة أخرى.';

  @override
  String get riderEmailReviewCodeHint =>
      'رمز التحقق (مراجعة App Store فقط — اتركه فارغاً لحساب عادي)';

  @override
  String get riderEmailReviewCodeFieldHint =>
      'رمز مكوّن من 6 أرقام من ملاحظات App Store';

  @override
  String get riderEmailReviewCredentialsError =>
      'البريد والرمز لا يطابقان تسجيل المراجعة. اترك الرمز فارغاً إن لم تستخدم حساب المراجعة.';

  @override
  String get riderEmailReviewOtpSixDigitsOrEmpty =>
      'أدخل 6 أرقام كاملة أو اترك حقل الرمز فارغاً.';

  @override
  String get addYourHome => 'أضف عنوان منزلك';

  @override
  String get homeAddressDesc => 'احفظ عنوان منزلك للوصول السريع.';

  @override
  String get enterHomeAddress => 'أدخل عنوان منزلك';

  @override
  String get saving => 'جارٍ الحفظ...';

  @override
  String get failedToSaveHome => 'فشل حفظ عنوان المنزل';

  @override
  String get faqBookingSection => 'الحجز';

  @override
  String get faqHowToBook => 'كيف أحجز رحلة؟';

  @override
  String get faqHowToBookAnswer =>
      'افتح التطبيق، اضغط على \'إلى أين؟\'، أدخل وجهتك، اختر وضع الحجز (فوري أو سوق)، اختر طريقة الدفع واضغط على \'ابحث عن سائقي\'. سيتم ربط سائق قريب برحلتك.';

  @override
  String get faqInstantVsMarketplace => 'ما الفرق بين الفوري والسوق؟';

  @override
  String get faqInstantVsMarketplaceAnswer =>
      'الفوري يرسل طلب رحلتك للسائقين القريبين فوراً. السوق يتيح لك تحديد سعرك والسائقون يمكنهم المزايدة على رحلتك.';

  @override
  String get faqScheduleRide => 'هل يمكنني جدولة رحلة لاحقاً؟';

  @override
  String get faqScheduleRideAnswer =>
      'نعم! اضغط على زر \'لاحقاً\' في الشاشة الرئيسية لاختيار تاريخ ووقت. سيتم إرسال طلبك للسائقين في الوقت المحدد.';

  @override
  String get faqHowMarketplace => 'كيف يعمل السوق؟';

  @override
  String get faqHowMarketplaceAnswer =>
      'تحدد السعر المطلوب للرحلة. يرى السائقون عرضك ويمكنهم المزايدة عليه. تختار السائق بناءً على السعر والتقييم ووقت الوصول.';

  @override
  String get faqDriversSection => 'السائقون والمفضلون';

  @override
  String get faqAddFavourite => 'كيف أضيف سائقاً كمفضل؟';

  @override
  String get faqAddFavouriteAnswer =>
      'بعد إكمال رحلة، اضغط على أيقونة القلب في شاشة التقييم لإضافة السائق إلى مفضلتك. تحتاج بريداً إلكترونياً موثقاً.';

  @override
  String get faqWhatAreFavourites => 'ما هم السائقون المفضلون؟';

  @override
  String get faqWhatAreFavouritesAnswer =>
      'السائقون المفضلون هم سائقون حفظتهم. يمكنك إرسال الرحلات مباشرة لسائقيك الموثوقين.';

  @override
  String get faqBlockDriver => 'هل يمكنني حظر سائق؟';

  @override
  String get faqBlockDriverAnswer =>
      'أثناء دردشة الرحلة النشطة: افتح القائمة (⋮) واختر حظر السائق. يمكنك أيضًا الإبلاغ عن السائق بعد الرحلة من شاشة التقييم.';

  @override
  String get faqPaymentSection => 'الدفع';

  @override
  String get faqPaymentMethods => 'ما طرق الدفع المتاحة؟';

  @override
  String get faqPaymentMethodsAnswer =>
      'نقداً، بطاقة (بطاقة الخصم في المركبة)، وتيكي (طلب دفع بعد الرحلة).';

  @override
  String get faqWhoPaysWho => 'من يدفع لمن؟';

  @override
  String get faqWhoPaysWhoAnswer =>
      'تدفع للسائق مباشرة. HeyCaby لا تأخذ عمولة — 100% من الأجرة تذهب للسائق.';

  @override
  String get faqWhereSeeCosts => 'أين أرى تكاليف رحلتي؟';

  @override
  String get faqWhereSeeCostsAnswer => 'في شاشة إكمال الرحلة وفي سجل الرحلات.';

  @override
  String get faqSafetySection => 'المشاكل والسلامة';

  @override
  String get faqDriverNoShow => 'ماذا أفعل إذا لم يأتِ سائقي؟';

  @override
  String get faqDriverNoShowAnswer =>
      'شاشة الانتظار بها خيار إلغاء. إذا لم يتم العثور على سائق خلال دقائق، يمكنك إعادة المحاولة أو الإلغاء.';

  @override
  String get faqReportIncident => 'كيف أبلغ عن حادث؟';

  @override
  String get faqReportIncidentAnswer =>
      'بعد الرحلة، استخدم خيار الإبلاغ في شاشة التقييم لإرسال تفاصيل ما حدث.';

  @override
  String get faqInsurance => 'هل رحلتي مؤمنة؟';

  @override
  String get faqInsuranceAnswer =>
      'جميع سائقي HeyCaby سائقون محترفون مرخصون بتأمين صالح.';

  @override
  String get faqAccountSection => 'الحساب';

  @override
  String get faqChangeName => 'كيف أغير اسم الحجز؟';

  @override
  String get faqChangeNameAnswer =>
      'اذهب إلى الحساب واضغط على حقل الاسم لتعديله.';

  @override
  String get faqVerifyEmail => 'كيف أوثق بريدي الإلكتروني؟';

  @override
  String get faqVerifyEmailAnswer =>
      'المفضلة تتطلب بريداً محفوظاً. افتح الحساب أو السائقون المفضلون، اضغط إضافة بريد، أدخل عنوانك واضغط متابعة. لمراجعة App Store: استخدم بريد المراجعة والرمز المكوّن من 6 أرقام من معلومات المراجعة.';

  @override
  String get faqDeleteAccount => 'كيف أحذف حسابي؟';

  @override
  String get faqDeleteAccountAnswer =>
      'انتقل إلى الحساب، اضغط حذف حسابي، وأكد بكتابة DELETE. يزيل ذلك هوية الراكب والبيانات المرتبطة من HeyCaby.';

  @override
  String get termsTitle => 'شروط الخدمة';

  @override
  String get termsWhatIsHeyCaby => 'ما هو HeyCaby';

  @override
  String get termsWhatIsHeyCabyBody =>
      'HeyCaby منصة بدون عمولة تربط الركاب بسائقي التاكسي المحترفين المرخصين في هولندا.';

  @override
  String get termsRiderResponsibilities => 'مسؤوليات الراكب';

  @override
  String get termsRiderResponsibilitiesBody =>
      'يجب على الركاب تقديم معلومات حجز دقيقة. السلوك المحترم تجاه السائقين مطلوب في جميع الأوقات.';

  @override
  String get termsPayment => 'الدفع';

  @override
  String get termsPaymentBody =>
      'جميع المدفوعات تتم مباشرة من الراكب إلى السائق. HeyCaby لا تعالج أو تحتفظ بأي نسبة.';

  @override
  String get termsCancellation => 'الإلغاء';

  @override
  String get termsCancellationBody =>
      'يمكن إلغاء الرحلات مجاناً قبل قبول السائق. بعد القبول، قد يفرض السائق رسوم إلغاء.';

  @override
  String get termsSuspension => 'تعليق الحساب';

  @override
  String get termsSuspensionBody =>
      'تحتفظ HeyCaby بالحق في تعليق الحسابات في حالات الاحتيال أو سوء الاستخدام.';

  @override
  String get termsDisputes => 'حل النزاعات';

  @override
  String get termsDisputesBody =>
      'يجب الإبلاغ عن النزاعات أولاً عبر ميزة الإبلاغ في التطبيق.';

  @override
  String get termsGoverningLaw => 'القانون المعمول به';

  @override
  String get termsGoverningLawBody => 'تخضع هذه الشروط لقوانين هولندا.';

  @override
  String get termsContact => 'التواصل';

  @override
  String get termsContactBody => 'للأسئلة، تواصل مع الدعم عبر شاشة الحساب.';

  @override
  String get privacyTitle => 'سياسة الخصوصية';

  @override
  String get privacyDataCollected => 'البيانات المجمعة';

  @override
  String get privacyDataCollectedBody =>
      'نجمع فقط البيانات اللازمة لتقديم الخدمة:\n• بيانات الحساب: البريد الإلكتروني وبيانات الملف الأساسية لإنشاء الحساب والتحقق من الهوية\n• بيانات الموقع: أثناء الحجوزات النشطة لمطابقة الركاب مع السائقين القريبين\n• بيانات الرحلة: مواقع الالتقاط/الإنزال والطوابع الزمنية وسجل الرحلات للإيصالات وتحسين الخدمة\n• بيانات الجهاز: إصدار التطبيق ونوع الجهاز ورموز الإشعارات للتشغيل والأداء\n• بيانات الدعم: رسائل تذاكر الدعم وفئتها، وقد تُعالج عبر مزود دعم الذكاء الاصطناعي عند موافقتك داخل الدردشة';

  @override
  String get privacyLocationData => 'بيانات الموقع';

  @override
  String get privacyLocationDataBody =>
      'تُستخدم بيانات الموقع فقط أثناء جلسات الحجز والرحلة النشطة.';

  @override
  String get privacyDataSharing => 'مشاركة البيانات';

  @override
  String get privacyDataSharingBody =>
      'نشارك بيانات محدودة فقط عند الحاجة لتقديم الخدمة.\n\nيتلقى السائق: اسم الحجز (أو الاسم المستعار) وموقع الالتقاط.\nيتلقى الراكب: بيانات السائق اللازمة للرحلة.\n\nدعم الذكاء الاصطناعي (بعد موافقتك قبل أول رسالة): تتم معالجة محتوى رسائل الدعم وفئة التذكرة وسياق محدود لازم للرد عبر نماذج OpenAI (ChatGPT).\n\nلا نشارك البريد الإلكتروني أو رقم الهاتف (إلا إذا لزم مستقبلاً لميزة محددة) أو البيانات الشخصية الحساسة في دردشة الذكاء الاصطناعي.';

  @override
  String get privacyRetention => 'الاحتفاظ بالبيانات';

  @override
  String get privacyRetentionBody =>
      'يُحتفظ بسجل الرحلات للإيصالات. تُحذف بيانات الحساب عند الطلب.';

  @override
  String get privacyGdpr => 'حقوقك';

  @override
  String get privacyGdprBody =>
      'بموجب اللائحة العامة لحماية البيانات، لديك حق الوصول والتصحيح والحذف. يمكنك حذف حساب الراكب من التطبيق عبر الحساب ← حذف حسابي. لطلبات أخرى، تواصل مع الدعم من شاشة الحساب.';

  @override
  String get privacyNoAds =>
      '2/7/8/9/10/11/12. الاستخدام، دعم الذكاء الاصطناعي (ياز)، الأمان، الإشعارات، الأطراف الثالثة، التحديثات، التواصل';

  @override
  String get privacyNoAdsBody =>
      'تُستخدم بياناتك فقط لتشغيل HeyCaby: مطابقة الركاب مع السائقين، إدارة الحجوزات والتواصل، عرض سجل الرحلات والإيصالات، تحسين الأداء، وإرسال الإشعارات المهمة.\n\nدعم الذكاء الاصطناعي (ياز): عند اختيارك \"الدردشة مع ياز\" وموافقتك الصريحة داخل التطبيق، تتم معالجة محتوى رسالة الدعم، وفئة التذكرة، وسياق حساب محدود عبر OpenAI (ChatGPT) لتوليد ردود الدعم. الدردشة مع الذكاء الاصطناعي اختيارية، ويمكنك استخدام دعم غير معتمد على الذكاء الاصطناعي عبر \"رسالة جديدة\".\n\nنطلب من المستخدمين عدم إرسال بيانات شديدة الحساسية في دردشة الذكاء الاصطناعي (مثل كلمات المرور، أرقام البطاقات الكاملة، أو أرقام الهويات الرسمية). وللمشكلات الحساسة أو المعقدة، نوجّه المستخدمين إلى الدعم البشري.\n\nلا نستخدم بياناتك للإعلانات ولا نبيع بياناتك لأطراف ثالثة.\n\nنطبق إجراءات تقنية وتنظيمية للحماية، لكن لا يوجد نظام آمن بنسبة 100%.\n\nقد تتضمن الإشعارات تحديثات الرحلات ورسائل خدمة مهمة وتحديثات منتج من حين لآخر. يمكنك تعطيل الإشعارات من إعدادات الجهاز.\n\nقد نستخدم مزودي خدمة موثوقين (مثل مزودي الدفع وFirebase وSupabase) فقط بالقدر اللازم لتقديم الخدمة.\n\nقد نحدّث هذه السياسة من وقت لآخر، واستمرارك في استخدام التطبيق يعني موافقتك على التحديثات.\n\nلطلبات الخصوصية، تواصل معنا عبر قسم الدعم داخل التطبيق.';

  @override
  String distanceRemaining(String km) {
    return '$km كم متبقية';
  }

  @override
  String get shareRideLink => 'مشاركة رابط الرحلة';

  @override
  String get rideShareCopied => 'تم نسخ رابط تتبع الرحلة إلى الحافظة';

  @override
  String get deleteMyAccount => 'حذف حسابي';

  @override
  String get deleteAccountConfirmTitle => 'حذف الحساب نهائيًا؟';

  @override
  String get deleteAccountConfirmBody =>
      'ستُزال ملفات الراكب والبيانات المرتبطة بهذه الجلسة من HeyCaby. قد تُحفظ بعض سجلات الرحلات حيث يقتضي القانون ذلك. لا يمكن التراجع.';

  @override
  String get deleteAccountTypeDeleteHint => 'اكتب DELETE للتأكيد';

  @override
  String get deleteAccountTypeDeleteError =>
      'اكتب كلمة DELETE (بأي حالة أحرف)، ثم اضغط حذف حسابي مرة أخرى.';

  @override
  String get deleteAccountFailed =>
      'تعذر حذف الحساب. حاول مرة أخرى أو تواصل مع الدعم.';

  @override
  String get deleteAccountSuccess => 'تم حذف حسابك.';

  @override
  String get deleteAccountSuccessModalTitle => 'تم حذف الحساب';

  @override
  String get deleteAccountSuccessModalBody =>
      'تمت إزالة ملف الراكب لديك والبيانات الشخصية المرتبطة بهذا التطبيق نهائيًا من HeyCaby.\n\nيمكنك حذف التطبيق من هاتفك في أي وقت—لا يلزمك إجراء آخر هنا.';

  @override
  String get deleteAccountSuccessModalCta => 'متابعة';

  @override
  String get deleteAccountNoSession => 'لا توجد جلسة نشطة للحذف.';

  @override
  String get deleteAccountNoPersonalDataMessage =>
      'لا توجد معلومات شخصية محفوظة في نظامنا. لا يوجد بريد إلكتروني أو بيانات للحذف. يمكنك إزالة التطبيق من هاتفك.';

  @override
  String get deleteAccountNoEmailMessage =>
      'لا يوجد بريد إلكتروني مرتبط بحسابك. لا توجد بيانات شخصية للحذف. يمكنك إزالة التطبيق من هاتفك.';

  @override
  String get dialogOk => 'حسنًا';

  @override
  String get blockDriver => 'حظر السائق';

  @override
  String get blockDriverConfirm =>
      'لن تظهر لك رسائل جديدة من هذا السائق في دردشة هذه الرحلة.';

  @override
  String get reportDriverTitle => 'الإبلاغ عن هذا السائق؟';

  @override
  String get reportDriverBody =>
      'سيراجع HeyCaby محادثة هذه الرحلة. يمكنك إضافة تفاصيل أدناه (اختياري).';

  @override
  String get reportReasonHint => 'ماذا حدث؟ (اختياري)';

  @override
  String get chatReportSubmitted => 'شكرًا — استلمنا بلاغك.';

  @override
  String get chatMoreOptions => 'المزيد';

  @override
  String get chatBlockFailed => 'تعذر تحديث قائمة الحظر.';

  @override
  String get chatReportFailed => 'تعذر إرسال البلاغ. حاول مرة أخرى.';

  @override
  String get saveButton => 'حفظ';

  @override
  String get savedAddressesSubtitle => 'وجهاتك المحفوظة';

  @override
  String get savedPlacesSheetSubtitle =>
      'اضغط للحجز إلى هناك، أو احفظ مكانًا آخر أدناه.';

  @override
  String get noSavedAddressesYet => 'اختصاراتك';

  @override
  String get noSavedAddressesEmptyBody =>
      'احفظ المنزل أو العمل أو النادي — أو عدة منازل (أم، أب، بيت العطلة). نفس الأيقونة وأسماء مختلفة.';

  @override
  String get addSavedAddress => 'حفظ مكان';

  @override
  String get addSavedAddressSheetTitle => 'حفظ مكان جديد';

  @override
  String get savedAddressCategoryLabel => 'الفئة';

  @override
  String get savedAddressNameLabel => 'اسم المكان';

  @override
  String get savedAddressNameHint => 'مثلًا: بيت أمي، المكتب، النادي';

  @override
  String get savedAddressSearchLabel => 'العنوان';

  @override
  String get savedAddressSearchHint => 'ابحث عن عنوان';

  @override
  String get savedAddressesEmailPrompt =>
      'احفظ عناوينك المفضلة واحجز بنقرة واحدة. أدخل بريدك الإلكتروني للبدء.';

  @override
  String get savedAddressesGetStarted => 'ابدأ';

  @override
  String get savedAddressesUnlocked => 'رائع! يمكنك الآن حفظ العناوين.';

  @override
  String get savedAddressLabelHome => 'المنزل';

  @override
  String get savedAddressLabelWork => 'العمل';

  @override
  String get savedAddressLabelGym => 'الصالة الرياضية';

  @override
  String get savedAddressLabelCustom => 'مخصص';

  @override
  String get savedAddressesLimitReached =>
      'يمكنك حفظ ما يصل إلى 10 أماكن. احذف مكانًا لإضافة مكان آخر.';

  @override
  String get deleteSavedAddress => 'حذف';

  @override
  String get searchFactDriversKeep100 =>
      'السائقون يحتفظون بـ 100٪ من أرباحهم. HeyCaby لا تأخذ أي عمولة.';

  @override
  String get searchFactNoSurgePricing =>
      'لا توجد أسعار متضاعفة. أبدًا. السعر الذي تراه هو السعر الذي تدفعه.';

  @override
  String get searchFactAllVerified =>
      'كل رخصة، كل تأمين، كل تصريح — تم التحقق منها قبل البدء.';

  @override
  String get searchFactMarketplace =>
      'السائقون العائدون إلى مدنهم يقدمون أحيانًا أسعارًا أقل. تحقق من السوق للحصول على أفضل سعر.';

  @override
  String get searchFactZZP =>
      'كل سائق Caby محترف مستقل. أنت تسافر مع شخص فخور بعمله.';

  @override
  String get searchFactSaveAddresses =>
      'هل تسكن في روتردام؟ انقر على أيقونة المنزل مرة واحدة وسيتم ملء وجهتك تلقائيًا.';

  @override
  String get searchFactPayHowYouWant =>
      'نقدًا أو Tikkie أو بطاقة — سيخبرك سائقك بالخيارات المتاحة.';

  @override
  String get searchingTitle => 'نبحث عن أقرب Caby…';

  @override
  String get matchingTitleMarketplace => 'نبحث عن Caby من السوق…';

  @override
  String get matchingTitleScheduled => 'نبحث عن Caby لرحلتك المجدولة…';

  @override
  String get homeNearTermTitleInstant => 'جارٍ العثور على Caby';

  @override
  String get homeNearTermTitleMarketplace => 'طلب من السوق';

  @override
  String get homeNearTermTitleScheduled => 'رحلة مجدولة';

  @override
  String get homeNearTermOpenMatching =>
      'ما زلنا نربطك بسائق. انقر لعرض التقدم.';

  @override
  String get homeNearTermOpenMatchingHint =>
      'ما زلنا نطابق — اضغط لتفاصيل الرحلة';

  @override
  String get homeNearTermTripDetails => 'تفاصيل الرحلة';

  @override
  String get rideMatchingTypeLabelInstant => 'رحلة فورية';

  @override
  String get rideMatchingTypeLabelMarketplace => 'السوق';

  @override
  String get rideMatchingTypeLabelScheduled => 'مجدولة';

  @override
  String get activeSearchStopTitle => 'إيقاف البحث؟';

  @override
  String get activeSearchStopBody =>
      'سنلغي طلب الرحلة هذا. لن يراه السائقون ولن تصلك إشعارات منهم. يمكنك الحجز مجددًا في أي وقت.';

  @override
  String get activeSearchStopConfirm => 'إيقاف الرحلة';

  @override
  String get activeSearchStopKeep => 'متابعة البحث';

  @override
  String homeNearTermUntilPickup(String remaining) {
    return 'الاستلام خلال $remaining';
  }

  @override
  String get ridesScheduledMatchingSection => 'طلبات مجدولة قادمة';

  @override
  String get noDriverFoundCard => 'لم يُعثر على Caby بعد. ماذا تريد أن تفعل؟';

  @override
  String get notifyMeWhenFound => 'أعلمني';

  @override
  String get scheduleRideInstead => 'جدولة';

  @override
  String get activeSearchBannerSubtitle => 'سنرسل إشعارًا فور العثور على سائق.';

  @override
  String get activeSearchCardHint =>
      'HeyCaby جديدة ولا تزال تنمو. يتوقف البحث في الخلفية تلقائيًا بعد 30 دقيقة — لن تبقى في انتظار بلا نهاية.';

  @override
  String activeSearchMinutesLeft(int minutes) {
    return 'متبقي $minutes د';
  }

  @override
  String get noCabyFoundModalTitle => 'عذرًا، لم نجد Caby 😔';

  @override
  String get noCabyFoundModalBody =>
      'ما زلنا منصة نامية بعدد محدود من السائقين. يمكنك المساعدة! هل تعرف سائق تاكسي معتمدًا؟ شارك HeyCaby معهم — معًا نكبر المنصة.';

  @override
  String get shareHeyCabyInvite => 'شارك HeyCaby ←';

  @override
  String shareHeyCabyMessage(String url) {
    return 'جرّب HeyCaby — رحلات عادلة، بدون عمولة للسائقين. $url';
  }

  @override
  String get growthModalClose => 'إغلاق';

  @override
  String get riderEmailVerificationSent =>
      'أرسلنا رمزًا مكوّنًا من 6 أرقام إلى بريدك. أدخله أدناه.';

  @override
  String get riderSplashTagline => 'Caby الخاص بك في دقائق.';

  @override
  String get activeSearchWidget => 'جارٍ البحث عن Caby…';

  @override
  String get driverFoundWidget => 'تم العثور على Caby! تأكيد رحلتك ←';

  @override
  String get riderNameLabel => 'اسمك';

  @override
  String get scheduledRideLabel => 'مجدول لـ';

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
  String get activeRideFoundingShort => 'Founding';

  @override
  String get activeRideShareSubtitle => 'Share live trip link';

  @override
  String get activeRideReportSubtitle => 'Submit ride report';

  @override
  String get activeRideSupportSubtitle => 'Safety and help';

  @override
  String get activeRidePickupNotSet => 'Pickup not set';

  @override
  String get activeRideDestinationNotSet => 'Destination not set';

  @override
  String get activeRideShareDetails => 'Share ride details';

  @override
  String get activeRideContactDriver => 'اتصل بالسائق';

  @override
  String activeRideCategoryLabel(String category) {
    return 'Category: $category';
  }

  @override
  String get activeRideCancelReasonLongPickup => 'طول وقت الوصول';

  @override
  String get activeRideCancelReasonBetterAlternative => 'وجدت بديلاً أفضل';

  @override
  String get activeRideCancelReasonDriverNotCloser => 'السائق لا يقترب';

  @override
  String get activeRideCancelReasonDriverAskedCancel => 'طلب السائق الإلغاء';

  @override
  String get activeRideCancelReasonPriceDispute => 'خلاف على السعر مع السائق';

  @override
  String get activeRideCancelReasonOutsideAppPayment =>
      'طلب السائق الدفع خارج التطبيق';

  @override
  String get activeRidePlateNumber => 'رقم اللوحة';

  @override
  String get activeRideUnknownPlate => 'غير معروف';

  @override
  String get activeRideFoundingMember => 'عضو مؤسس';

  @override
  String get activeRideVerifyPlate =>
      'يرجى التحقق من هذه اللوحة قبل دخول المركبة.';

  @override
  String get openAction => 'فتح';

  @override
  String get rideReceiptTitle => 'إيصال الرحلة';

  @override
  String get rideReceiptUnavailable => 'الإيصال غير متاح بعد.';

  @override
  String get rideReceiptSettlement => 'التسوية';

  @override
  String get rideReceiptRideId => 'معرّف الرحلة';

  @override
  String get rideReceiptExpected => 'المتوقع';

  @override
  String get rideReceiptPaid => 'المدفوع';

  @override
  String get rideReceiptMethod => 'طريقة الدفع';

  @override
  String get rideReceiptNote => 'ملاحظة';

  @override
  String get rideReceiptOutstanding => 'المتبقي';

  @override
  String get rideReceiptOverpaid => 'مدفوع بزيادة';

  @override
  String get rideReceiptStatus => 'الحالة';

  @override
  String get rideReceiptSettlementComplete => 'اكتملت التسوية';

  @override
  String get smartBundleRideTypeOptions => 'خيارات نوع الرحلة';

  @override
  String smartBundleEstimatedPrice(String min, String max) {
    return 'السعر التقديري: $min - $max';
  }

  @override
  String get smartBundleDriverPricingNote =>
      'السائقون يحددون أسعارهم الخاصة. سنطابقك مع أفضل الخيارات القريبة.';

  @override
  String get smartBundleTapToHide => 'اضغط لإخفاء فئات الرحلات';
}
