import Foundation

struct ReleaseItem: Identifiable, Codable, Hashable {
    var id: String { "\(kind.rawValue)-\(version)-\(build)-\(channel.rawValue)" }
    let kind: OSKind
    let version: String
    let build: String
    let channel: Channel
    let publishedAt: Date
    let status: SourceStatus
    let deviceIdentifier: String?
    let betaNumber: Int?

    var formattedDate: String {
        DisplayDateFormatter.dateTime.string(from: publishedAt)
    }

    var displayTitle: String {
        let baseVersion: String = {
            // If the version does not contain a dot, append .0 for readability.
            if version.firstIndex(of: ".") == nil { return "\(version).0" }
            return version
        }()
        switch channel {
        case .developerBeta:
            let bn = betaNumber.map { " beta \($0)" } ?? " beta"
            return "\(kind.displayName) \(baseVersion)\(bn) - Developer Beta"
        case .publicBeta:
            let bn = betaNumber.map { " beta \($0)" } ?? " beta"
            return "\(kind.displayName) \(baseVersion)\(bn) - Public Beta"
        case .rc:
            return "\(kind.displayName) \(baseVersion) - RC"
        case .release:
            return "\(kind.displayName) \(baseVersion) - Release"
        }
    }
}

extension ReleaseItem {
    func withPublishedAt(_ date: Date) -> ReleaseItem {
        ReleaseItem(
            kind: kind,
            version: version,
            build: build,
            channel: channel,
            publishedAt: date,
            status: status,
            deviceIdentifier: deviceIdentifier,
            betaNumber: betaNumber
        )
    }
}
