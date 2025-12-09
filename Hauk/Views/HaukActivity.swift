import ActivityKit
import WidgetKit
import SwiftUI

@available(iOS 16.1, *)
struct HaukActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: LocationSharingAttributes.self) { context in
            // Lock Screen/Banner UI
            VStack {
                HStack(spacing: 20) {
                    // Logo on the left
                    Image("AppLogo")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 60, height: 60)
                        
                    VStack(alignment: .leading) {
                        Text("Sharing Location")
                            .font(.headline)
                            .foregroundColor(.white)
                        if let location = context.state.lastLocation {
                            Text(location)
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                    
                    Spacer()
                    
                    // Big Timer on the right
                    Text(timerInterval: Date()...context.state.expiryDate, countsDown: true)
                        .font(.system(size: 32, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.trailing)
                }
                .padding()
                .environment(\.colorScheme, .dark)
            }
            .activityBackgroundTint(Color.black)
            .activitySystemActionForegroundColor(Color.white)
            
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI
                DynamicIslandExpandedRegion(.leading) {
                    Image("DynamicIslandLogo")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 44, height: 44)
                        .environment(\.colorScheme, .dark)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(timerInterval: Date()...context.state.expiryDate, countsDown: true)
                        .multilineTextAlignment(.trailing)
                        .monospacedDigit()
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text("Sharing Active")
                        .font(.headline)
                        .foregroundColor(.white)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    if let location = context.state.lastLocation {
                        HStack(spacing: 4) {
                            Image(systemName: "location.fill")
                                .font(.caption2)
                                .foregroundColor(.red)
                            Text(location)
                                .font(.caption2)
                                .foregroundColor(.gray)
                        }
                    }
                }
            } compactLeading: {
                Image("DynamicIslandLogo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 20, height: 20)
                    .environment(\.colorScheme, .dark)
            } compactTrailing: {
                Text(timerInterval: Date()...context.state.expiryDate, countsDown: true)
                    .monospacedDigit()
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: 50)
            } minimal: {
                Image("DynamicIslandLogo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .padding(2)
                    .environment(\.colorScheme, .dark)
            }
            .widgetURL(URL(string: context.attributes.shareUrl))
        }
    }
}
