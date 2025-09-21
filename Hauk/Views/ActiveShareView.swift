import SwiftUI
import CoreLocation

struct ActiveShareView: View {
    @EnvironmentObject var sharingManager: SharingManager
    @EnvironmentObject var locationManager: LocationManager
    @State private var showingAdoptDialog = false
    
    var body: some View {
        VStack(spacing: 16) {
            if let share = sharingManager.activeShares.first {
                VStack(spacing: 8) {
                    HStack {
                        Text("Sharing Location")
                            .font(.headline)
                            .foregroundColor(.green)
                        
                        Spacer()
                        
                        Text(share.shareMode.shortDescription)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.blue.opacity(0.2))
                            .cornerRadius(8)
                    }
                    
                    Text("Until \(share.expiryDate.formatted(date: .omitted, time: .shortened))")
                        .foregroundColor(.secondary)
                    
                    if let location = locationManager.location {
                        Text("Last update: \(location.timestamp.formatted(date: .omitted, time: .standard))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    if let nickname = share.nickname {
                        Text("Nickname: \(nickname)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    if let viewerId = share.viewerId {
                        Text("Share ID: \(viewerId)")
                            .font(.system(.body, design: .monospaced))
                            .padding(.vertical, 4)
                    }
                    
                    // Show group PIN for group hosts
                    if share.shareMode == .createGroup, let groupPin = share.groupPin {
                        VStack(spacing: 8) {
                            Text("GROUP PIN")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.secondary)
                            
                            Text(groupPin)
                                .font(.system(.title, design: .monospaced))
                                .fontWeight(.bold)
                                .foregroundColor(.blue)
                                .padding()
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(8)
                            
                            Text("Share this PIN with others to let them join your group")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                    
                    HStack(spacing: 12) {
                        ShareLinkView(url: share.shareUrl)
                        
                        // Show adopt button for group hosts
                        if share.shareMode == .createGroup {
                            Button(action: { showingAdoptDialog = true }) {
                                HStack {
                                    Image(systemName: "person.badge.plus")
                                    Text("Merge")
                                }
                                .foregroundColor(.white)
                                .padding()
                                .background(Color.green)
                                .cornerRadius(8)
                            }
                        }
                    }
                    .padding(.top)
                }
            }
        }
        .padding()
        .sheet(isPresented: $showingAdoptDialog) {
            AdoptShareView(isPresented: $showingAdoptDialog)
                .environmentObject(sharingManager)
        }
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