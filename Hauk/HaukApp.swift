import SwiftUI
import BackgroundTasks

@main
struct HaukApp: App {
    @StateObject private var locationManager = LocationManager()
    @StateObject private var sharingManager: SharingManager
    
    init() {
        let locationManager = LocationManager()
        let sharingManager = SharingManager(locationManager: locationManager)
        _locationManager = StateObject(wrappedValue: locationManager)
        _sharingManager = StateObject(wrappedValue: sharingManager)
        
        // Register for background task handling
        BGTaskScheduler.shared.register(forTaskWithIdentifier: "net.bouwhuis.nick.Hauk.locationUpdate", using: nil) { task in
            task.setTaskCompleted(success: true)
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(locationManager)
                .environmentObject(sharingManager)
        }
    }
} 