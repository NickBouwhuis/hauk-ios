import ActivityKit
import WidgetKit
import SwiftUI

struct LocationSharingLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: LocationSharingAttributes.self) { context in
            HStack(spacing: 12) {
                Image("AppLogo")
                    .resizable()
                    .frame(width: 36, height: 36)
                VStack(alignment: .leading) {
                    Text("Sharing location")
                        .font(.headline)
                    Text(context.state.expiryDate, style: .timer)
                        .font(.system(.body, design: .monospaced))
                }
                Spacer()
                Button("Stop") {
                    Task {
                        await SharingManager.shared.stopSharing()
                    }
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image("AppLogo")
                        .resizable()
                        .frame(width: 24, height: 24)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Button("Stop") {
                        Task {
                            await SharingManager.shared.stopSharing()
                        }
                    }
                    .buttonStyle(.bordered)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.state.expiryDate, style: .timer)
                        .monospacedDigit()
                }
            } compactLeading: {
                CountdownRingView(expiryDate: context.state.expiryDate,
                                  startDate: context.attributes.startDate)
                    .frame(width: 22, height: 22)
            } compactTrailing: {
                Image(systemName: "location.fill")
            } minimal: {
                CountdownRingView(expiryDate: context.state.expiryDate,
                                  startDate: context.attributes.startDate)
                    .frame(width: 22, height: 22)
            }
        }
    }
}

struct CountdownRingView: View {
    let expiryDate: Date
    let startDate: Date

    var body: some View {
        ProgressView(timerInterval: startDate...expiryDate, countsDown: true)
            .progressViewStyle(.circular)
    }
}

