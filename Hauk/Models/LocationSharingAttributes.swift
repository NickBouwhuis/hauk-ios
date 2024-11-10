import ActivityKit
import Foundation

struct LocationSharingAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var expiryDate: Date
        var lastLocation: String?
    }
    
    var shareUrl: String
    var startDate: Date
}
