import Foundation

struct RumorPrediction: Identifiable, Hashable {
    let id: String
    let source: String
    let title: String
    let summary: String
    let url: URL
    let window: ReleaseForecast.Window?
    let confidence: ReleaseForecast.Confidence
}
