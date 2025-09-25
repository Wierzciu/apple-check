import Foundation

enum DisplayDateFormatter {
    static let date: DateFormatter = {
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.calendar = Calendar(identifier: .gregorian)
        df.dateStyle = .medium
        df.timeStyle = .none
        return df
    }()

    static let dateTime: DateFormatter = {
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.calendar = Calendar(identifier: .gregorian)
        df.dateStyle = .medium
        df.timeStyle = .short
        return df
    }()
}
