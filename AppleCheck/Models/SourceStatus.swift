import Foundation

enum SourceStatus: String, Codable {
    case device_first
    case announce_first
    case confirmed

    var displayName: String {
        switch self {
        case .device_first: return "device_first"
        case .announce_first: return "announce_first"
        case .confirmed: return "confirmed"
        }
    }
}


