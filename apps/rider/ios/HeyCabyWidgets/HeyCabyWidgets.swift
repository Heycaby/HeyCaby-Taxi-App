import WidgetKit
import SwiftUI

let kAppGroup = "group.nl.heycaby.rider.app.widgets"

struct RideWidgetData {
    let status: String
    let driverName: String
    let car: String
    let plate: String
    let rating: String
    let etaMinutes: String
    let pickup: String
    // Widget D (in-progress)
    let dStatus: String
    let dDestination: String
    let dDestinationCity: String
    let dMinutesRemaining: String
    let dKmRemaining: String
    let dProgressPct: String

    static func load() -> RideWidgetData {
        let defaults = UserDefaults(suiteName: kAppGroup)
        func s(_ key: String) -> String { defaults?.string(forKey: key) ?? "" }
        return RideWidgetData(
            status: s("widget_a_status"),
            driverName: s("widget_a_driver_name"),
            car: s("widget_a_car"),
            plate: s("widget_a_plate"),
            rating: s("widget_a_rating"),
            etaMinutes: s("widget_a_eta_minutes"),
            pickup: s("widget_a_pickup"),
            dStatus: s("widget_d_status"),
            dDestination: s("widget_d_destination"),
            dDestinationCity: s("widget_d_destination_city"),
            dMinutesRemaining: s("widget_d_minutes_remaining"),
            dKmRemaining: s("widget_d_km_remaining"),
            dProgressPct: s("widget_d_progress_pct")
        )
    }

    var isActive: Bool {
        status != "inactive" && status != "" || dStatus == "in_progress"
    }
}

struct HeyCabyStatusProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), configuration: RideStatusConfigurationAppIntent(), data: RideWidgetData(status: "driver_found", driverName: "Ahmed", car: "Toyota Prius", plate: "AB-123-C", rating: "4.8", etaMinutes: "5", pickup: "Centraal Station", dStatus: "inactive", dDestination: "", dDestinationCity: "", dMinutesRemaining: "", dKmRemaining: "", dProgressPct: ""))
    }

    func snapshot(for configuration: RideStatusConfigurationAppIntent, in context: Context) async -> SimpleEntry {
        SimpleEntry(date: Date(), configuration: configuration, data: RideWidgetData.load())
    }
    
    func timeline(for configuration: RideStatusConfigurationAppIntent, in context: Context) async -> Timeline<SimpleEntry> {
        let entry = SimpleEntry(date: Date(), configuration: configuration, data: RideWidgetData.load())
        return Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(15)))
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let configuration: RideStatusConfigurationAppIntent
    let data: RideWidgetData
}

struct HeyCabyStatusEntryView: View {
    var entry: HeyCabyStatusProvider.Entry
    private var d: RideWidgetData { entry.data }

    private var phaseLabel: String {
        if d.dStatus == "in_progress" {
            return "Trip in progress"
        }
        switch d.status {
        case "searching": return "Searching for driver"
        case "driver_found": return "Driver on the way"
        case "notify_background": return "Searching for driver"
        default: return "HeyCaby Rider"
        }
    }

    private var phaseIcon: String {
        if d.dStatus == "in_progress" { return "road.horizontal" }
        switch d.status {
        case "searching", "notify_background": return "magnifyingglass"
        case "driver_found": return "car.fill"
        default: return "car.fill"
        }
    }

    private var etaText: String {
        if d.dStatus == "in_progress" {
            let mins = d.dMinutesRemaining
            return mins.isEmpty ? "" : "\(mins) min left"
        }
        let mins = d.etaMinutes
        return mins.isEmpty ? "" : "ETA \(mins) min"
    }

    var body: some View {
        if !d.isActive {
            HStack(spacing: 10) {
                Image(systemName: "car.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.yellow)
                VStack(alignment: .leading, spacing: 2) {
                    Text("HeyCaby Rider")
                        .font(.subheadline.weight(.semibold))
                    Text("Open app to book a ride")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(12)
            .widgetURL(URL(string: "heycabyrider://ride-status"))
        } else if d.dStatus == "in_progress" {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Image(systemName: phaseIcon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.yellow)
                    Text(phaseLabel)
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Text(etaText)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.green)
                }
                if !d.dDestination.isEmpty {
                    Text(d.dDestinationCity.isEmpty ? d.dDestination : d.dDestinationCity)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                if !d.dProgressPct.isEmpty, let pct = Int(d.dProgressPct) {
                    ProgressView(value: Double(pct), total: 100)
                        .tint(.yellow)
                }
            }
            .padding(12)
            .widgetURL(URL(string: "heycabyrider://ride-status"))
        } else {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Image(systemName: phaseIcon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.yellow)
                    Text(phaseLabel)
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    if !etaText.isEmpty {
                        Text(etaText)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.green)
                    }
                }
                if !d.driverName.isEmpty {
                    HStack(spacing: 6) {
                        Text(d.driverName)
                            .font(.caption.weight(.medium))
                        if !d.rating.isEmpty {
                            HStack(spacing: 2) {
                                Image(systemName: "star.fill")
                                    .font(.system(size: 9))
                                Text(d.rating)
                                    .font(.caption2)
                            }
                            .foregroundStyle(.orange)
                        }
                    }
                }
                if !d.car.isEmpty || !d.plate.isEmpty {
                    Text([d.car, d.plate].filter { !$0.isEmpty }.joined(separator: " · "))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .padding(12)
            .widgetURL(URL(string: "heycabyrider://ride-status"))
        }
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
        .description("See your HeyCaby ride status on your lock screen — driver info, ETA, and trip progress.")
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
    SimpleEntry(date: .now, configuration: .previewValue, data: RideWidgetData(status: "driver_found", driverName: "Ahmed", car: "Toyota Prius", plate: "AB-123-C", rating: "4.8", etaMinutes: "5", pickup: "Centraal Station", dStatus: "inactive", dDestination: "", dDestinationCity: "", dMinutesRemaining: "", dKmRemaining: "", dProgressPct: ""))
}

#Preview(as: .systemMedium) {
    HeyCabyStatusWidget()
} timeline: {
    SimpleEntry(date: .now, configuration: .previewValue, data: RideWidgetData(status: "inactive", driverName: "", car: "", plate: "", rating: "", etaMinutes: "", pickup: "", dStatus: "in_progress", dDestination: "Schiphol Airport", dDestinationCity: "Schiphol", dMinutesRemaining: "12", dKmRemaining: "8.5", dProgressPct: "45"))
}
