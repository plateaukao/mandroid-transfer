import Foundation

@Observable
@MainActor
final class AppState {
    // Navigation
    var currentPath: String = "/sdcard"
    var pathHistory: [String] = ["/sdcard"]
    var historyIndex: Int = 0

    // Directory listing
    var currentFiles: [AndroidFile] = []
    var isLoading = false
    var errorMessage: String?
    var showError = false

    // Selection
    var selectedFileIDs: Set<String> = []

    // Storage volumes (detected per-device)
    var storageVolumes: [StorageVolume] = []

    struct StorageVolume: Identifiable {
        let name: String
        let path: String
        let icon: String
        var id: String { path }
    }

    // Bookmarks
    var bookmarks: [Bookmark] = Bookmark.builtIn + AppState.loadCustomBookmarks()

    // View options
    var sortOrder: SortOrder = .name
    var sortAscending = true
    var showHiddenFiles = false

    // Services
    var deviceManager: DeviceManager
    let transferManager: TransferManager
    let cache: DirectoryCache
    let adbService: ADBService

    enum SortOrder: String, CaseIterable {
        case name = "Name"
        case size = "Size"
        case date = "Date"
    }

    init() {
        let adb = ADBService()
        let cache = DirectoryCache()
        self.adbService = adb
        self.cache = cache
        self.deviceManager = DeviceManager(adbService: adb, cache: cache)
        self.transferManager = TransferManager(adbService: adb, cache: cache)
    }

    var canGoBack: Bool { historyIndex > 0 }
    var canGoForward: Bool { historyIndex < pathHistory.count - 1 }
    var canGoUp: Bool { currentPath != "/" }

    var pathComponents: [(name: String, path: String)] {
        var components: [(String, String)] = []
        var path = ""
        for part in currentPath.split(separator: "/") {
            path += "/\(part)"
            components.append((String(part), path))
        }
        if components.isEmpty {
            components.append(("/", "/"))
        }
        return components
    }

    var sortedFiles: [AndroidFile] {
        var files = currentFiles
        if !showHiddenFiles {
            files = files.filter { !$0.isHidden }
        }

        files.sort { a, b in
            // Directories and navigable symlinks first
            if a.isNavigable != b.isNavigable {
                return a.isNavigable
            }
            let result: Bool
            switch sortOrder {
            case .name:
                result = a.name.localizedStandardCompare(b.name) == .orderedAscending
            case .size:
                result = a.size < b.size
            case .date:
                result = (a.modifiedDate ?? .distantPast) < (b.modifiedDate ?? .distantPast)
            }
            return sortAscending ? result : !result
        }
        return files
    }

    // MARK: - Storage Detection

