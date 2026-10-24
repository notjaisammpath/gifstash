import Foundation

/// Downloads and caches GIF bytes. One shared instance keeps the grid from
/// re-fetching the same preview as cells scroll in and out.
public actor GifLoader {
    public static let shared = GifLoader()

    private let session: URLSession
    private let memory = NSCache<NSURL, NSData>()
    private var inflight: [URL: Task<Data, Error>] = [:]

    init() {
        let config = URLSessionConfiguration.default
        config.urlCache = URLCache(memoryCapacity: 16 << 20, diskCapacity: 256 << 20, directory: nil)
        config.requestCachePolicy = .returnCacheDataElseLoad
        config.timeoutIntervalForRequest = 20
        config.waitsForConnectivity = true
        session = URLSession(configuration: config)
        memory.totalCostLimit = 48 << 20
    }

    public func data(for url: URL) async throws -> Data {
        if let cached = memory.object(forKey: url as NSURL) {
            return cached as Data
        }
        if let existing = inflight[url] {
            return try await existing.value
        }

        let task = Task<Data, Error> { [session] in
            let (data, response) = try await session.data(from: url)
            if let http = response as? HTTPURLResponse,
               !(200..<300).contains(http.statusCode) {
                throw GifProviderError.http(http.statusCode)
            }
            return data
        }
        inflight[url] = task

        do {
            let data = try await task.value
            inflight[url] = nil
            memory.setObject(data as NSData, forKey: url as NSURL, cost: data.count)
            return data
        } catch {
            inflight[url] = nil
            throw error
        }
    }

    /// Materializes the full-size GIF on disk. Messages needs a file URL to
    /// attach, and the extension on the line expects a real .gif extension.
    public func fileURL(for item: GifItem) async throws -> URL {
        let data = try await data(for: item.fullURL)

        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("outgoing", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let destination = directory.appendingPathComponent(item.filename)
        try data.write(to: destination, options: .atomic)
        return destination
    }
}
