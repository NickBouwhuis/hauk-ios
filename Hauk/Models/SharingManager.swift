import Foundation
import CoreLocation

final class SharingManager: ObservableObject {
    @Published var isSharing = false
    @Published var activeShares: [Share] = []
    @Published var error: Error?
    
    private let locationManager: LocationManager?
    private var uploadTask: Task<Void, Never>?
    private var sessionId: String?
    private let queue = DispatchQueue(label: "net.bouwhuis.nick.Hauk.sharing")
    
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
        
        init(id: String, baseUrl: URL, expiryDate: Date) {
            self.id = id
            self.baseUrl = baseUrl
            self.shareUrl = baseUrl
            self.sessionId = nil
            self.viewerId = nil
            self.expiryDate = expiryDate
            self.locations = []
        }
        
        init(id: String, 
             baseUrl: URL, 
             shareUrl: URL, 
             sessionId: String?, 
             viewerId: String?, 
             expiryDate: Date, 
             locations: [CLLocation]) {
            self.id = id
            self.baseUrl = baseUrl
            self.shareUrl = shareUrl
            self.sessionId = sessionId
            self.viewerId = viewerId
            self.expiryDate = expiryDate
            self.locations = locations
        }
    }
    
    func startSharing(duration: TimeInterval) async {
        guard let serverUrl = UserDefaults.standard.string(forKey: "serverUrl"), !serverUrl.isEmpty else {
            await MainActor.run {
                error = SharingError.noServerConfigured
                isSharing = false
                activeShares.removeAll()
            }
            return
        }
        
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
            expiryDate: expiryDate
        )
        
        await MainActor.run {
            activeShares = [share]
        }
        
        do {
            try await initializeShare(share)
            
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
            }
        } catch {
            await MainActor.run {
                self.error = error
                self.activeShares.removeAll()
                locationManager?.stopUpdating()
                isSharing = false
            }
        }
    }
    
    private func initializeShare(_ share: Share) async throws {
        var request = URLRequest(url: share.baseUrl.appendingPathComponent("api/create.php"))
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        // Get settings
        let preferredLinkId = UserDefaults.standard.string(forKey: "preferredLinkId") ?? ""
        let isPasswordProtected = UserDefaults.standard.bool(forKey: "isPasswordProtected")
        let sharePassword = UserDefaults.standard.string(forKey: "sharePassword") ?? ""
        
        // Use default value of 1 if not set
        let interval = UserDefaults.standard.object(forKey: "updateInterval") as? Int ?? 1
        
        let params = [
            ("dur", "\(Int(share.expiryDate.timeIntervalSinceNow))"),
            ("mod", "0"),
            ("lid", preferredLinkId),
            ("e2e", "0"),
            ("pwd", isPasswordProtected ? sharePassword : ""),
            ("ado", "0"),
            ("int", "\(interval)")
        ]
        
        let formData = params.map { key, value in 
            "\(key)=\(value)"
        }.joined(separator: "&")
        
        request.httpBody = formData.data(using: .utf8)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw SharingError.serverError
        }
        
        guard let responseStr = String(data: data, encoding: .utf8) else {
            throw SharingError.serverError
        }
        
        let parts = responseStr.split(separator: "\n")
        guard parts.count >= 4,
              parts[0] == "OK",
              let shareUrl = URL(string: String(parts[2])) else {
            if responseStr.contains("Missing data!") {
                print("Server response: Missing data!")
                print("Sent data: \(formData)")
            }
            throw SharingError.serverError
        }
        
        let sessionId = String(parts[1])
        let viewerId = String(parts[3])
        
        // Create the updated share as a local constant
        let finalShare = Share(
            id: share.id,
            baseUrl: share.baseUrl,
            shareUrl: shareUrl,  // Use the shareUrl from the server response
            sessionId: sessionId,
            viewerId: viewerId,
            expiryDate: share.expiryDate,
            locations: share.locations
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
            throw SharingError.serverError
        }
        
        // Check for specific error responses
        if let responseStr = String(data: data, encoding: .utf8) {
            if responseStr.contains("Missing data!") {
                throw SharingError.serverError
            }
            if !responseStr.hasPrefix("OK") {
                throw SharingError.serverError
            }
        }
    }
    
    private func uploadLocation(_ location: CLLocation) async {
        guard let share = await MainActor.run(body: { activeShares.first }) else { return }
        
        do {
            try await uploadLocationToServer(location, for: share)
        } catch {
            if !(error is CancellationError) {
                await MainActor.run {
                    self.error = error
                }
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
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw SharingError.serverError
        }
    }
    
    func stopSharing() async {
        let shareToStop = await MainActor.run { activeShares.first }
        
        await MainActor.run {
            locationManager?.stopUpdating()
            isSharing = false
            activeShares.removeAll()
        }
        
        if let share = shareToStop {
            do {
                try await stopShare(share)
            } catch {
                print("Error stopping share: \(error.localizedDescription)")
            }
        }
        
        sessionId = nil
    }
    
    enum SharingError: LocalizedError {
        case noServerConfigured
        case invalidServerUrl
        case serverError
        case cancelled
        
        var errorDescription: String? {
            switch self {
            case .noServerConfigured:
                return "No server URL configured. Please set a server URL in Settings."
            case .invalidServerUrl:
                return "The configured server URL is invalid."
            case .serverError:
                return "Failed to communicate with the server. Please try again."
            case .cancelled:
                return "Operation cancelled. This is normal during rapid updates."
            }
        }
    }
} 
