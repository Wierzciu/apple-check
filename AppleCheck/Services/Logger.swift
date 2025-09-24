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
        guard let data = line.data(using: .utf8) else { return }
        if fileManager.fileExists(atPath: logURL.path) {
            do {
                let handle = try FileHandle(forWritingTo: logURL)
                defer { try? handle.close() }
                try handle.seekToEnd()
                try handle.write(contentsOf: data)
            } catch {
                print("Logger write error: \(error)")
            }
        } else {
            do {
                try data.write(to: logURL)
            } catch {
                print("Logger create error: \(error)")
            }
        }
    }
}

