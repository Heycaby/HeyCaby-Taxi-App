import WidgetKit
import AppIntents

struct RideStatusConfigurationAppIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "Ride Status" }
    static var description: IntentDescription { "Shows quick access to your HeyCaby ride status." }

    @Parameter(title: "Show current ride", default: true)
    var showCurrentRide: Bool
}
