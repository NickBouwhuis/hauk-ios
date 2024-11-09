import SwiftUI
import CoreLocation

struct ActiveShareView: View {
    @EnvironmentObject var sharingManager: SharingManager
    @EnvironmentObject var locationManager: LocationManager
    
    var body: some View {
        VStack(spacing: 16) {
            if let share = sharingManager.activeShares.first {
                VStack(spacing: 8) {
                    Text("Sharing Location")
                        .font(.headline)
                        .foregroundColor(.green)
                    
                    Text("Until \(share.expiryDate.formatted(date: .omitted, time: .shortened))")
                        .foregroundColor(.secondary)
                    
                    if let location = locationManager.location {
                        Text("Last update: \(location.timestamp.formatted(date: .omitted, time: .standard))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    if let viewerId = share.viewerId {
                        Text("Share ID: \(viewerId)")
                            .font(.system(.body, design: .monospaced))
                            .padding(.vertical, 4)
                    }
                    
                    ShareLinkView(url: share.shareUrl)
                        .padding(.top)
                }
            }
        }
        .padding()
    }
}

struct ShareLinkView: View {
    let url: URL
    @State private var showingCopiedAlert = false
    
    var body: some View {
        Button {
            UIPasteboard.general.url = url
            showingCopiedAlert = true
        } label: {
            HStack {
                Image(systemName: "link")
                Text("Copy Share Link")
            }
            .foregroundColor(.white)
            .padding()
            .background(Color.blue)
            .cornerRadius(8)
        }
        .alert("Link Copied", isPresented: $showingCopiedAlert) {
            Button("OK", role: .cancel) { }
        }
    }
} 