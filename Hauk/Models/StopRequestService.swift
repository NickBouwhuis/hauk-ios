import Foundation

/// Guarantees that "stop sharing" reaches the server.
///
/// Stopping a share is the one request we cannot afford to lose: if it never
/// arrives, the session stays live and keeps publishing the user's last known
/// location until it expires on its own, hours after they thought they had
/// stopped sharing.
///
/// Three layers protect it:
///
/// 1. Every stop is written to `UserDefaults` before it is attempted, and only
///    removed once the server has confirmed it.
/// 2. A foreground attempt runs immediately, so the common case is instant.
/// 3. If that fails, the request is handed to a background `URLSession`, which
///    the system owns. It retries as connectivity allows and completes even if
///    the app is suspended or terminated, relaunching us to report the result.
///
/// Anything that still hasn't landed is retried by `flush()` on the next launch.
final class StopRequestService: NSObject, @unchecked Sendable {
    static let shared = StopRequestService()

    private static let pendingStopsKey = "pendingStopRequests"
    private static let backgroundSessionIdentifier = "net.bouwhuis.nick.Hauk.stopRequests"

    private let lock = NSLock()
    private var backgroundCompletionHandler: (() -> Void)?

    private lazy var backgroundSession: URLSession = {
        let config = URLSessionConfiguration.background(withIdentifier: Self.backgroundSessionIdentifier)
        // The user asked to stop sharing; this is not deferrable housekeeping.
        config.isDiscretionary = false
        config.sessionSendsLaunchEvents = true
        // Keep retrying for a day. A share can outlive that, but by then the
        // session has almost certainly expired on its own anyway.
        config.timeoutIntervalForResource = 24 * 60 * 60
        return URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }()

    private override init() {
        super.init()
    }

    // MARK: - Pending stop persistence

    struct PendingStop: Codable, Equatable {
        let sessionId: String
        let baseUrl: URL
        let queuedAt: Date
    }

    private func loadPendingStops() -> [PendingStop] {
        guard let data = UserDefaults.standard.data(forKey: Self.pendingStopsKey) else { return [] }
        return (try? JSONDecoder().decode([PendingStop].self, from: data)) ?? []
    }

    private func savePendingStops(_ stops: [PendingStop]) {
        lock.lock()
        defer { lock.unlock() }

        if stops.isEmpty {
            UserDefaults.standard.removeObject(forKey: Self.pendingStopsKey)
        } else if let data = try? JSONEncoder().encode(stops) {
            UserDefaults.standard.set(data, forKey: Self.pendingStopsKey)
        }
    }

    private func enqueue(_ stop: PendingStop) {
        var stops = loadPendingStops()
        guard !stops.contains(where: { $0.sessionId == stop.sessionId }) else { return }
        stops.append(stop)
        savePendingStops(stops)
    }

    private func confirm(sessionId: String) {
        savePendingStops(loadPendingStops().filter { $0.sessionId != sessionId })
        removeBodyFile(sessionId: sessionId)
        print("✅ Confirmed stop for session \(sessionId)")
    }

    var hasPendingStops: Bool {
        !loadPendingStops().isEmpty
    }

    // MARK: - Public API

    /// Stops a session, and keeps trying until the server confirms it.
    func stop(sessionId: String, baseUrl: URL) async {
        let stop = PendingStop(sessionId: sessionId, baseUrl: baseUrl, queuedAt: Date())
        enqueue(stop)

        if await attemptInForeground(stop) {
            confirm(sessionId: stop.sessionId)
        } else {
            scheduleInBackground(stop)
        }
    }

    /// Retries every stop the server hasn't confirmed yet. Safe to call on each
    /// launch and foreground; requests already in flight are left alone.
    func flush() async {
        let stops = loadPendingStops()
        guard !stops.isEmpty else { return }

        let inFlight = Set(await backgroundSession.allTasks.compactMap(\.taskDescription))

        for stop in stops {
            // Already handed to the system; let it finish rather than sending
            // the same stop twice.
            guard !inFlight.contains(stop.sessionId) else { continue }

            if await attemptInForeground(stop) {
                confirm(sessionId: stop.sessionId)
            } else {
                scheduleInBackground(stop)
            }
        }

        let remaining = loadPendingStops().count
        if remaining > 0 {
            print("⏳ \(remaining) stop request(s) handed to the background session")
        }
    }

