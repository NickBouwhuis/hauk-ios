import SwiftUI

struct SettingsView: View {
    @AppStorage("serverUrl") private var serverUrl = ""
    @AppStorage("username") private var username = ""
    @AppStorage("password") private var password = ""
    @AppStorage("preferredLinkId") private var preferredLinkId = ""
    @AppStorage("updateInterval") private var updateInterval = 1
//    @AppStorage("isPasswordProtected") private var isPasswordProtected = false
//    @AppStorage("sharePassword") private var sharePassword = ""
    @EnvironmentObject var locationManager: LocationManager
    
    var body: some View {
        Form {
            Section(header: Text("Server Configuration")) {
                TextField("Server URL", text: $serverUrl)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .keyboardType(.URL)
                
                TextField("Username (optional)", text: $username)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)

                SecureField("Password (optional)", text: $password)
            }
            
            Section(header: Text("Share Settings")) {
                TextField("Preferred Link ID", text: $preferredLinkId)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                
                Stepper("Update Interval: \(updateInterval)s", 
                        value: $updateInterval,
                        in: 1...60)
                    .help("Minimum interval is 1 second")
                
//                Toggle("Password Protected Shares", isOn: $isPasswordProtected)
                
//                if isPasswordProtected {
//                    SecureField("Share Password", text: $sharePassword)
//                }
            }
            
            Section(header: Text("Location Access")) {
                HStack {
                    Text("Status")
                    Spacer()
                    Text(locationStatusText)
                        .foregroundColor(.secondary)
                }
                
                if locationManager.authorizationStatus == .denied {
                    Button("Open Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                }
            }
            
            Section(header: Text("About")) {
                HStack {
                    Text("Version")
                    Spacer()
                    Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown")
                        .foregroundColor(.secondary)
                }
            }
        }
        .navigationTitle("Settings")
    }
    
    private var locationStatusText: String {
        switch locationManager.authorizationStatus {
        case .authorizedAlways: return "Always"
        case .authorizedWhenInUse: return "While Using (for a better experience: Change to 'Always' in System Settings"
        case .denied: return "Denied. Hauk cannot share your location."
        case .restricted: return "Restricted. Hauk cannot share your location"
        case .notDetermined: return "Not Determined"
        @unknown default: return "Unknown"
        }
    }
} 
