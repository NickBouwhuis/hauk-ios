//
//  HaukWidgetLiveActivity.swift
//  HaukWidget
//
//  Created by Nick Bouwhuis on 05/12/2025.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct HaukWidgetAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct HaukWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: HaukWidgetAttributes.self) { context in
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

extension HaukWidgetAttributes {
    fileprivate static var preview: HaukWidgetAttributes {
        HaukWidgetAttributes(name: "World")
    }
}

extension HaukWidgetAttributes.ContentState {
    fileprivate static var smiley: HaukWidgetAttributes.ContentState {
        HaukWidgetAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: HaukWidgetAttributes.ContentState {
         HaukWidgetAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: HaukWidgetAttributes.preview) {
   HaukWidgetLiveActivity()
} contentStates: {
    HaukWidgetAttributes.ContentState.smiley
    HaukWidgetAttributes.ContentState.starEyes
}
