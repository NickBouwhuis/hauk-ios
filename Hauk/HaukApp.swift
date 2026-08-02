import SwiftUI
import UIKit
import BackgroundTasks
import AppIntents
import UserNotifications

/// Exists solely so the system can hand us background `URLSession` events.
/// When a queued stop request completes while the app is suspended or
/// terminated, iOS relaunches us into the background and calls this; we have
/// to recreate the session and let it drain before reporting back.
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        handleEventsForBackgroundURLSession identifier: String,
        completionHandler: @escaping () -> Void
    ) {
        StopRequestService.shared.handleBackgroundEvents(
            identifier: identifier,
            completionHandler: completionHandler
        )
    }
}

@main
struct HaukApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var locationManager: LocationManager
    @StateObject private var sharingManager: SharingManager
    @Environment(\.scenePhase) private var scenePhase

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
        
        // Request location permissions immediately
        locationManager.requestAuthorization()
        
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
                .task {
                    await resumeInterruptedWork()
                }
                .onChange(of: scenePhase) { _, newPhase in
                    guard newPhase == .active else { return }
                    Task { await resumeInterruptedWork() }
                }
        }
    }

    /// Picks up anything a previous run could not finish: sessions that were
    /// stopped locally but never confirmed by the server, and Live Activities
    /// that outlived their session because the app was force quit or the stop
    /// request failed while we were in the background.
    @MainActor
    private func resumeInterruptedWork() async {
        if #available(iOS 16.1, *) {
            await sharingManager.reconcileLiveActivities()
        }
        await sharingManager.flushPendingStops()
    }
}
