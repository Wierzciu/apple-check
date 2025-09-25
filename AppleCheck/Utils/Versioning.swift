import Foundation

enum Versioning {
    static func extractMajor(from version: String) -> Int? {
        // Extract the first numeric component in the version string.
        let digits = version.firstMatch(in: #"(\d+)"#)
        return digits.flatMap { Int($0) }
    }

    /// Compares versions while supporting formats like "18", "18.0", and "17.7.6".
    /// Returns .orderedDescending when lhs > rhs.
    static func compareVersions(_ lhs: String, _ rhs: String) -> ComparisonResult {
        func components(_ s: String) -> [Int] {
            let normalized = s.lowercased()
                .replacingOccurrences(of: "beta", with: "")
                .replacingOccurrences(of: "rc", with: "")
            let parts = normalized.firstMatch(in: #"(\d+(?:\.\d+){0,3})"#) ?? normalized
            return parts.split(separator: ".").compactMap { Int($0) }
        }
        let a = components(lhs)
        let b = components(rhs)
        let count = max(a.count, b.count)
        for i in 0..<count {
            let ai = i < a.count ? a[i] : 0
            let bi = i < b.count ? b[i] : 0
            if ai != bi { return ai > bi ? .orderedDescending : .orderedAscending }
        }
        return .orderedSame
    }
}

extension String {
    func firstMatch(in pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(location: 0, length: utf16.count)
        guard let m = regex.firstMatch(in: self, options: [], range: range), m.numberOfRanges > 1 else { return nil }
        if let r = Range(m.range(at: 1), in: self) { return String(self[r]) }
        return nil
    }
}

