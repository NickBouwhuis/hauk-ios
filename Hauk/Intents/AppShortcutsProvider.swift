import AppIntents

public struct HaukShortcuts: AppShortcutsProvider {
    public static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartSharingIntent(),
            phrases: [
                "Start sharing my location with ${applicationName}",
                "Share my location using ${applicationName}",
                "Start ${applicationName} sharing",
                "Get ${applicationName} sharing link",
                "Share my location for 1 hour with ${applicationName}"
            ],
            shortTitle: "Share Location",
            systemImageName: "location.fill.viewfinder"
        )
    }
}
