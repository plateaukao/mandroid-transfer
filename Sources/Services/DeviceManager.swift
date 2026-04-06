import Foundation

@Observable
@MainActor
final class DeviceManager {
    var devices: [DeviceInfo] = []
    var selectedDevice: DeviceInfo?
    private(set) var isPolling = false

    private let adbService: ADBService
    private let cache: DirectoryCache
    private var pollTask: Task<Void, Never>?

    init(adbService: ADBService, cache: DirectoryCache) {
        self.adbService = adbService
        self.cache = cache
    }

    func startPolling(interval: TimeInterval = 3.0) {
        guard !isPolling else { return }
        isPolling = true
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refreshDevices()
                try? await Task.sleep(for: .seconds(interval))
            }
        }
    }

    func stopPolling() {
        pollTask?.cancel()
        pollTask = nil
        isPolling = false
    }

    func refreshDevices() async {
        do {
            let newDevices = try await adbService.listDevices()
            let newSerials = Set(newDevices.map(\.serial))

            // If selected device disappeared, invalidate its cache and deselect
            if let selected = selectedDevice, !newSerials.contains(selected.serial) {
                await cache.invalidateAll(device: selected.serial)
                selectedDevice = newDevices.first(where: \.isOnline)
            }

            // Auto-select first online device if none selected
            if selectedDevice == nil {
                selectedDevice = newDevices.first(where: \.isOnline)
            }

            devices = newDevices
        } catch {
            // ADB server might not be running; silently retry on next poll
        }
    }

    // Note: stopPolling() should be called before this object is released
}
