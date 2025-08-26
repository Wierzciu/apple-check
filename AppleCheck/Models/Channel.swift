import Foundation

enum Channel: String, Codable, CaseIterable, Identifiable {
    case developerBeta
    case publicBeta
    case rc
    case release

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .developerBeta: return "Developer Beta"
        case .publicBeta: return "Public Beta"
        case .rc: return "RC"
        case .release: return "Release"
        }
    }
}


