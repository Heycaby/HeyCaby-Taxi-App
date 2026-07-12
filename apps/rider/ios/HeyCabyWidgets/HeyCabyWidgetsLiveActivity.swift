import ActivityKit
import WidgetKit
import SwiftUI

private let kLiveActivityAppGroup = "group.nl.heycaby.rider.app.widgets"

// HeyCaby Green — lock screen palette aligned with rider premium theme.
private enum HeyCabyLivePalette {
    static let forest = Color(red: 0.10, green: 0.36, blue: 0.27)
    static let forestDeep = Color(red: 0.05, green: 0.12, blue: 0.09)
    static let accent = Color(red: 0.0, green: 0.65, blue: 0.32)
    static let accentBright = Color(red: 0.20, green: 0.83, blue: 0.60)
    static let amber = Color(red: 1.0, green: 0.78, blue: 0.36)
    static let amberSoft = Color(red: 1.0, green: 0.86, blue: 0.55)
    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.78)
    static let textMuted = Color.white.opacity(0.52)
    static let track = Color.white.opacity(0.14)
    static let glass = Color.white.opacity(0.08)
    static let glassStroke = Color.white.opacity(0.14)
}

/// Lock-screen Live Activity insets — keep the banner short (fits above flashlight/camera).
private enum LiveActivityLayout {
    static let lockScreenHorizontalInset: CGFloat = 18
    static let lockScreenTopInset: CGFloat = 12
    static let lockScreenBottomInset: CGFloat = 10
    static let lockScreenSpacing: CGFloat = 8
    static let islandHorizontalInset: CGFloat = 14
    static let islandTopInset: CGFloat = 8
    static let islandBottomInset: CGFloat = 10
    static let islandSpacing: CGFloat = 8
    /// Expanded timeline (Dynamic Island long-press) — room for next-action card.
    static let expandedHorizontalInset: CGFloat = 16
    static let expandedTopInset: CGFloat = 12
    static let expandedBottomInset: CGFloat = 14
    static let expandedSpacing: CGFloat = 10
}

/// Must match the `live_activities` Flutter plugin attribute name exactly.
struct LiveActivitiesAppAttributes: ActivityAttributes, Identifiable {
    public typealias LiveDeliveryData = ContentState

    public struct ContentState: Codable, Hashable {
        var appGroupId: String
        var phase: String?
        var title: String?
        var subtitle: String?
        var status: String?
        var nextAction: String?
        var eta: String?
        var progressPercent: Int?
        var graceRemaining: String?
        var graceEndsAtEpoch: Int?
        var waitFee: String?
        var heroMetric: String?
        var compactTrailing: String?
        var waitPhase: String?
        var rideVersion: Int?
    }

    var id = UUID()
}

extension LiveActivitiesAppAttributes {
    func prefixedKey(_ key: String) -> String {
        return "\(id)_\(key)"
    }
}

private enum LiveRidePhase: String {
    case searching
    case driverFound = "driver_found"
    case onTheWay = "on_the_way"
    case nearby
    case outsideFree = "outside_free"
    case outsidePaid = "outside_paid"
    case onTrip = "on_trip"
    case payment
    case completed

    init(raw: String) {
        self = LiveRidePhase(rawValue: raw) ?? .searching
    }

    var icon: String {
        switch self {
        case .searching: return "magnifyingglass"
        case .driverFound: return "checkmark.circle.fill"
        case .onTheWay: return "car.fill"
        case .nearby: return "location.fill"
        case .outsideFree: return "figure.wave"
        case .outsidePaid: return "timer"
        case .onTrip: return "arrow.triangle.turn.up.right.diamond.fill"
        case .payment: return "creditcard.fill"
        case .completed: return "checkmark.seal.fill"
        }
    }
}

private enum LiveWaitPhase: String {
    case none, free, paid

    init(raw: String) {
        self = LiveWaitPhase(rawValue: raw) ?? .none
    }
}

private struct LiveRidePayload {
    let phase: LiveRidePhase
    let title: String
    let subtitle: String
    let status: String
    let nextAction: String
    let eta: String
    let progressPercent: Int
    let graceRemaining: String
    let waitFee: String
    let heroMetric: String
    let compactTrailing: String
    let waitPhase: LiveWaitPhase
    let graceEndsAt: Date?

