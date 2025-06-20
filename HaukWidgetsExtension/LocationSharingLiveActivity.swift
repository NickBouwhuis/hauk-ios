import ActivityKit
import WidgetKit
import SwiftUI

struct LocationSharingLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: LocationSharingAttributes.self) { context in
            VStack(alignment: .leading) {
                Text("Sharing location")
                    .font(.headline)
                if let location = context.state.lastLocation {
                    Text(location)
                        .font(.caption)
                }
            }
            .padding()
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text("Hauk")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    if let location = context.state.lastLocation {
                        Text(location)
                    }
                }
            } compactLeading: {
                Image(systemName: "location")
            } compactTrailing: {
                Text("Hauk")
            } minimal: {
                Image(systemName: "location")
            }
        }
    }
}

@main
struct HaukWidgets: WidgetBundle {
    var body: some Widget {
        LocationSharingLiveActivity()
    }
}
