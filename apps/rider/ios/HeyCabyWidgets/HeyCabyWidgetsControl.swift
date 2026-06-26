import AppIntents
import SwiftUI
import WidgetKit

struct HeyCabyWidgetsControl: ControlWidget {
    static let kind: String = "nl.heycaby.rider.app.HeyCabyWidgetsExtension"

    var body: some ControlWidgetConfiguration {
        AppIntentControlConfiguration(
            kind: Self.kind,
            provider: Provider()
        ) { value in
            ControlWidgetToggle(
                "Ride updates",
                isOn: value.isRunning,
                action: SetRideUpdatesIntent(value.name)
            ) { isRunning in
                Label(isRunning ? "Enabled" : "Disabled", systemImage: "car.fill")
            }
        }
        .displayName("HeyCaby ride updates")
        .description("Enable or disable quick ride status controls.")
    }
}

extension HeyCabyWidgetsControl {
    struct Value {
        var isRunning: Bool
        var name: String
    }

    struct Provider: AppIntentControlValueProvider {
        func previewValue(configuration: RideUpdatesConfiguration) -> Value {
            HeyCabyWidgetsControl.Value(isRunning: false, name: configuration.timerName)
        }

        func currentValue(configuration: RideUpdatesConfiguration) async throws -> Value {
            let isRunning = false
            return HeyCabyWidgetsControl.Value(isRunning: isRunning, name: configuration.timerName)
        }
    }
}

struct RideUpdatesConfiguration: ControlConfigurationIntent {
    static let title: LocalizedStringResource = "Ride updates configuration"

    @Parameter(title: "Label", default: "Ride updates")
    var timerName: String
}

struct SetRideUpdatesIntent: SetValueIntent {
    static let title: LocalizedStringResource = "Set ride updates"

    @Parameter(title: "Label")
    var name: String

    @Parameter(title: "Enabled")
    var value: Bool

    init() {}

    init(_ name: String) {
        self.name = name
    }

    func perform() async throws -> some IntentResult {
        return .result()
    }
}
