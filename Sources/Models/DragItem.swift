import SwiftUI
import UniformTypeIdentifiers

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
