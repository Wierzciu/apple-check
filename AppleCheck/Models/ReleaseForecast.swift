import Foundation

struct ReleaseForecast: Identifiable {
    enum Confidence: String {
        case high
        case medium
        case low

        var displayName: String {
            switch self {
            case .high: return "High"
            case .medium: return "Medium"
            case .low: return "Low"
            }
        }
    }

    struct Window {
        let earliest: Date
        let latest: Date

        var formatted: String {
            if Calendar.current.isDate(earliest, inSameDayAs: latest) {
                return DisplayDateFormatter.date.string(from: earliest)
            }
            let first = DisplayDateFormatter.date.string(from: earliest)
            let second = DisplayDateFormatter.date.string(from: latest)
            return "\(first) - \(second)"
        }
    }

    let id: String
    let channel: Channel
    let headline: String
    let note: String
    let window: Window?
    let confidence: Confidence
}

struct ReleaseForecastSummary {
    let kind: OSKind
    let generatedAt: Date
    let items: [ReleaseForecast]
    let rumors: [RumorPrediction]
}

extension ReleaseForecastSummary {
    static let emptyIOS: ReleaseForecastSummary = .init(kind: .iOS, generatedAt: Date(), items: [], rumors: [])
}
