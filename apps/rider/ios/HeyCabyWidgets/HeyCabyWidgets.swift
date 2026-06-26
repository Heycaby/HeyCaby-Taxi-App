import WidgetKit
import SwiftUI

struct HeyCabyStatusProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), configuration: RideStatusConfigurationAppIntent())
    }

    func snapshot(for configuration: RideStatusConfigurationAppIntent, in context: Context) async -> SimpleEntry {
        SimpleEntry(date: Date(), configuration: configuration)
    }
    
    func timeline(for configuration: RideStatusConfigurationAppIntent, in context: Context) async -> Timeline<SimpleEntry> {
        let entry = SimpleEntry(date: Date(), configuration: configuration)
        return Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(60 * 15)))
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let configuration: RideStatusConfigurationAppIntent
}

struct HeyCabyStatusEntryView: View {
    var entry: HeyCabyStatusProvider.Entry

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "car.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.yellow)
            VStack(alignment: .leading, spacing: 2) {
                Text("HeyCaby Rider")
                    .font(.subheadline.weight(.semibold))
                Text("Open app for live ride status")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(12)
        .widgetURL(URL(string: "heycabyrider://ride-status"))
    }
}

struct HeyCabyStatusWidget: Widget {
    let kind: String = "HeyCabyStatusWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: RideStatusConfigurationAppIntent.self, provider: HeyCabyStatusProvider()) { entry in
            HeyCabyStatusEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Ride status")
        .description("Quick access to your current HeyCaby ride.")
    }
}

extension RideStatusConfigurationAppIntent {
    fileprivate static var previewValue: RideStatusConfigurationAppIntent {
        let intent = RideStatusConfigurationAppIntent()
        intent.showCurrentRide = true
        return intent
    }
}

#Preview(as: .systemSmall) {
    HeyCabyStatusWidget()
} timeline: {
    SimpleEntry(date: .now, configuration: .previewValue)
}
