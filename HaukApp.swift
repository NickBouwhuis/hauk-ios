import SwiftUI

@main
struct HaukApp: App {
    // Handle app lifecycle and state
    @StateObject private var locationManager = LocationManager()
    @StateObject private var sharingManager = SharingManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(locationManager)
                .environmentObject(sharingManager)
        }
    }
} 