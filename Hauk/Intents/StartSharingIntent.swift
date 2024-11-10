import AppIntents
import Foundation

struct StartSharingIntent: AppIntent {
    static var title: LocalizedStringResource = "Start Sharing Location"
    static var description = IntentDescription("Starts sharing your location and returns a sharing URL that you can send to others")
    
    static var openAppWhenRun = false
    
    static var parameterSummary: some ParameterSummary {
        Summary("Start sharing location for 1 hour")
    }
    
    @MainActor
    static var resultDisplayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "Sharing URL",
            subtitle: "Use this link to share your location"
        )
    }
    
    func perform() async throws -> some IntentResult & ReturnsValue<URL> {
        let manager = await SharingManager.shared
        
        // Check if already sharing
        if let existingShare = await manager.activeShares.first,
           await manager.isSharing,
           existingShare.shareUrl != existingShare.baseUrl {
            return .result(value: existingShare.shareUrl)
        }
        
        // Default sharing duration (1 hour = 3600 seconds)
        let duration: TimeInterval = 3600
        
        await manager.startSharing(duration: duration)
        
        // Wait for the share URL to be available
        var shareUrl: URL?
        for _ in 0..<10 { // Try for up to 1 second
            if let share = await manager.activeShares.first,
               share.shareUrl != share.baseUrl { // Check if we have a valid share URL
                shareUrl = share.shareUrl
                break
            }
            try await Task.sleep(for: .milliseconds(100))
        }
        
        guard let finalUrl = shareUrl else {
            throw Error.failedToGetShareUrl
        }
        
        return .result(value: finalUrl)
    }
    
    enum Error: Swift.Error, CustomLocalizedStringResourceConvertible {
        case failedToGetShareUrl
        
        var localizedStringResource: LocalizedStringResource {
            switch self {
            case .failedToGetShareUrl:
                return "Failed to get sharing URL. Please check your internet connection and try again."
            }
        }
    }
} 