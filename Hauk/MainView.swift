import SwiftUI
import CoreLocation

struct CardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
}

struct MainView: View {
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var sharingManager: SharingManager
    @State private var showingError = false
    @State private var sharingTask: Task<Void, Never>?
    @AppStorage("hideLogo") private var hideLogo = false
    @State private var showingCopiedAlert = false
    @State private var showingShareDialog = false
    
    // Duration selection state
    @State private var duration: Double = 1
    @State private var unit: TimeUnit = .hours
    
    enum TimeUnit: String, CaseIterable {
        case minutes = "Minutes"
        case hours = "Hours"
        case days = "Days"
        
        var multiplier: TimeInterval {
            switch self {
            case .minutes: return 60
            case .hours: return 3600
            case .days: return 86400
            }
        }
    }
    
    // Add this helper view for the status indicator
    struct StatusIndicatorView: View {
        let isSharing: Bool
        let authStatus: CLAuthorizationStatus
        
        private var statusColor: Color {
            if isSharing {
                return .green
            }
            switch authStatus {
            case .authorizedAlways:
                return .blue
            case .denied, .restricted:
                return .red
            default:
                return .orange
            }
        }
        
        private var statusText: String {
            if isSharing {
                return "Location sharing is active"
            }
            switch authStatus {
            case .authorizedAlways:
                return "Ready to share location"
            case .authorizedWhenInUse:
                return "Background access required"
            case .denied:
                return "Location access denied"
            case .restricted:
                return "Location access restricted"
            case .notDetermined:
                return "Location permission needed"
            @unknown default:
                return "Unknown status"
            }
        }
        
        var body: some View {
            HStack(spacing: 12) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
                    .shadow(color: statusColor.opacity(0.5), radius: 4)
                
                Text(statusText)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
        }
    }
    
    // Add this state for navigation
    @State private var showingSettings = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Logo Section
                if !hideLogo {
                    Image("AppLogo")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: 100)
                        .padding(.top, 12)
                }
                
                Text("Open-source location sharing")
                    .font(.headline)
                    .padding(.bottom, 8)
                
                // Location Permission Warning
                if locationManager.authorizationStatus != .authorizedAlways {
                    VStack(spacing: 8) {
                        Text(locationManager.authorizationStatus == .denied ? 
                            "Location Access Denied" : 
                            "Background Location Access Required")
                            .font(.headline)
                            .foregroundColor(.red)
                        
                        Text("Hauk needs location access set to 'Always' to share your location in the background.")
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                        
                        Button("Open Settings") {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        }
                        .foregroundColor(.blue)
                        .padding(.top, 4)
                    }
                    .modifier(CardStyle())
                }
                
                if !sharingManager.isSharing {
                    // Duration Selection when not sharing
                    VStack(alignment: .center, spacing: 16) {
                        Text("Share Duration")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                        
                        HStack(spacing: 12) {
                            TextField("Duration", value: $duration, format: .number)
                                .keyboardType(.decimalPad)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .frame(width: 100)
                                .frame(minHeight: 44)
                                .onChange(of: duration) { oldValue, newValue in
                                    duration = min(max(newValue, 1), 999999)
                                }
                                .multilineTextAlignment(.center)
                            
                            Picker("Unit", selection: $unit) {
                                ForEach(TimeUnit.allCases, id: \.self) { unit in
                                    Text(unit.rawValue).tag(unit)
                                }
                            }
                            .pickerStyle(.menu)
                            .frame(minHeight: 44)
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.horizontal)
                    }
                    .padding(.vertical, 8)
                } else {
                    // Show sharing info when active
                    VStack(spacing: 16) {
                        if let share = sharingManager.activeShares.first {
                            VStack(spacing: 8) {
                                Text("Share URL")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                
                                Text(share.shareUrl.absoluteString)
                                    .font(.system(.body, design: .monospaced))
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal)
                                
                                Button {
                                    let shareSheet = UIActivityViewController(
                                        activityItems: [share.shareUrl.absoluteString],
                                        applicationActivities: nil
                                    )
                                    
                                    if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                                       let window = windowScene.windows.first,
                                       let rootViewController = window.rootViewController {
                                        shareSheet.popoverPresentationController?.sourceView = rootViewController.view
                                        rootViewController.present(shareSheet, animated: true)
                                    }
                                } label: {
                                    HStack {
                                        Image(systemName: "square.and.arrow.up")
                                        Text("Share Link")
                                    }
                                    .foregroundColor(.blue)
                                }
                                
                                if let viewerId = share.viewerId {
                                    Text("Share ID: \(viewerId)")
                                        .font(.system(.body, design: .monospaced))
                                        .padding(.top, 4)
                                }
                                
                                if let location = locationManager.location {
                                    Text("Last update: \(location.timestamp.formatted(date: .omitted, time: .standard))")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .padding(.top, 4)
                                }
                            }
                            .modifier(CardStyle())
                        }
                    }
                    .padding()
                }
                
                // Status Indicator (always show)
                StatusIndicatorView(
                    isSharing: sharingManager.isSharing,
                    authStatus: locationManager.authorizationStatus
                )
                .padding(.horizontal)
                
                Spacer()
                
                // Action Button
                Button {
                    if sharingManager.isSharing {
                        sharingTask?.cancel()
                        sharingTask = Task {
                            await sharingManager.stopSharing()
                        }
                    } else {
                        sharingTask?.cancel()
                        sharingTask = Task {
                            await sharingManager.startSharing(duration: duration * unit.multiplier)
                            await MainActor.run {
                                if !sharingManager.activeShares.isEmpty {
                                    showingShareDialog = true
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: sharingManager.isSharing ? "location.slash.fill" : "location.fill")
                        Text(sharingManager.isSharing ? "Stop Sharing" : "Start Sharing")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(sharingManager.isSharing ? Color.red : Color.accentColor)
                    .cornerRadius(10)
                }
                .padding(.horizontal)
                .padding(.bottom, 20)
                .disabled(locationManager.authorizationStatus != .authorizedAlways)
            }
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK", role: .cancel) {
                if let error = sharingManager.error as? SharingManager.SharingError,
                   case .noServerConfigured = error {
                    showingSettings = true
                }
            }
        } message: {
            Text(sharingManager.error?.localizedDescription ?? "An unknown error occurred")
        }
        .onReceive(sharingManager.$error) { error in
            if let error = error {
                if error is CancellationError {
                    return
                }
                showingError = true
            }
        }
        .onDisappear {
            sharingTask?.cancel()
        }
        .alert("Location Sharing Started", isPresented: $showingShareDialog) {
            if let share = sharingManager.activeShares.first {
                Button("Share") {
                    let shareSheet = UIActivityViewController(
                        activityItems: [share.shareUrl.absoluteString],
                        applicationActivities: nil
                    )
                    
                    if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                       let window = windowScene.windows.first,
                       let rootViewController = window.rootViewController {
                        shareSheet.popoverPresentationController?.sourceView = rootViewController.view
                        rootViewController.present(shareSheet, animated: true)
                    }
                }
            }
            Button("OK", role: .cancel) { }
        } message: {
            if let share = sharingManager.activeShares.first {
                Text("Your location is now being shared.\n\nShare URL: \(share.shareUrl.absoluteString)")
            } else {
                Text("") // Empty message if no active share
            }
        }
        .navigationDestination(isPresented: $showingSettings) {
            SettingsView()
        }
    }
} 
