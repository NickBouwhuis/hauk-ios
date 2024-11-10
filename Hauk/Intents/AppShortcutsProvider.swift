import AppIntents

public struct HaukShortcuts: AppShortcutsProvider {
    public static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartSharingIntent(),
            phrases: [
                "Start sharing my location with Hauk",
                "Share my location using Hauk",
                "Start Hauk sharing",
                "Get Hauk sharing link",
                "Share my location for 1 hour"
            ],
            shortTitle: "Share Location",
            systemImageName: "location.fill.viewfinder"
        )
    }
} 