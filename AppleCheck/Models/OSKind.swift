import Foundation

enum OSKind: String, Codable, CaseIterable, Identifiable {
    case iOS
    case iPadOS
    case macOS
    case watchOS
    case tvOS
    case xcode

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .iOS: return "iOS"
        case .iPadOS: return "iPadOS"
        case .macOS: return "macOS"
        case .watchOS: return "watchOS"
        case .tvOS: return "tvOS"
        case .xcode: return "Xcode"
        }
    }

    var systemImage: String {
        switch self {
        case .iOS: return "iphone"
        case .iPadOS: return "ipad"
        case .macOS: return "laptopcomputer"
        case .watchOS: return "applewatch"
        case .tvOS: return "appletv"
        case .xcode: return "hammer"
        }
    }
}


