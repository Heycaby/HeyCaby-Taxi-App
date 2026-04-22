//
//  HeyCabyWidgetsLiveActivity.swift
//  HeyCabyWidgets
//
//  Created by Ai Guy on 05/04/2026.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct HeyCabyWidgetsAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct HeyCabyWidgetsLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: HeyCabyWidgetsAttributes.self) { context in
            // Lock screen/banner UI goes here
            VStack {
                Text("Hello \(context.state.emoji)")
            }
            .activityBackgroundTint(Color.cyan)
            .activitySystemActionForegroundColor(Color.black)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI goes here.  Compose the expanded UI through
                // various regions, like leading/trailing/center/bottom
                DynamicIslandExpandedRegion(.leading) {
                    Text("Leading")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("Trailing")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Bottom \(context.state.emoji)")
                    // more content
                }
            } compactLeading: {
                Text("L")
            } compactTrailing: {
                Text("T \(context.state.emoji)")
            } minimal: {
                Text(context.state.emoji)
            }
            .widgetURL(URL(string: "http://www.apple.com"))
            .keylineTint(Color.red)
        }
    }
}

extension HeyCabyWidgetsAttributes {
    fileprivate static var preview: HeyCabyWidgetsAttributes {
        HeyCabyWidgetsAttributes(name: "World")
    }
}

extension HeyCabyWidgetsAttributes.ContentState {
    fileprivate static var smiley: HeyCabyWidgetsAttributes.ContentState {
        HeyCabyWidgetsAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: HeyCabyWidgetsAttributes.ContentState {
         HeyCabyWidgetsAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: HeyCabyWidgetsAttributes.preview) {
   HeyCabyWidgetsLiveActivity()
} contentStates: {
    HeyCabyWidgetsAttributes.ContentState.smiley
    HeyCabyWidgetsAttributes.ContentState.starEyes
}
