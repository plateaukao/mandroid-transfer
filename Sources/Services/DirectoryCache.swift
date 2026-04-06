import Foundation

actor DirectoryCache {
    private struct CacheKey: Hashable {
        let deviceSerial: String
        let path: String
    }

    private struct CachedListing {
        let files: [AndroidFile]
        let timestamp: Date
    }

    private var cache: [CacheKey: CachedListing] = [:]
    private let ttl: TimeInterval = 300 // 5 minutes

    func get(device: String, path: String) -> [AndroidFile]? {
        let key = CacheKey(deviceSerial: device, path: path)
        guard let entry = cache[key] else { return nil }
        if Date().timeIntervalSince(entry.timestamp) > ttl {
            cache.removeValue(forKey: key)
            return nil
        }
        return entry.files
    }

    func set(device: String, path: String, files: [AndroidFile]) {
        let key = CacheKey(deviceSerial: device, path: path)
        cache[key] = CachedListing(files: files, timestamp: Date())
    }

    func invalidate(device: String, path: String) {
        let key = CacheKey(deviceSerial: device, path: path)
        cache.removeValue(forKey: key)
    }

    func invalidateAll(device: String) {
        cache = cache.filter { $0.key.deviceSerial != device }
    }

    func invalidateAll() {
        cache.removeAll()
    }
}
