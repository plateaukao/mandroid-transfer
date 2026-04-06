import Foundation

@Observable
@MainActor
final class TransferManager {
    var activeTasks: [TransferTask] = []
    var completedTasks: [TransferTask] = []

    private let adbService: ADBService
    private let cache: DirectoryCache

    init(adbService: ADBService, cache: DirectoryCache) {
        self.adbService = adbService
        self.cache = cache
    }

    func pullFile(device: String, remotePath: String, toLocal localPath: String) async {
        let fileName = (remotePath as NSString).lastPathComponent
        let task = TransferTask(direction: .pull, remotePath: remotePath, localPath: localPath, fileName: fileName)
        activeTasks.append(task)

        do {
            try await adbService.pull(device: device, remotePath: remotePath, localPath: localPath) { [weak task] progress in
                Task { @MainActor in
                    task?.progress = progress
                }
            }
            task.status = .completed
            task.progress = 1.0
        } catch {
            task.status = .failed
            task.error = error.localizedDescription
        }

        moveToCompleted(task)
    }

    func pushFile(device: String, localPath: String, toRemote remotePath: String) async {
        let fileName = (localPath as NSString).lastPathComponent
        let task = TransferTask(direction: .push, remotePath: remotePath, localPath: localPath, fileName: fileName)
        activeTasks.append(task)

        do {
            try await adbService.push(device: device, localPath: localPath, remotePath: remotePath) { [weak task] progress in
                Task { @MainActor in
                    task?.progress = progress
                }
            }
            task.status = .completed
            task.progress = 1.0
            // Invalidate cache for the target directory
            let parentDir = (remotePath as NSString).deletingLastPathComponent
            await cache.invalidate(device: device, path: parentDir)
        } catch {
            task.status = .failed
            task.error = error.localizedDescription
        }

        moveToCompleted(task)
    }

    func pullToTemporaryLocation(device: String, remotePath: String) async throws -> URL {
        let fileName = (remotePath as NSString).lastPathComponent
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let localURL = tempDir.appendingPathComponent(fileName)

        let task = TransferTask(direction: .pull, remotePath: remotePath, localPath: localURL.path, fileName: fileName)
        activeTasks.append(task)

        do {
            try await adbService.pull(device: device, remotePath: remotePath, localPath: localURL.path) { [weak task] progress in
                Task { @MainActor in
                    task?.progress = progress
                }
            }
            task.status = .completed
            task.progress = 1.0
            moveToCompleted(task)
            return localURL
        } catch {
            task.status = .failed
            task.error = error.localizedDescription
            moveToCompleted(task)
            throw error
        }
    }

    func clearCompleted() {
        completedTasks.removeAll()
    }

    private func moveToCompleted(_ task: TransferTask) {
        activeTasks.removeAll { $0.id == task.id }
        completedTasks.insert(task, at: 0)
    }
}
