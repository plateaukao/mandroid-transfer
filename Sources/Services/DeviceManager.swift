import Foundation

@Observable
@MainActor
final class DeviceManager {
    var devices: [DeviceInfo] = []
    var selectedDevice: DeviceInfo?

    private let adbService: ADBService
    private let cache: DirectoryCache

    init(adbService: ADBService, cache: DirectoryCache) {
        self.adbService = adbService
        self.cache = cache
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
            // ADB server might not be running
        }
    }
}
