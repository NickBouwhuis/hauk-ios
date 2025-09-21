import Foundation

/// An enum describing various ways a share may be created when starting a sharing session.
enum ShareMode: Int, CaseIterable, Codable {
    case createAlone = 0
    case createGroup = 1
    case joinGroup = 2
    
    /// Returns whether or not this sharing mode is a group share variant.
    var isGroupType: Bool {
        return self == .createGroup || self == .joinGroup
    }
    
    /// Human-readable description of the sharing mode
    var displayName: String {
        switch self {
        case .createAlone:
            return "Share my own location only"
        case .createGroup:
            return "Create a group share"
        case .joinGroup:
            return "Join a group share"
        }
    }
    
    /// Short description for UI display
    var shortDescription: String {
        switch self {
        case .createAlone:
            return "Solo"
        case .createGroup:
            return "Group Host"
        case .joinGroup:
            return "Group Member"
        }
    }
}

