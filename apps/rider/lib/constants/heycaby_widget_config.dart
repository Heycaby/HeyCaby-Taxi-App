/// App Group used by Runner + WidgetKit extension (must match Xcode capabilities).
const String kHeyCabyIosWidgetAppGroup = 'group.nl.heycaby.rider.widgets';

/// Custom URL scheme for widget taps → [HeyCabyWidgetDeepLinkScope] (Info.plist + Swift widgetURL).
const String kHeyCabyWidgetUrlScheme = 'heycabyrider';

/// Android `AppWidgetProvider` qualified class name (`HeyCabyHomeWidgetProvider` + manifest receiver).
const String kHeyCabyAndroidHomeWidgetProvider =
    'com.heycaby.rider.HeyCabyHomeWidgetProvider';
