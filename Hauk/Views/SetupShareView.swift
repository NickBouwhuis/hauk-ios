import SwiftUI
import CoreLocation

struct SetupShareView: View {
    @EnvironmentObject var locationManager: LocationManager
    
    var body: some View {
        VStack(spacing: 16) {
            LocationStatusView(status: locationManager.authorizationStatus)
            
            if locationManager.authorizationStatus == .denied {
                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    Text("Open Settings")
                        .foregroundColor(.blue)
                }
            } else if locationManager.authorizationStatus == .notDetermined {
                Button {
                    locationManager.requestAuthorization()
                } label: {
                    Text("Grant Location Access")
                        .foregroundColor(.blue)
                }
            }
            
            Text("Tap 'Start Sharing' to begin sharing your location")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding()
        }
    }
}

struct LocationStatusView: View {
    let status: CLAuthorizationStatus
    
    var body: some View {
        HStack {
            Image(systemName: statusIcon)
                .foregroundColor(statusColor)
            Text(statusText)
                .font(.headline)
        }
    }
    
    private var statusIcon: String {
        switch status {
        case .authorizedAlways: return "checkmark.circle.fill"
        case .authorizedWhenInUse: return "checkmark.circle"
        case .denied, .restricted: return "xmark.circle.fill"
        case .notDetermined: return "questionmark.circle.fill"
        @unknown default: return "exclamationmark.circle.fill"
        }
    }
    
    private var statusColor: Color {
        switch status {
        case .authorizedAlways, .authorizedWhenInUse: return .green
        case .denied, .restricted: return .red
        case .notDetermined: return .orange
        @unknown default: return .gray
        }
    }
    
    private var statusText: String {
        switch status {
        case .authorizedAlways: return "Location Access Granted"
        case .authorizedWhenInUse: return "Limited Location Access"
        case .denied: return "Location Access Denied"
        case .restricted: return "Location Access Restricted"
        case .notDetermined: return "Location Permission Required"
        @unknown default: return "Unknown Status"
        }
    }
} 