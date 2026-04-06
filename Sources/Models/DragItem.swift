import SwiftUI
import UniformTypeIdentifiers

// MARK: - Single file Transferable (used by .draggable for internal bookmark drops)

struct DragItem: Transferable, Sendable {
    let fileName: String
    let remotePath: String
    let deviceSerial: String
    let isDirectory: Bool
    let transferManager: TransferManager

    static var transferRepresentation: some TransferRepresentation {
        // Plain text path — used for internal drops (bookmarks sidebar)
        DataRepresentation(exportedContentType: .utf8PlainText) { item in
            Data(item.remotePath.utf8)
        }
        // File export — used for Finder drag-out (triggers actual pull)
        FileRepresentation(exportedContentType: .data) { item in
            let url = try await item.transferManager.pullToTemporaryLocation(
                device: item.deviceSerial,
                remotePath: item.remotePath
            )
            return SentTransferredFile(url, allowAccessingOriginalFile: true)
        }
    }
}

// MARK: - NSFilePromiseProvider delegate for multi-file drag to Finder

@MainActor
final class ADBFilePromiseDelegate: NSObject, NSFilePromiseProviderDelegate, Sendable {
    let remotePath: String
    let deviceSerial: String
    let transferManager: TransferManager

    init(remotePath: String, deviceSerial: String, transferManager: TransferManager) {
        self.remotePath = remotePath
        self.deviceSerial = deviceSerial
        self.transferManager = transferManager
    }

    nonisolated func filePromiseProvider(_ filePromiseProvider: NSFilePromiseProvider, fileNameForType fileType: String) -> String {
        (remotePath as NSString).lastPathComponent
    }

    nonisolated func filePromiseProvider(
        _ filePromiseProvider: NSFilePromiseProvider,
        writePromiseTo url: URL,
        completionHandler: @escaping @Sendable (Error?) -> Void
    ) {
        let remotePath = self.remotePath
        let deviceSerial = self.deviceSerial
        let transferManager = self.transferManager

        Task { @MainActor in
            do {
                let tempURL = try await transferManager.pullToTemporaryLocation(
                    device: deviceSerial,
                    remotePath: remotePath
                )
                try FileManager.default.moveItem(at: tempURL, to: url)
                completionHandler(nil)
            } catch {
                completionHandler(error)
            }
        }
    }

    nonisolated func operationQueue(for filePromiseProvider: NSFilePromiseProvider) -> OperationQueue {
        .main
    }
}
