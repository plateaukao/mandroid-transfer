import Foundation

enum TransferDirection: Sendable {
    case push
    case pull
}

enum TransferStatus: Sendable {
    case inProgress
    case completed
    case failed
    case cancelled
}

@Observable
@MainActor
final class TransferTask: Identifiable {
    let id = UUID()
    let direction: TransferDirection
    let remotePath: String
    let localPath: String
    let fileName: String
    var progress: Double = 0
    var bytesTransferred: Int64 = 0
    var totalBytes: Int64 = 0
    var status: TransferStatus = .inProgress
    var error: String?
    let startTime = Date()

    nonisolated var isCancellable: Bool { true }

    init(direction: TransferDirection, remotePath: String, localPath: String, fileName: String, totalBytes: Int64 = 0) {
        self.direction = direction
        self.remotePath = remotePath
        self.localPath = localPath
        self.fileName = fileName
        self.totalBytes = totalBytes
    }
}