    /// Called when the system relaunches us to deliver background session
    /// events. Touching `backgroundSession` recreates it so its delegate
    /// callbacks can fire.
    func handleBackgroundEvents(identifier: String, completionHandler: @escaping () -> Void) {
        guard identifier == Self.backgroundSessionIdentifier else {
            completionHandler()
            return
        }

        lock.lock()
        backgroundCompletionHandler = completionHandler
        lock.unlock()

        _ = backgroundSession
    }

    // MARK: - Requests

    private func stopRequest(for stop: PendingStop) -> URLRequest {
        var request = URLRequest(url: stop.baseUrl.appendingPathComponent("api/stop.php"))
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 15
        return request
    }

    private func body(for stop: PendingStop) -> Data {
        Data("sid=\(stop.sessionId)".utf8)
    }

    /// One immediate attempt over the normal session. Returns `true` only when
    /// the session is confirmed gone.
    private func attemptInForeground(_ stop: PendingStop) async -> Bool {
        var request = stopRequest(for: stop)
        request.httpBody = body(for: stop)

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else { return false }
            return Self.isConclusive(statusCode: httpResponse.statusCode, sessionId: stop.sessionId)
        } catch {
            print("⚠️ Foreground stop failed for session \(stop.sessionId): \(error.localizedDescription)")
            return false
        }
    }

    /// Hands the request to the system, which will deliver it even if the app
    /// is suspended or killed before it completes.
    private func scheduleInBackground(_ stop: PendingStop) {
        guard let fileUrl = writeBodyFile(for: stop) else {
            print("❌ Could not stage stop request for session \(stop.sessionId)")
            return
        }

        // Background uploads must read their body from a file; a request with
        // an in-memory httpBody is silently sent without one.
        let task = backgroundSession.uploadTask(with: stopRequest(for: stop), fromFile: fileUrl)
        // Survives app termination, so the delegate can identify the session
        // after a relaunch without any in-memory state.
        task.taskDescription = stop.sessionId
        task.resume()

        print("📮 Handed stop for session \(stop.sessionId) to the background session")
    }

    /// Whether a status code settles the question. A 2xx is the server
    /// accepting the stop — including the localised "Session expired!" body it
    /// returns for an already-dead session, which is just as good. A 4xx means
    /// it understood us and refused, and retrying will not change that. A 5xx
    /// or a transport error might succeed later.
    private static func isConclusive(statusCode: Int, sessionId: String) -> Bool {
        switch statusCode {
        case 200...299:
            return true
        case 400...499:
            print("⚠️ Stop rejected for session \(sessionId): HTTP \(statusCode), giving up")
            return true
        default:
            print("⚠️ Stop failed for session \(sessionId): HTTP \(statusCode)")
            return false
        }
    }

    // MARK: - Body files

    private func bodyFileUrl(sessionId: String) -> URL? {
        guard let caches = try? FileManager.default.url(
            for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true
        ) else { return nil }

        let directory = caches.appendingPathComponent("PendingStops", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        // Session IDs are server-generated tokens, but they land in a path, so
        // don't trust them to be filename-safe.
        let safeName = sessionId.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? sessionId
        return directory.appendingPathComponent("\(safeName).body")
    }

    private func writeBodyFile(for stop: PendingStop) -> URL? {
        guard let url = bodyFileUrl(sessionId: stop.sessionId) else { return nil }
        do {
            try body(for: stop).write(to: url, options: .atomic)
            return url
        } catch {
            print("❌ Could not write stop body: \(error.localizedDescription)")
            return nil
        }
    }

    private func removeBodyFile(sessionId: String) {
        guard let url = bodyFileUrl(sessionId: sessionId) else { return }
        try? FileManager.default.removeItem(at: url)
    }
}

// MARK: - URLSessionTaskDelegate

extension StopRequestService: URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let sessionId = task.taskDescription else { return }

        if let error {
            // The background session has already exhausted its own retries by
            // this point. Leave the stop queued so `flush()` picks it up.
            print("⚠️ Background stop failed for session \(sessionId): \(error.localizedDescription)")
            return
        }

        let statusCode = (task.response as? HTTPURLResponse)?.statusCode ?? 0
        if Self.isConclusive(statusCode: statusCode, sessionId: sessionId) {
            confirm(sessionId: sessionId)
        }
    }

    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        lock.lock()
        let handler = backgroundCompletionHandler
        backgroundCompletionHandler = nil
        lock.unlock()

        // UIKit requires this on the main thread.
        DispatchQueue.main.async {
            handler?()
        }
    }
}