    static func load(from context: ActivityViewContext<LiveActivitiesAppAttributes>) -> LiveRidePayload {
        let defaults = UserDefaults(suiteName: kLiveActivityAppGroup)!
        func str(_ key: String) -> String {
            defaults.string(forKey: context.attributes.prefixedKey(key)) ?? ""
        }
        func remoteOrLocal(_ remote: String?, _ key: String) -> String {
            guard let remote, !remote.isEmpty else { return str(key) }
            return remote
        }
        let state = context.state
        let percentRaw = state.progressPercent ?? Int(str("progressPercent")) ?? 0
        let timelineStep = min(max(Int(str("timelineStep")) ?? 0, 0), 4)
        let phaseRaw = remoteOrLocal(state.phase, "phase")
        let inferredPercent = percentRaw > 0 ? percentRaw : legacyPercent(for: timelineStep)
        return LiveRidePayload(
            phase: phaseRaw.isEmpty ? legacyPhase(for: timelineStep) : LiveRidePhase(raw: phaseRaw),
            title: remoteOrLocal(state.title, "title"),
            subtitle: remoteOrLocal(state.subtitle, "subtitle"),
            status: remoteOrLocal(state.status, "status"),
            nextAction: remoteOrLocal(state.nextAction, "nextAction"),
            eta: remoteOrLocal(state.eta, "eta"),
            progressPercent: min(max(inferredPercent, 0), 100),
            graceRemaining: remoteOrLocal(state.graceRemaining, "graceRemaining"),
            waitFee: remoteOrLocal(state.waitFee, "waitFee"),
            heroMetric: remoteOrLocal(state.heroMetric, "heroMetric"),
            compactTrailing: remoteOrLocal(state.compactTrailing, "compactTrailing"),
            waitPhase: LiveWaitPhase(raw: remoteOrLocal(state.waitPhase, "waitPhase")),
            graceEndsAt: state.graceEndsAtEpoch.map { Date(timeIntervalSince1970: TimeInterval($0)) }
        )
    }

    private static func legacyPercent(for step: Int) -> Int {
        switch step {
        case 0: return 15
        case 1: return 45
        case 2: return 70
        case 3: return 85
        default: return 100
        }
    }

    private static func legacyPhase(for step: Int) -> LiveRidePhase {
        switch step {
        case 0: return .searching
        case 1: return .onTheWay
        case 2: return .outsideFree
        case 3: return .onTrip
        default: return .completed
        }
    }

    var headline: String {
        title.isEmpty ? "Your ride" : title
    }

    var detailLine: String {
        if !subtitle.isEmpty { return subtitle }
        if !status.isEmpty { return status }
        return "Tap to open HeyCaby"
    }

    var trailingPillText: String {
        if !eta.isEmpty { return eta }
        if waitPhase == .free, !graceRemaining.isEmpty { return graceRemaining }
        if waitPhase == .paid, !waitFee.isEmpty { return waitFee }
        if !heroMetric.isEmpty { return heroMetric }
        return ""
    }

    var lockScreenStatusLine: String {
        if !status.isEmpty { return status }
        if !nextAction.isEmpty { return nextAction }
        return ""
    }

    var lockScreenSubtitle: String {
        if !subtitle.isEmpty { return subtitle }
        return ""
    }

    var nextActionLine: String {
        if !nextAction.isEmpty { return nextAction }
        if !status.isEmpty { return status }
        return "Open HeyCaby for details"
    }

    // MARK: - Xcode previews (no App Group required)

    static let previewSearching = LiveRidePayload(
        phase: .searching,
        title: "Looking for a driver",
        subtitle: "Damrak → Schiphol",
        status: "5 drivers notified",
        nextAction: "We're notifying nearby drivers.",
        eta: "",
        progressPercent: 15,
        graceRemaining: "",
        waitFee: "",
        heroMetric: "1 min",
        compactTrailing: "5",
        waitPhase: .none,
        graceEndsAt: nil
    )

