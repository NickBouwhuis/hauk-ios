import SwiftUI
import BackgroundTasks
import AppIntents
import UserNotifications

@main
struct HaukApp: App {
    @StateObject private var locationManager: LocationManager
    @StateObject private var sharingManager: SharingManager
    
    static let shortcutsProvider = HaukShortcuts()
    
    init() {
        // Initialize LocationManager first
        let locationManager = LocationManager()
        _locationManager = StateObject(wrappedValue: locationManager)
        
        // Use the shared SharingManager instance instead of creating a new one
        _sharingManager = StateObject(wrappedValue: SharingManager.shared)
        
        // Request notification permissions
        Task {
            try? await UNUserNotificationCenter.current().requestAuthorization(
                options: [.alert, .sound]
            )
        }
        
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
