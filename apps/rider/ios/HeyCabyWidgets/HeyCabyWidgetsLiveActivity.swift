import ActivityKit
import WidgetKit
import SwiftUI

struct HeyCabyWidgetsAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var title: String
        var subtitle: String
        var status: String
        var eta: String?
    }

    var rideId: String
}

struct HeyCabyWidgetsLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: HeyCabyWidgetsAttributes.self) { context in
            VStack(alignment: .leading, spacing: 8) {
                Text(context.state.title)
                    .font(.headline)
                Text(context.state.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                HStack {
                    Image(systemName: "car.fill")
                    Text(context.state.status)
                        .font(.footnote.weight(.semibold))
                    Spacer()
                    if let eta = context.state.eta, !eta.isEmpty {
                        Text(eta)
                            .font(.footnote.weight(.semibold))
                    }
                }
            }
            .padding(.vertical, 4)
            .activityBackgroundTint(Color.black.opacity(0.85))
            .activitySystemActionForegroundColor(Color.white)
            .widgetURL(URL(string: "heycabyrider://ride-status"))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "car.fill")
                        .foregroundStyle(.yellow)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    if let eta = context.state.eta, !eta.isEmpty {
                        Text(eta)
                            .font(.caption.weight(.semibold))
                    } else {
                        Text("Live")
                            .font(.caption.weight(.semibold))
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(context.state.title)
                            .font(.subheadline.weight(.semibold))
                        Text(context.state.subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } compactLeading: {
                Image(systemName: "car.fill")
            } compactTrailing: {
                if let eta = context.state.eta, !eta.isEmpty {
                    Text(eta)
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

extension HeyCabyWidgetsAttributes {
    fileprivate static var preview: HeyCabyWidgetsAttributes {
        HeyCabyWidgetsAttributes(rideId: "preview")
    }
}

extension HeyCabyWidgetsAttributes.ContentState {
    fileprivate static var searching: HeyCabyWidgetsAttributes.ContentState {
        HeyCabyWidgetsAttributes.ContentState(
            title: "Finding your Caby",
            subtitle: "Still matching nearby drivers",
            status: "Searching",
            eta: "10m"
        )
    }
}

#Preview("Notification", as: .content, using: HeyCabyWidgetsAttributes.preview) {
    HeyCabyWidgetsLiveActivity()
} contentStates: {
    HeyCabyWidgetsAttributes.ContentState.searching
}