    static let previewOnTheWay = LiveRidePayload(
        phase: .onTheWay,
        title: "Pickup in 6 min",
        subtitle: "TX-22-NL · Black Tesla",
        status: "Ahmed is heading to you",
        nextAction: "Ahmed is heading to you.",
        eta: "6 min",
        progressPercent: 45,
        graceRemaining: "",
        waitFee: "",
        heroMetric: "6 min",
        compactTrailing: "6 min",
        waitPhase: .none,
        graceEndsAt: nil
    )

    static let previewFreeWait = LiveRidePayload(
        phase: .outsideFree,
        title: "Driver outside",
        subtitle: "TX-22-NL · Black Tesla",
        status: "Free wait · 1:42 left",
        nextAction: "Look for TX-22-NL · Black Tesla.",
        eta: "",
        progressPercent: 70,
        graceRemaining: "1:42",
        waitFee: "",
        heroMetric: "1:42",
        compactTrailing: "1:42 free",
        waitPhase: .free,
        graceEndsAt: Date().addingTimeInterval(102)
    )

    static let previewPaidWait = LiveRidePayload(
        phase: .outsidePaid,
        title: "Waiting fee active",
        subtitle: "TX-22-NL · Black Tesla",
        status: "€0.80 added",
        nextAction: "Please join your driver at the pickup point.",
        eta: "",
        progressPercent: 70,
        graceRemaining: "",
        waitFee: "€0.80 added",
        heroMetric: "€0.80 added",
        compactTrailing: "€0.80",
        waitPhase: .paid,
        graceEndsAt: nil
    )

    static let previewOnTrip = LiveRidePayload(
        phase: .onTrip,
        title: "On your way",
        subtitle: "Schiphol Terminal 1",
        status: "Arriving in 18 min",
        nextAction: "Relax — we'll keep you updated.",
        eta: "18 min",
        progressPercent: 85,
        graceRemaining: "",
        waitFee: "",
        heroMetric: "18 min",
        compactTrailing: "18 min",
        waitPhase: .none,
        graceEndsAt: nil
    )
}

private struct HeyCabyBrandMark: View {
    var compact: Bool = false

    var body: some View {
        HStack(spacing: compact ? 6 : 8) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [HeyCabyLivePalette.accent, HeyCabyLivePalette.forest],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: compact ? 22 : 28, height: compact ? 22 : 28)
                Text("H")
                    .font(.system(size: compact ? 11 : 14, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
            }
            if !compact {
                Text("HeyCaby")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(HeyCabyLivePalette.textSecondary)
            }
        }
    }
}

private struct EightSegmentProgress: View {
    let percent: Int

    private let segmentCount = 8

    private var filledSegments: Int {
        min(segmentCount, max(0, Int((Double(percent) / 100.0 * Double(segmentCount)).rounded(.up))))
    }

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<segmentCount, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                    .fill(segmentFill(for: index))
                    .frame(height: 5)
            }
        }
        .accessibilityLabel("Ride progress \(percent) percent")
    }

    private func segmentFill(for index: Int) -> some ShapeStyle {
        if index < filledSegments {
            return AnyShapeStyle(
                LinearGradient(
                    colors: [HeyCabyLivePalette.accentBright, HeyCabyLivePalette.accent],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
        }
        return AnyShapeStyle(HeyCabyLivePalette.track)
    }
}

private struct LiveMetricPill: View {
    let text: String
    var icon: String = "clock.fill"
    var tint: Color = HeyCabyLivePalette.textPrimary
    var fill: Color = Color.white.opacity(0.12)

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .bold))
            Text(text)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .monospacedDigit()
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(fill)
        .overlay(
            Capsule()
                .strokeBorder(HeyCabyLivePalette.glassStroke, lineWidth: 0.5)
        )
        .clipShape(Capsule())
    }
}

private struct HeroMetricView: View {
    let data: LiveRidePayload

