import Foundation
import CoreLocation
import UserNotifications
import ActivityKit

@MainActor
final class SharingManager: ObservableObject, @unchecked Sendable {
    static let shared: SharingManager = {
        let locationManager = LocationManager()
        return SharingManager(locationManager: locationManager)
    }()
    
    @Published var isSharing = false
    @Published var activeShares: [Share] = []
    @Published var error: Error?
    @Published var sessionEndMessage: String?
    
    private let locationManager: LocationManager?
    private var uploadTask: Task<Void, Never>?
    private var sessionId: String?

    private let queue = DispatchQueue(label: "net.bouwhuis.nick.Hauk.sharing")
    
    private var expiryTimer: Timer?
    private var activity: Activity<LocationSharingAttributes>?
    
    init(locationManager: LocationManager? = nil) {
        self.locationManager = locationManager
    }
    
    struct Share: Identifiable {
        let id: String
        let baseUrl: URL
        var shareUrl: URL
        var sessionId: String?
        var viewerId: String?
        let expiryDate: Date
        var locations: [CLLocation]
        let shareMode: ShareMode
        var groupPin: String?
        var nickname: String?
        
        init(id: String, baseUrl: URL, expiryDate: Date, shareMode: ShareMode = .createAlone) {
            self.id = id
            self.baseUrl = baseUrl
            self.shareUrl = baseUrl
            self.sessionId = nil
            self.viewerId = nil
            self.expiryDate = expiryDate
            self.locations = []
            self.shareMode = shareMode
            self.groupPin = nil
            self.nickname = nil
        }
        
        init(id: String, 
             baseUrl: URL, 
             shareUrl: URL, 
             sessionId: String?, 
             viewerId: String?, 
             expiryDate: Date, 
             locations: [CLLocation],
             shareMode: ShareMode = .createAlone,
             groupPin: String? = nil,
             nickname: String? = nil) {
            self.id = id
            self.baseUrl = baseUrl
            self.shareUrl = shareUrl
            self.sessionId = sessionId
            self.viewerId = viewerId
            self.expiryDate = expiryDate
            self.locations = locations
            self.shareMode = shareMode
            self.groupPin = groupPin
            self.nickname = nickname
        }
    }
    
