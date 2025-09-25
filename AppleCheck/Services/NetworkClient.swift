import Foundation

/// Lightweight network client with ETag/If-Modified-Since support and a file-backed cache.
final class NetworkClient {
    static let shared = NetworkClient()
    private init() {}

    private let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 30
        config.httpAdditionalHeaders = [
            "User-Agent": "AppleCheck/1.0 (iOS)"
        ]
        return URLSession(configuration: config)
    }()

    private lazy var cacheURL: URL = {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("etag_cache.json")
    }()

    private struct CacheEntry: Codable { let etag: String?; let lastModified: String? }
    private var cache: [String: CacheEntry] = [:]

    private func loadCache() {
        guard cache.isEmpty, let data = try? Data(contentsOf: cacheURL) else { return }
        if let dict = try? JSONDecoder().decode([String: CacheEntry].self, from: data) { cache = dict }
    }
    private func saveCache() {
        if let data = try? JSONEncoder().encode(cache) { try? data.write(to: cacheURL) }
    }

    struct Response { let data: Data; let statusCode: Int; let etag: String?; let lastModified: String? }

    func get(_ url: URL) async throws -> Response? {
        loadCache()
        var request = URLRequest(url: url)
        if let entry = cache[url.absoluteString] {
            if let etag = entry.etag { request.addValue(etag, forHTTPHeaderField: "If-None-Match") }
            if let lm = entry.lastModified { request.addValue(lm, forHTTPHeaderField: "If-Modified-Since") }
        }
        let (data, resp) = try await session.data(for: request)
        guard let http = resp as? HTTPURLResponse else { return nil }
        if http.statusCode == 304 { return nil }
        let etag = http.allHeaderFields["ETag"] as? String
        let lm = http.allHeaderFields["Last-Modified"] as? String
        cache[url.absoluteString] = CacheEntry(etag: etag, lastModified: lm)
        saveCache()
        return Response(data: data, statusCode: http.statusCode, etag: etag, lastModified: lm)
    }

    func getIfModified(_ url: URL) async -> Data? {
        do { if let r = try await get(url) { return r.data } } catch { Logger.shared.log("GET error: \(error)") }
        return nil
    }
}

