import Foundation

struct AndroidFile: Identifiable, Hashable, Sendable {
    let name: String
    let path: String
    let isDirectory: Bool
    let isSymlink: Bool
    let symlinkTarget: String?
    let permissions: String
    let owner: String
    let group: String
    let size: Int64
    let modifiedDate: Date?

    var id: String { path }

    /// True for directories or symlinks that point to directories.
    /// Symlinks to directories show permissions starting with 'l' but their target is a directory.
    /// We treat all symlinks as potentially navigable since we can't know the target type without stat.
    var isNavigable: Bool { isDirectory || isSymlink }

    var fileExtension: String {
        (name as NSString).pathExtension.lowercased()
    }

    var isHidden: Bool {
        name.hasPrefix(".")
    }

    var formattedSize: String {
        if isDirectory { return "—" }
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }

    var formattedDate: String {
        guard let date = modifiedDate else { return "—" }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.string(from: date)
    }

    var iconName: String {
        if isDirectory { return "folder.fill" }
        if isSymlink { return "arrow.triangle.turn.up.right.diamond" }
        switch fileExtension {
        case "jpg", "jpeg", "png", "gif", "bmp", "webp", "heic":
            return "photo"
        case "mp4", "mkv", "avi", "mov", "wmv", "flv":
            return "film"
        case "mp3", "aac", "flac", "wav", "ogg", "m4a":
            return "music.note"
        case "pdf":
            return "doc.richtext"
        case "txt", "log", "csv", "json", "xml":
            return "doc.text"
        case "zip", "tar", "gz", "7z", "rar":
            return "doc.zipper"
        case "apk":
            return "app.badge"
        default:
            return "doc"
        }
    }
}