    func startSharing(duration: TimeInterval, shareMode: ShareMode = .createAlone, nickname: String? = nil, groupPin: String? = nil) async {
        // Use default server if no server is configured
        let configuredServerUrl = UserDefaults.standard.string(forKey: "serverUrl") ?? ""
        let serverUrl = configuredServerUrl.isEmpty ? "https://hauk.live" : configuredServerUrl
        print("🔍 Starting sharing with server: \(serverUrl)")
        
        let shareId = UUID().uuidString
        let expiryDate = Date().addingTimeInterval(duration)
        
        guard let baseUrl = URL(string: serverUrl) else {
            await MainActor.run {
                error = SharingError.invalidServerUrl
                isSharing = false
                activeShares.removeAll()
            }
            return
        }
        
        let share = Share(
            id: shareId,
            baseUrl: baseUrl,
            expiryDate: expiryDate,
            shareMode: shareMode
        )
        
        await MainActor.run {
            activeShares = [share]
        }
        
        do {
            try await initializeShare(share, nickname: nickname, groupPin: groupPin)
            
            await MainActor.run {
                isSharing = true
                // Start location updates after successful initialization
                locationManager?.startUpdating { [weak self] location in
                    guard let self = self else { return }
                    // Create a new task for each location update
                    Task {
                        await self.uploadLocation(location)
                    }
                }
                
                // Start local expiry timer
                self.startExpiryTimer(duration: duration)
            }

            // Start Live Activity after MainActor updates are complete
            // This ensures the Live Activity is fully initialized before returning
            if #available(iOS 16.1, *) {
                // Access shareUrl from the updated activeShares
                if let currentShare = await MainActor.run(body: { self.activeShares.first }) {
                    await self.startActivity(expiryDate: expiryDate, shareUrl: currentShare.shareUrl.absoluteString)
                }
            }
        } catch {
            await MainActor.run {
                print("❌ Sharing error: \(error)")
                if let sharingError = error as? SharingError {
                    print("❌ SharingError type: \(sharingError)")
                }
                self.error = error
                self.activeShares.removeAll()
                locationManager?.stopUpdating()
                stopExpiryTimer()
                isSharing = false
            }
        }
    }
    
    private func initializeShare(_ share: Share, nickname: String? = nil, groupPin: String? = nil) async throws {
        let requestUrl = share.baseUrl.appendingPathComponent("api/create.php")
        print("🌐 Making request to: \(requestUrl)")
        
        var request = URLRequest(url: requestUrl)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        // Get settings
        let preferredLinkId = UserDefaults.standard.string(forKey: "preferredLinkId") ?? ""
        let isAdoptable = UserDefaults.standard.bool(forKey: "isAdoptable") ? 1 : 0
//        let isPasswordProtected = UserDefaults.standard.bool(forKey: "isPasswordProtected")
//        let sharePassword = UserDefaults.standard.string(forKey: "sharePassword") ?? ""
        let username = UserDefaults.standard.string(forKey: "username") ?? ""
        let password = UserDefaults.standard.string(forKey: "password") ?? ""
        
        // Use default value of 1 if not set
        let interval = UserDefaults.standard.object(forKey: "updateInterval") as? Int ?? 1
        
        var params = [
            ("dur", "\(Int(share.expiryDate.timeIntervalSinceNow))"),
            ("mod", "\(share.shareMode.rawValue)"),
            ("lid", preferredLinkId),
            ("e2e", "0"), // Group shares don't support E2E encryption
            ("usr", username),
            ("pwd", password),
            ("ado", "\(isAdoptable)"),
            ("int", "\(interval)")
        ]
        
        // Add group-specific parameters
        if share.shareMode.isGroupType {
            if let nickname = nickname {
                params.append(("nic", nickname))
            }
            
            if share.shareMode == .joinGroup, let groupPin = groupPin {
                params.append(("pin", groupPin))
            }
        }
        
        let formData = params.map { key, value in 
            "\(key)=\(value)"
        }.joined(separator: "&")
        
        request.httpBody = formData.data(using: .utf8)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        print("📡 Response received: \(response)")
        if let httpResponse = response as? HTTPURLResponse {
            print("📡 Status code: \(httpResponse.statusCode)")
        }
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown server error"
            print("❌ Server error: \(errorMessage)")
            throw SharingError.serverError(errorMessage)
        }
        
        guard let responseStr = String(data: data, encoding: .utf8) else {
            throw SharingError.serverError("Could not decode server response")
        }
        
        let parts = responseStr.split(separator: "\n")
        guard parts.count >= 4,
              parts[0] == "OK",
              let shareUrl = URL(string: String(parts[2])) else {
            if responseStr.contains("Missing data!") {
                print("Server response: Missing data!")
                print("Sent data: \(formData)")
                throw SharingError.serverError("Server response: \(responseStr)")
            }
            throw SharingError.serverError("\(responseStr)")
        }
        
        let sessionId = String(parts[1])
        
        // For group shares, the response format is different
        var viewerId: String
        var groupPin: String? = nil
        
        if share.shareMode == .createGroup && parts.count >= 5 {
            // Group share response: ["OK", sessionID, viewURL, groupPIN, shareID]
            groupPin = String(parts[3]) // Group PIN is at index 3
            viewerId = String(parts[4]) // Share ID is at index 4
        } else {
            // Solo share response: ["OK", sessionID, viewURL, shareID]
            viewerId = String(parts[3]) // Share ID is at index 3
        }
        
        // Create the updated share as a local constant
        let finalShare = Share(
            id: share.id,
            baseUrl: share.baseUrl,
            shareUrl: shareUrl,  // Use the shareUrl from the server response
            sessionId: sessionId,
            viewerId: viewerId,
            expiryDate: share.expiryDate,
            locations: share.locations,
            shareMode: share.shareMode,
            groupPin: groupPin,
            nickname: nickname
        )
        
        await MainActor.run {
            activeShares = [finalShare]  // Use the local constant instead of the captured variable
            isSharing = true
        }
        
        self.sessionId = sessionId
    }
    
    private func uploadLocationToServer(_ location: CLLocation, for share: Share) async throws {
        guard let sessionId = share.sessionId else { return }
        
        var request = URLRequest(url: share.baseUrl.appendingPathComponent("api/post.php"))
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        // Format timestamp as Unix timestamp in seconds
        let timestamp = Int(location.timestamp.timeIntervalSince1970)
        
        let formData = [
            "acc": String(format: "%.5f", location.horizontalAccuracy),
            "prv": "0",
            "spd": String(format: "%.1f", location.speed >= 0 ? location.speed : 0),
            "lon": String(format: "%.8f", location.coordinate.longitude),
            "time": "\(timestamp)", // Use integer Unix timestamp
            "lat": String(format: "%.8f", location.coordinate.latitude),
            "sid": sessionId
        ].map { key, value in
            "\(key)=\(value)"
        }.joined(separator: "&")
        
        request.httpBody = formData.data(using: .utf8)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw SharingError.serverError(String(data: data, encoding: .utf8) ?? "Unknown server error")
        }
        
        // Check for specific error responses
        if let responseStr = String(data: data, encoding: .utf8) {
            let trimmedResponse = responseStr.trimmingCharacters(in: .whitespacesAndNewlines)

            // Check for validation errors first
            if responseStr.contains("Missing data!") {
                throw SharingError.serverError("Missing data in request")
            }

            // If response doesn't start with "OK", it's likely a session expired message
            // The server returns localized messages like:
            // - "Session expired!" (English)
            // - "Sessie verlopen!" (Dutch)
            // - "Sitzung abgelaufen!" (German)
            // - etc. in many other languages
            // We handle all of them gracefully by stopping the session
            if !trimmedResponse.hasPrefix("OK") {
                // Session has expired, stop sharing gracefully
                await stopSharing()
                return
            }
        }
    }
    
    private func uploadLocation(_ location: CLLocation) async {
        guard let share = await MainActor.run(body: { activeShares.first }) else { return }
        
        do {
            try await uploadLocationToServer(location, for: share)
            
            if #available(iOS 16.1, *) {
                 await updateActivity(with: location)
            }
        } catch {
            if error is CancellationError {
                return
            }
            
            await MainActor.run {
                self.error = error
            }
        }
    }
    
    private func stopShare(_ share: Share) async throws {
        guard let sessionId = share.sessionId else { return }
        
        var request = URLRequest(url: share.baseUrl.appendingPathComponent("api/stop.php"))
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let formData = "sid=\(sessionId)"
        request.httpBody = formData.data(using: .utf8)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw SharingError.serverError(String(data: data, encoding: .utf8) ?? "Unknown server error")
        }
    }
    
    func stopSharing() async {
        let shareToStop = await MainActor.run { activeShares.first }
        
        await MainActor.run {
            locationManager?.stopUpdating()
            stopExpiryTimer()
            isSharing = false
            activeShares.removeAll()
        }
        
        if let share = shareToStop {
            do {
                try await stopShare(share)
                await handleSessionEnd(expired: false)
            } catch {
                print("Error stopping share: \(error.localizedDescription)")
            }
        }
        
        sessionId = nil
    }
    
    func adoptShare(shareId: String, nickname: String) async throws {
        // Use default server if no server is configured
        let configuredServerUrl = UserDefaults.standard.string(forKey: "serverUrl") ?? ""
        let serverUrl = configuredServerUrl.isEmpty ? "https://hauk.live" : configuredServerUrl
        
        guard let baseUrl = URL(string: serverUrl) else {
            throw SharingError.invalidServerUrl
        }
        
        guard let currentShare = activeShares.first else {
            throw SharingError.noActiveShare
        }
        
        guard let groupPin = currentShare.groupPin else {
            throw SharingError.notAGroupShare
        }
        
        var request = URLRequest(url: baseUrl.appendingPathComponent("api/adopt.php"))
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let params = [
            ("sid", currentShare.sessionId ?? ""),
            ("nic", nickname),
            ("aid", shareId),
            ("pin", groupPin)
        ]
        
        let formData = params.map { key, value in
            "\(key)=\(value)"
        }.joined(separator: "&")
        
        request.httpBody = formData.data(using: .utf8)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw SharingError.serverError(String(data: data, encoding: .utf8) ?? "Unknown server error")
        }
        
        guard let responseStr = String(data: data, encoding: .utf8),
              responseStr.trimmingCharacters(in: .whitespacesAndNewlines) == "OK" else {
            throw SharingError.serverError("Adoption failed: \(String(data: data, encoding: .utf8) ?? "Unknown error")")
        }
    }
    
    enum SharingError: LocalizedError {
        case noServerConfigured
        case invalidServerUrl
        case serverError(String)
        case cancelled
        case noActiveShare
        case notAGroupShare
        
        var errorDescription: String? {
            switch self {
            case .noServerConfigured:
                return "No server URL configured. Please set a server URL in Settings."
            case .invalidServerUrl:
                return "The configured server URL is invalid."
            case .serverError(let response):
                return "Server error: \(response)"
            case .cancelled:
                return "Operation cancelled. This is normal during rapid updates."
            case .noActiveShare:
                return "No active share to adopt into."
            case .notAGroupShare:
                return "Current share is not a group share."
            }
        }
    }
    
    private func handleSessionEnd(expired: Bool) async {
        // `stopSharing()` already calls this method once the session has been
        // terminated. Calling it again here resulted in infinite recursion,
        // causing a crash when a share ended. Simply perform the UI and
        // notification cleanup here without stopping again.
        
        // Show different messages for manual stop vs expiration
        let message = expired ? "Location sharing session expired" : "Location sharing stopped"
        
        // If app is active, show in-app message
        await MainActor.run {
            sessionEndMessage = message
            
            // Automatically hide the message after 3 seconds
            Task {
                try? await Task.sleep(for: .seconds(3))
                await MainActor.run {
                    if sessionEndMessage == message {  // Only clear if it hasn't been changed
                        sessionEndMessage = nil
                    }
                }
            }
            
            if #available(iOS 16.1, *) {
                Task {
                    await endActivity(expired: expired)
                }
            }
        }
        
        // If app is in background, show system notification
        let notificationCenter = UNUserNotificationCenter.current()
        let settings = await notificationCenter.notificationSettings()
        
        if settings.authorizationStatus == .authorized {
            let content = UNMutableNotificationContent()
            content.title = "Hauk"
            content.body = message
            content.sound = UNNotificationSound.default
            
            let request = UNNotificationRequest(
                identifier: UUID().uuidString,
                content: content,
                trigger: nil as UNNotificationTrigger?
            )
            
            try? await notificationCenter.add(request)
        }
    }
    
    private func startExpiryTimer(duration: TimeInterval) {
        stopExpiryTimer()
        
        // Use a non-repeating timer on the main run loop
        expiryTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                if self.isSharing {
                    await self.stopSharing()
                    // Explicitly handle session end as expired since local timer triggered it
                    // stopSharing() calls handleSessionEnd(expired: false) by default, 
                    // so we might need to update the message/notification if needed, 
                    // but stopSharing() logic handles the cleanup.
                    // The issue is distinguishing between user stop and expiration.
                    // stopSharing() assumes user stop. 
                    // Let's refine stopSharing or handle it here.
                    // Actually, if we call stopSharing(), it calls stopShare(share) which hits the server.
                    // The server might eventually return "Session expired" on next update, but we want to be proactive.
                    
                    // Let's override the message for expiration
                    self.sessionEndMessage = "Location sharing session expired"
                }
            }
        }
    }
    
    private func stopExpiryTimer() {
        expiryTimer?.invalidate()
        expiryTimer = nil
    }
    
    @available(iOS 16.1, *)
    private func startActivity(expiryDate: Date, shareUrl: String) async {
        let attributes = LocationSharingAttributes(shareUrl: shareUrl, startDate: Date())
        let contentState = LocationSharingAttributes.ContentState(expiryDate: expiryDate, lastLocation: nil)
        
        do {
            let activity = try Activity<LocationSharingAttributes>.request(
                attributes: attributes,
                content: .init(state: contentState, staleDate: nil)
            )
            self.activity = activity
            print("🚀 Started Live Activity: \(activity.id)")
        } catch {
            print("❌ Error starting Live Activity: \(error.localizedDescription)")
        }
    }
    
    @available(iOS 16.1, *)
    private func updateActivity(with location: CLLocation) async {
        guard let activity = activity else { return }
        
        // Reverse geocoding could be done here if we want address, but for now let's show coordinates or speed
        // Or keep it simple: "Moving at X km/h" or just update freshness.
        
        let speed = location.speed > 0 ? Int(location.speed * 3.6) : 0
        let locationStr = speed > 0 ? "\(speed) km/h" : "Stationary"
        
        // We need to keep the original expiry date from the activity
        // Accessing content.state in update is tricky if we don't store it. 
        // But we have ContentState definition.
        
        let currentContentState = activity.content.state
        let contentState = LocationSharingAttributes.ContentState(
            expiryDate: currentContentState.expiryDate,
            lastLocation: locationStr
        )
        
        await activity.update(.init(state: contentState, staleDate: nil))
    }
    
    @available(iOS 16.1, *)
    private func endActivity(expired: Bool) async {
        // Iterate through all active activities and end them
        for activity in Activity<LocationSharingAttributes>.activities {
            let finalContentState = activity.content.state
            let dismissalPolicy: ActivityUIDismissalPolicy = .immediate
            
            await activity.end(
                .init(state: finalContentState, staleDate: nil),
                dismissalPolicy: dismissalPolicy
            )
            print("🛑 Ended Live Activity: \(activity.id)")
        }
        
        self.activity = nil
    }
} 