    func detectStorageVolumes() async {
        guard let device = deviceManager.selectedDevice else {
            storageVolumes = []
            return
        }

        do {
            // List /storage/ to find all mounted volumes
            let output = try await adbService.shellCommand(device: device.serial, command: "ls -1 /storage/")
            var volumes: [StorageVolume] = []
            let entries = output.components(separatedBy: "\n").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }

            // These are all aliases for internal storage, not real SD cards
            let internalAliases: Set<String> = ["emulated", "self", "sdcard0"]

            for entry in entries {
                if internalAliases.contains(entry) {
                    if !volumes.contains(where: { $0.name == "Internal Storage" }) {
                        volumes.append(StorageVolume(name: "Internal Storage", path: "/sdcard", icon: "internaldrive"))
                    }
                } else {
                    let path = "/storage/\(entry)"
                    volumes.append(StorageVolume(name: "SD Card (\(entry))", path: path, icon: "sdcard"))
                }
            }

            // Fallback: always ensure internal storage is listed
            if volumes.isEmpty {
                volumes.append(StorageVolume(name: "Internal Storage", path: "/sdcard", icon: "internaldrive"))
            }

            storageVolumes = volumes
        } catch {
            storageVolumes = [StorageVolume(name: "Internal Storage", path: "/sdcard", icon: "internaldrive")]
        }
    }

    // MARK: - Navigation

    func navigateTo(path: String) async {
        guard let device = deviceManager.selectedDevice else { return }

        isLoading = true
        selectedFileIDs.removeAll()
        errorMessage = nil

        // Check cache first
        if let cached = await cache.get(device: device.serial, path: path) {
            currentFiles = cached
            updateNavigation(to: path)
            isLoading = false
            return
        }

        do {
            let files = try await adbService.listDirectory(device: device.serial, path: path)
            await cache.set(device: device.serial, path: path, files: files)
            currentFiles = files
            updateNavigation(to: path)
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }

        isLoading = false
    }

    private func updateNavigation(to path: String) {
        if currentPath != path {
            // Trim forward history
            if historyIndex < pathHistory.count - 1 {
                pathHistory = Array(pathHistory[...historyIndex])
            }
            pathHistory.append(path)
            historyIndex = pathHistory.count - 1
            currentPath = path
        }
    }

    func navigateUp() async {
        let parent = (currentPath as NSString).deletingLastPathComponent
        if parent != currentPath {
            await navigateTo(path: parent)
        }
    }

    func goBack() async {
        guard canGoBack else { return }
        historyIndex -= 1
        let path = pathHistory[historyIndex]
        currentPath = path
        await loadCurrentPath()
    }

    func goForward() async {
        guard canGoForward else { return }
        historyIndex += 1
        let path = pathHistory[historyIndex]
        currentPath = path
        await loadCurrentPath()
    }

    func refresh() async {
        guard let device = deviceManager.selectedDevice else { return }
        await cache.invalidate(device: device.serial, path: currentPath)
        await loadCurrentPath()
    }

    private func loadCurrentPath() async {
        guard let device = deviceManager.selectedDevice else { return }

        isLoading = true
        errorMessage = nil

        if let cached = await cache.get(device: device.serial, path: currentPath) {
            currentFiles = cached
            isLoading = false
            return
        }

        do {
            let files = try await adbService.listDirectory(device: device.serial, path: currentPath)
            await cache.set(device: device.serial, path: currentPath, files: files)
            currentFiles = files
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }

        isLoading = false
    }

    // MARK: - File Operations

    func deleteFiles(_ files: [AndroidFile]) async {
        guard let device = deviceManager.selectedDevice else { return }
        for file in files {
            do {
                try await adbService.deleteFile(device: device.serial, path: file.path)
            } catch {
                errorMessage = "Failed to delete \(file.name): \(error.localizedDescription)"
                showError = true
                return
            }
        }
        await refresh()
    }

    func createDirectory(name: String) async {
        guard let device = deviceManager.selectedDevice else { return }
        let path = currentPath.hasSuffix("/") ? "\(currentPath)\(name)" : "\(currentPath)/\(name)"
        do {
            try await adbService.createDirectory(device: device.serial, path: path)
            await refresh()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    // MARK: - Bookmarks

    func addBookmark(name: String, path: String) {
        guard !bookmarks.contains(where: { $0.path == path }) else { return }
        let bookmark = Bookmark(name: name, path: path, icon: "folder.fill", isBuiltIn: false)
        bookmarks.append(bookmark)
        saveCustomBookmarks()
    }

    func removeBookmark(_ bookmark: Bookmark) {
        guard !bookmark.isBuiltIn else { return }
        bookmarks.removeAll { $0.path == bookmark.path }
        saveCustomBookmarks()
    }

    func moveBookmark(from source: IndexSet, to destination: Int) {
        bookmarks.move(fromOffsets: source, toOffset: destination)
        saveCustomBookmarks()
    }

    private func saveCustomBookmarks() {
        let custom = bookmarks.filter { !$0.isBuiltIn }
        if let data = try? JSONEncoder().encode(custom) {
            UserDefaults.standard.set(data, forKey: "customBookmarks")
        }
    }

    static func loadCustomBookmarks() -> [Bookmark] {
        guard let data = UserDefaults.standard.data(forKey: "customBookmarks"),
              let bookmarks = try? JSONDecoder().decode([Bookmark].self, from: data) else {
            return []
        }
        return bookmarks
    }
}
