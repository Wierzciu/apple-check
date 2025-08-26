import Foundation

final class Logger {
    static let shared = Logger()
    private init() {}

    private let fileManager = FileManager.default

    private lazy var logURL: URL = {
        let dir = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
        return dir.appendingPathComponent("applecheck.log")
    }()

    func log(_ message: String) {
        let line = "[\(Date())] \(message)\n"
        print(line)
        if let data = line.data(using: .utf8) {
            if fileManager.fileExists(atPath: logURL.path) {
                if let handle = try? FileHandle(forWritingTo: logURL) {
                    try? handle.seekToEnd()
                    try? handle.write(contentsOf: data)
                    try? handle.close()
                }
            } else {
                try? data.write(to: logURL)
            }
        }
    }
}


