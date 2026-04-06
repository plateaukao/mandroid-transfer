import Foundation

struct DeviceInfo: Identifiable, Hashable, Sendable {
    let serial: String
    let state: String

    var id: String { serial }

    var isOnline: Bool { state == "device" }
}