    var body: some View {
        if data.waitPhase == .free,
           data.graceEndsAt != nil || !data.graceRemaining.isEmpty {
            VStack(alignment: .leading, spacing: 2) {
                Text("FREE WAIT")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(HeyCabyLivePalette.accentBright.opacity(0.9))
                    .tracking(0.6)
                if let end = data.graceEndsAt, end > Date() {
                    Text(timerInterval: Date()...end, countsDown: true)
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(HeyCabyLivePalette.textPrimary)
                } else {
                    Text(data.graceRemaining)
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(HeyCabyLivePalette.textPrimary)
                }
            }
        } else if data.waitPhase == .paid, !data.waitFee.isEmpty {
            VStack(alignment: .leading, spacing: 2) {
                Text("WAITING FEE")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(HeyCabyLivePalette.amberSoft)
                    .tracking(0.6)
                Text(data.waitFee.replacingOccurrences(of: " added", with: ""))
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(HeyCabyLivePalette.amber)
            }
        } else if !data.eta.isEmpty {
            Text(data.eta)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(HeyCabyLivePalette.textPrimary)
        }
    }
}

private struct NextActionRow: View {
    let text: String
    let phase: LiveRidePhase

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: phase.icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(HeyCabyLivePalette.accentBright)
                .frame(width: 26, height: 26)
                .background(HeyCabyLivePalette.accent.opacity(0.22))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text("Next")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(HeyCabyLivePalette.textMuted)
                    .textCase(.uppercase)
                    .tracking(0.4)
                Text(text)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(HeyCabyLivePalette.textPrimary.opacity(0.94))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(HeyCabyLivePalette.glass)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(HeyCabyLivePalette.glassStroke, lineWidth: 0.5)
        )
    }
}

private struct LockScreenRideActivityView: View {
    let data: LiveRidePayload

    var body: some View {
        VStack(alignment: .leading, spacing: LiveActivityLayout.lockScreenSpacing) {
            HStack(alignment: .center) {
                HeyCabyBrandMark(compact: false)
                Spacer(minLength: 8)
                if !data.trailingPillText.isEmpty {
                    LockScreenMetricPill(data: data)
                }
            }

            Text(data.headline)
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(HeyCabyLivePalette.textPrimary)
                .lineLimit(2)
                .minimumScaleFactor(0.9)

            if !data.lockScreenSubtitle.isEmpty {
                Text(data.lockScreenSubtitle)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(HeyCabyLivePalette.textSecondary)
                    .lineLimit(1)
            }

            if !data.lockScreenStatusLine.isEmpty,
               data.lockScreenStatusLine != data.lockScreenSubtitle {
                Text(data.lockScreenStatusLine)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(statusColor)
                    .lineLimit(1)
            }

            EightSegmentProgress(percent: data.progressPercent)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, LiveActivityLayout.lockScreenHorizontalInset)
        .padding(.top, LiveActivityLayout.lockScreenTopInset)
        .padding(.bottom, LiveActivityLayout.lockScreenBottomInset)
    }

    private var statusColor: Color {
        data.waitPhase == .paid ? HeyCabyLivePalette.amberSoft : HeyCabyLivePalette.textMuted
    }
}

private struct LockScreenMetricPill: View {
    let data: LiveRidePayload

    var body: some View {
        LiveMetricPill(
            text: data.trailingPillText,
            icon: pillIcon,
            tint: pillTint,
            fill: pillFill
        )
    }

    private var pillIcon: String {
        switch data.waitPhase {
        case .free: return "timer"
        case .paid: return "eurosign.circle.fill"
        case .none: return data.eta.isEmpty ? "ellipsis" : "clock.fill"
        }
    }

    private var pillTint: Color {
        switch data.waitPhase {
        case .free: return HeyCabyLivePalette.accentBright
        case .paid: return HeyCabyLivePalette.amber
        case .none: return HeyCabyLivePalette.textPrimary
        }
    }

    private var pillFill: Color {
        switch data.waitPhase {
        case .paid: return HeyCabyLivePalette.amber.opacity(0.18)
        default: return Color.white.opacity(0.12)
        }
    }
}

/// Dynamic Island expanded — more room than lock screen; may include next-action card.
private struct ExpandedRideActivityView: View {
    let data: LiveRidePayload

