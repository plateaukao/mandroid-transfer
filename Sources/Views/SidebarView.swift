import SwiftUI
import UniformTypeIdentifiers

struct SidebarView: View {
    @Environment(AppState.self) var appState
    @State private var isBookmarkDropTargeted = false

    var body: some View {
        List {
            deviceSection
            bookmarksSection
        }
        .listStyle(.sidebar)
        .navigationTitle("Mandroid")
    }

    @ViewBuilder
    private var deviceSection: some View {
        @Bindable var appState = appState

        Section("Device") {
            if appState.deviceManager.devices.isEmpty {
                Label("No devices connected", systemImage: "antenna.radiowaves.left.and.right.slash")
                    .foregroundStyle(.secondary)
            } else {
                Picker("Device", selection: $appState.deviceManager.selectedDevice) {
                    ForEach(appState.deviceManager.devices) { device in
                        deviceRow(device).tag(Optional(device))
                    }
                }
                .labelsHidden()
                .onChange(of: appState.deviceManager.selectedDevice) { _, newDevice in
                    if newDevice != nil {
                        Task { await appState.navigateTo(path: "/sdcard") }
                    }
                }
            }
        }
    }

    private func deviceRow(_ device: DeviceInfo) -> some View {
        HStack {
            Image(systemName: device.isOnline ? "smartphone" : "smartphone.slash")
            Text(device.serial)
            if !device.isOnline {
                Text("(\(device.state))")
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var bookmarksSection: some View {
        Section("Bookmarks") {
            ForEach(appState.bookmarks) { bookmark in
                bookmarkRow(bookmark)
            }
            .onMove { source, destination in
                appState.moveBookmark(from: source, to: destination)
            }
        }
        .onDrop(of: [.utf8PlainText], isTargeted: $isBookmarkDropTargeted) { providers in
            handleBookmarkDrop(providers)
        }
    }

    private func bookmarkRow(_ bookmark: Bookmark) -> some View {
        let isActive = appState.currentPath == bookmark.path
        return Button {
            Task { await appState.navigateTo(path: bookmark.path) }
        } label: {
            Label(bookmark.name, systemImage: bookmark.icon)
        }
        .buttonStyle(.plain)
        .fontWeight(isActive ? .semibold : .regular)
        .contextMenu {
            if !bookmark.isBuiltIn {
                Button("Remove Bookmark", role: .destructive) {
                    appState.removeBookmark(bookmark)
                }
            }
        }
    }

    private func handleBookmarkDrop(_ providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            provider.loadItem(forTypeIdentifier: UTType.utf8PlainText.identifier) { data, _ in
                guard let data = data as? Data,
                      let path = String(data: data, encoding: .utf8),
                      path.hasPrefix("/") else { return }

                let name = (path as NSString).lastPathComponent
                Task { @MainActor in
                    appState.addBookmark(name: name, path: path)
                }
            }
        }
        return true
    }
}
