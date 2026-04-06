import Foundation

struct Bookmark: Identifiable, Codable, Hashable {
    let name: String
    let path: String
    let icon: String
    let isBuiltIn: Bool

    var id: String { path }

    static let builtIn: [Bookmark] = [
        Bookmark(name: "Download", path: "/sdcard/Download", icon: "arrow.down.circle", isBuiltIn: true),
        Bookmark(name: "DCIM", path: "/sdcard/DCIM", icon: "camera", isBuiltIn: true),
        Bookmark(name: "Documents", path: "/sdcard/Documents", icon: "doc", isBuiltIn: true),
        Bookmark(name: "Music", path: "/sdcard/Music", icon: "music.note", isBuiltIn: true),
        Bookmark(name: "Pictures", path: "/sdcard/Pictures", icon: "photo", isBuiltIn: true),
        Bookmark(name: "Movies", path: "/sdcard/Movies", icon: "film", isBuiltIn: true),
    ]
}