    var body: some View {
        VStack(alignment: .leading, spacing: LiveActivityLayout.expandedSpacing) {
            HStack(alignment: .center) {
                HeyCabyBrandMark(compact: true)
                Spacer(minLength: 8)
                if !data.trailingPillText.isEmpty {
                    LockScreenMetricPill(data: data)
                }
            }

            if data.waitPhase != .none || !data.eta.isEmpty {
                HeroMetricView(data: data)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(data.headline)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(HeyCabyLivePalette.textPrimary)
                    .lineLimit(2)
                if !data.lockScreenSubtitle.isEmpty {
                    Text(data.lockScreenSubtitle)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(HeyCabyLivePalette.textSecondary)
                        .lineLimit(2)
                }
            }

            EightSegmentProgress(percent: data.progressPercent)
                .padding(.vertical, 2)

            NextActionRow(text: data.nextActionLine, phase: data.phase)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, LiveActivityLayout.expandedHorizontalInset)
        .padding(.top, LiveActivityLayout.expandedTopInset)
        .padding(.bottom, LiveActivityLayout.expandedBottomInset)
    }
}

struct HeyCabyWidgetsLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: LiveActivitiesAppAttributes.self) { context in
            let data = LiveRidePayload.load(from: context)

            LockScreenRideActivityView(data: data)
                .activityBackgroundTint(HeyCabyLivePalette.forestDeep)
                .activitySystemActionForegroundColor(HeyCabyLivePalette.textPrimary)
                .widgetURL(URL(string: "heycabyrider://ride-status"))
        } dynamicIsland: { context in
            let data = LiveRidePayload.load(from: context)

            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HeyCabyBrandMark(compact: true)
                        .padding(.leading, LiveActivityLayout.islandHorizontalInset)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    if !data.trailingPillText.isEmpty {
                        LiveMetricPill(text: data.trailingPillText, icon: data.phase.icon)
                            .padding(.trailing, LiveActivityLayout.islandHorizontalInset)
                    }
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(data.headline)
                        .font(.caption.weight(.bold))
                        .lineLimit(1)
                        .padding(.horizontal, LiveActivityLayout.islandHorizontalInset)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    ExpandedRideActivityView(data: data)
                }
            } compactLeading: {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [HeyCabyLivePalette.accent, HeyCabyLivePalette.forest],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 22, height: 22)
                    Image(systemName: data.phase.icon)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                }
            } compactTrailing: {
                Text(compactTrailingText(for: data))
                    .font(.caption2.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(
                        data.waitPhase == .paid
                            ? HeyCabyLivePalette.amber
                            : HeyCabyLivePalette.accentBright
                    )
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            } minimal: {
                Image(systemName: data.phase.icon)
                    .foregroundStyle(HeyCabyLivePalette.accentBright)
            }
            .widgetURL(URL(string: "heycabyrider://ride-status"))
            .keylineTint(HeyCabyLivePalette.accentBright)
        }
    }

    private func compactTrailingText(for data: LiveRidePayload) -> String {
        if !data.compactTrailing.isEmpty { return data.compactTrailing }
        if !data.eta.isEmpty { return data.eta }
        if data.waitPhase == .free, !data.graceRemaining.isEmpty { return data.graceRemaining }
        return "•••"
    }
}

// MARK: - Design previews

#Preview("Lock screen — searching") {
    LockScreenRideActivityView(data: .previewSearching)
        .activityBackgroundTint(HeyCabyLivePalette.forestDeep)
        .background(HeyCabyLivePalette.forestDeep)
}

#Preview("Lock screen — on the way") {
    LockScreenRideActivityView(data: .previewOnTheWay)
        .activityBackgroundTint(HeyCabyLivePalette.forestDeep)
        .background(HeyCabyLivePalette.forestDeep)
}

#Preview("Lock screen — free wait") {
    LockScreenRideActivityView(data: .previewFreeWait)
        .activityBackgroundTint(HeyCabyLivePalette.forestDeep)
        .background(HeyCabyLivePalette.forestDeep)
}

#Preview("Expanded — free wait") {
    ExpandedRideActivityView(data: .previewFreeWait)
        .activityBackgroundTint(HeyCabyLivePalette.forestDeep)
        .background(HeyCabyLivePalette.forestDeep)
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

#Preview("ActivityKit shell", as: .content, using: LiveActivitiesAppAttributes.preview) {
    HeyCabyWidgetsLiveActivity()
} contentStates: {
    LiveActivitiesAppAttributes.ContentState.searching
}
