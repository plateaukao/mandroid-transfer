import SwiftUI
import UniformTypeIdentifiers

struct SidebarView: View {
    @Environment(AppState.self) var appState
    @State private var isBookmarkDropTargeted = false

    var body: some View {
        List {
            deviceSection
            storageSection
            bookmarksSection
        }
        .listStyle(.sidebar)
        .navigationTitle("Mandroid")
    }

    @ViewBuilder
    private var deviceSection: some View {
        @Bindable var appState = appState

        Section {
            if appState.deviceManager.devices.isEmpty {
                Label("No devices connected", systemImage: "antenna.radiowaves.left.and.right.slash")
                    .foregroundStyle(.secondary)
            } else if appState.deviceManager.devices.count < 3 {
                ForEach(appState.deviceManager.devices) { device in
                    let isSelected = appState.deviceManager.selectedDevice == device
                    Button {
                        appState.deviceManager.selectedDevice = device
                    } label: {
                        deviceRow(device)
                    }
                    .buttonStyle(.plain)
                    .fontWeight(isSelected ? .semibold : .regular)
                }
                .onChange(of: appState.deviceManager.selectedDevice) { _, newDevice in
                    if newDevice != nil {
                        appState.searchText = ""
                        appState.showSearch = false
                        Task {
                            await appState.detectStorageVolumes()
                            await appState.navigateToDefaultFolder()
                        }
                    }
                }
            } else {
                Picker("Device", selection: $appState.deviceManager.selectedDevice) {
                    ForEach(appState.deviceManager.devices) { device in
                        deviceRow(device).tag(Optional(device))
                    }
                }
                .labelsHidden()
                .onChange(of: appState.deviceManager.selectedDevice) { _, newDevice in
                    if newDevice != nil {
                        appState.searchText = ""
                        appState.showSearch = false
                        Task {
                            await appState.detectStorageVolumes()
                            await appState.navigateToDefaultFolder()
                        }
                    }
                }
            }
        } header: {
            HStack {
                Text("Device")
                Spacer()
                Button {
                    Task { await appState.deviceManager.refreshDevices() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .help("Refresh device list")
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
    private var storageSection: some View {
        if !appState.storageVolumes.isEmpty {
            Section("Storage") {
                ForEach(appState.storageVolumes) { volume in
                    storageRow(volume)
                }
            }
        }
    }

    private func storageRow(_ volume: AppState.StorageVolume) -> some View {
        let isActive = appState.currentPath.hasPrefix(volume.path)
        return Button {
            Task { await appState.navigateTo(path: volume.path) }
        } label: {
            Label(volume.name, systemImage: volume.icon)
        }
        .buttonStyle(.plain)
        .fontWeight(isActive ? .semibold : .regular)
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

            if isBookmarkDropTargeted {
                Label("Drop to add bookmark", systemImage: "plus.circle")
                    .foregroundStyle(.secondary)
                    .font(.caption)
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
        let paths = appState.draggedPaths
        guard !paths.isEmpty else { return false }
        for path in paths where path.hasPrefix("/") {
            let name = (path as NSString).lastPathComponent
            appState.addBookmark(name: name, path: path)
        }
        appState.draggedPaths = []
        return true
    }
}
