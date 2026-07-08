import ActivityKit
import WidgetKit
import SwiftUI

private let kLiveActivityAppGroup = "group.nl.heycaby.rider.widgets"

/// Must match the `live_activities` Flutter plugin attribute name exactly.
struct LiveActivitiesAppAttributes: ActivityAttributes, Identifiable {
    public typealias LiveDeliveryData = ContentState

    public struct ContentState: Codable, Hashable {
        var appGroupId: String
    }

    var id = UUID()
}

extension LiveActivitiesAppAttributes {
    func prefixedKey(_ key: String) -> String {
        return "\(id)_\(key)"
    }
}

private struct LiveRidePayload {
    let title: String
    let subtitle: String
    let status: String
    let eta: String
    let timelineStep: Int
    let graceRemaining: String
    let totalFare: String
    let waitFee: String

    static func load(from context: ActivityViewContext<LiveActivitiesAppAttributes>) -> LiveRidePayload {
        let defaults = UserDefaults(suiteName: kLiveActivityAppGroup)!
        func str(_ key: String) -> String {
            defaults.string(forKey: context.attributes.prefixedKey(key)) ?? ""
        }
        return LiveRidePayload(
            title: str("title"),
            subtitle: str("subtitle"),
            status: str("status"),
            eta: str("eta"),
            timelineStep: Int(str("timelineStep")) ?? 0,
            graceRemaining: str("graceRemaining"),
            totalFare: str("totalFare"),
            waitFee: str("waitFee")
        )
    }
}

private struct RideTimelineDots: View {
    let currentStep: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<5, id: \.self) { index in
                Circle()
                    .fill(index <= currentStep ? Color.green : Color.white.opacity(0.25))
                    .frame(width: index == currentStep ? 8 : 6, height: index == currentStep ? 8 : 6)
            }
        }
    }
}

struct HeyCabyWidgetsLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: LiveActivitiesAppAttributes.self) { context in
            let data = LiveRidePayload.load(from: context)
            let title = data.title.isEmpty ? "HeyCaby" : data.title

            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(.headline.weight(.bold))
                            .foregroundStyle(.white)
                        if !data.subtitle.isEmpty {
                            Text(data.subtitle)
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.78))
                                .lineLimit(2)
                        }
                    }
                    Spacer(minLength: 8)
                    if !data.eta.isEmpty {
                        Text(data.eta)
                            .font(.footnote.weight(.bold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.white.opacity(0.14))
                            .clipShape(Capsule())
                            .foregroundStyle(.white)
                    }
                }

                RideTimelineDots(currentStep: data.timelineStep)

                HStack {
                    Image(systemName: "car.fill")
                        .foregroundStyle(.yellow)
                    Text(data.status.isEmpty ? "Live ride" : data.status)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.9))
                    Spacer()
                    if !data.graceRemaining.isEmpty {
                        Label(data.graceRemaining, systemImage: "timer")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.green)
                    } else if !data.totalFare.isEmpty {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(data.totalFare)
                                .font(.footnote.weight(.bold))
                                .foregroundStyle(.white)
                            if !data.waitFee.isEmpty {
                                Text(data.waitFee)
                                    .font(.caption2)
                                    .foregroundStyle(.orange)
                            }
                        }
                    }
                }
            }
            .padding(.vertical, 6)
            .activityBackgroundTint(Color.black.opacity(0.88))
            .activitySystemActionForegroundColor(Color.white)
            .widgetURL(URL(string: "heycabyrider://ride-status"))
        } dynamicIsland: { context in
            let data = LiveRidePayload.load(from: context)
            let title = data.title.isEmpty ? "HeyCaby" : data.title

            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "car.fill")
                        .foregroundStyle(.yellow)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    if !data.eta.isEmpty {
                        Text(data.eta)
                            .font(.caption.weight(.semibold))
                    } else if !data.graceRemaining.isEmpty {
                        Text(data.graceRemaining)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.green)
                    } else if !data.totalFare.isEmpty {
                        Text(data.totalFare)
                            .font(.caption.weight(.semibold))
                    } else {
                        Text("Live")
                            .font(.caption.weight(.semibold))
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(title)
                            .font(.subheadline.weight(.semibold))
                        if !data.subtitle.isEmpty {
                            Text(data.subtitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                        RideTimelineDots(currentStep: data.timelineStep)
                    }
                }
            } compactLeading: {
                Image(systemName: "car.fill")
            } compactTrailing: {
                if !data.eta.isEmpty {
                    Text(data.eta)
                } else if !data.graceRemaining.isEmpty {
                    Text(data.graceRemaining)
                } else {
                    Text("Hey")
                }
            } minimal: {
                Image(systemName: "car.fill")
            }
            .widgetURL(URL(string: "heycabyrider://ride-status"))
            .keylineTint(Color.yellow)
        }
    }
}

extension LiveActivitiesAppAttributes {
    fileprivate static var preview: LiveActivitiesAppAttributes {
        LiveActivitiesAppAttributes()
    }
}

extension LiveActivitiesAppAttributes.ContentState {
    fileprivate static var searching: LiveActivitiesAppAttributes.ContentState {
        LiveActivitiesAppAttributes.ContentState(appGroupId: kLiveActivityAppGroup)
    }
}

#Preview("Notification", as: .content, using: LiveActivitiesAppAttributes.preview) {
    HeyCabyWidgetsLiveActivity()
} contentStates: {
    LiveActivitiesAppAttributes.ContentState.searching
}
