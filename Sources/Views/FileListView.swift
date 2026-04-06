import SwiftUI
import UniformTypeIdentifiers

struct FileListView: View {
    @Environment(AppState.self) var appState
    @State private var isDropTargeted = false
    @State private var showNewFolderAlert = false
    @State private var newFolderName = ""
    @State private var showDeleteConfirmation = false
    @State private var filesToDelete: [AndroidFile] = []

    var body: some View {
        @Bindable var appState = appState

        VStack(spacing: 0) {
            // Breadcrumb path bar
            breadcrumbBar

            Divider()

            // File list
            if appState.deviceManager.selectedDevice == nil {
                noDeviceView
            } else if appState.isLoading && appState.currentFiles.isEmpty {
                ProgressView("Loading…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if appState.sortedFiles.isEmpty && !appState.isLoading {
                emptyDirectoryView
            } else {
                fileList
            }
        }
        .toolbar {
            toolbarContent
        }
        .overlay {
            if isDropTargeted {
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(Color.accentColor, style: StrokeStyle(lineWidth: 3, dash: [8]))
                    .background(Color.accentColor.opacity(0.05))
                    .padding(4)
            }
        }
        .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
            handleFileDrop(providers)
        }
        .alert("New Folder", isPresented: $showNewFolderAlert) {
            TextField("Folder name", text: $newFolderName)
            Button("Create") {
                let name = newFolderName
                newFolderName = ""
                Task { await appState.createDirectory(name: name) }
            }
            Button("Cancel", role: .cancel) { newFolderName = "" }
        }
        .confirmationDialog("Delete \(filesToDelete.count) item(s)?", isPresented: $showDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                let files = filesToDelete
                filesToDelete = []
                Task { await appState.deleteFiles(files) }
            }
        } message: {
            Text("This cannot be undone.")
        }
        .onReceive(NotificationCenter.default.publisher(for: .newFolderRequested)) { _ in
            showNewFolderAlert = true
        }
        .onDeleteCommand {
            let selected = appState.sortedFiles.filter { appState.selectedFileIDs.contains($0.id) }
            if !selected.isEmpty {
                filesToDelete = selected
                showDeleteConfirmation = true
            }
        }
    }

    // MARK: - Breadcrumb

    private var breadcrumbBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                Button {
                    Task { await appState.navigateTo(path: "/") }
                } label: {
                    Image(systemName: "externaldrive")
                }
                .buttonStyle(.plain)

                ForEach(Array(appState.pathComponents.enumerated()), id: \.offset) { index, component in
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)

                    Button(component.name) {
                        Task { await appState.navigateTo(path: component.path) }
                    }
                    .buttonStyle(.plain)
                    .fontWeight(index == appState.pathComponents.count - 1 ? .semibold : .regular)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
        .background(.bar)
    }

    // MARK: - Column Header

    private var columnHeader: some View {
        HStack(spacing: 10) {
            // Spacer for icon column
            Color.clear.frame(width: 20, height: 1)

            sortButton(label: "Name", order: .name)

            Spacer()

            sortButton(label: "Size", order: .size)
                .frame(width: 80, alignment: .trailing)

            sortButton(label: "Date Modified", order: .date)
                .frame(width: 120, alignment: .trailing)
        }
        .font(.callout)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 24)
        .padding(.vertical, 3)
        .fixedSize(horizontal: false, vertical: true)
        .background(.bar)
    }

    private func sortButton(label: String, order: AppState.SortOrder) -> some View {
        Button {
            if appState.sortOrder == order {
                appState.sortAscending.toggle()
            } else {
                appState.sortOrder = order
                appState.sortAscending = true
            }
        } label: {
            HStack(spacing: 3) {
                Text(label)
                if appState.sortOrder == order {
                    Image(systemName: appState.sortAscending ? "chevron.up" : "chevron.down")
                        .font(.caption2)
                }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - File List

    private var fileList: some View {
        VStack(spacing: 0) {
            columnHeader
            Divider()
            List(selection: Binding(
                get: { appState.selectedFileIDs },
                set: { appState.selectedFileIDs = $0 }
            )) {
                ForEach(appState.sortedFiles) { file in
                    FileRowView(file: file)
                        .tag(file.id)
                        .contextMenu {
                            fileContextMenu(for: file)
                        }
                }
            }
            .listStyle(.inset(alternatesRowBackgrounds: true))
            .contextMenu {
                backgroundContextMenu
            }
            .onKeyPress(.return) {
                openSelected()
                return .handled
            }
        }
    }

    private func openSelected() {
        guard let fileID = appState.selectedFileIDs.first,
              let file = appState.sortedFiles.first(where: { $0.id == fileID }) else { return }
        handleDoubleTap(file)
    }

    private func makeDragProvider(for file: AndroidFile) -> NSItemProvider {
        guard let device = appState.deviceManager.selectedDevice?.serial else {
            return NSItemProvider()
        }

        // If the dragged file is part of a multi-selection, drag all selected files
        let filesToDrag: [AndroidFile]
        if appState.selectedFileIDs.contains(file.id) && appState.selectedFileIDs.count > 1 {
            filesToDrag = appState.sortedFiles.filter { appState.selectedFileIDs.contains($0.id) }
        } else {
            filesToDrag = [file]
        }

        let provider = NSItemProvider()
        let transferManager = appState.transferManager

        // Register a file representation for each file to drag
        for dragFile in filesToDrag {
            let remotePath = dragFile.path
            let fileName = dragFile.name
            provider.registerFileRepresentation(
                forTypeIdentifier: UTType.data.identifier,
                fileOptions: [],
                visibility: .all
            ) { completion in
                Task { @MainActor in
                    do {
                        let url = try await transferManager.pullToTemporaryLocation(
                            device: device,
                            remotePath: remotePath
                        )
                        completion(url, true, nil)
                    } catch {
                        completion(nil, false, error)
                    }
                }
                return nil
            }
            provider.suggestedName = fileName
        }

        // Also register plain text path for internal bookmark drops
        provider.registerObject(file.path as NSString, visibility: .all)

        return provider
    }

    // MARK: - Empty States

    private var noDeviceView: some View {
        VStack(spacing: 16) {
            Image(systemName: "smartphone.slash")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("No Android Device Connected")
                .font(.title2)
                .fontWeight(.medium)
            Text("Connect an Android device with USB debugging enabled")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyDirectoryView: some View {
        VStack(spacing: 12) {
            Image(systemName: "folder")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)
            Text("Empty Folder")
                .foregroundStyle(.secondary)
            Text("Drop files here to transfer")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .navigation) {
            Button {
                Task { await appState.goBack() }
            } label: {
                Image(systemName: "chevron.left")
            }
            .disabled(!appState.canGoBack)

            Button {
                Task { await appState.goForward() }
            } label: {
                Image(systemName: "chevron.right")
            }
            .disabled(!appState.canGoForward)
        }

        ToolbarItem {
            Button {
                Task { await appState.navigateUp() }
            } label: {
                Image(systemName: "arrow.up")
            }
            .disabled(!appState.canGoUp)
            .keyboardShortcut(.delete, modifiers: .command)
        }

        ToolbarItem {
            Button {
                Task { await appState.refresh() }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .keyboardShortcut("r", modifiers: .command)
        }

        ToolbarItem {
            Toggle(isOn: Binding(
                get: { appState.showHiddenFiles },
                set: { appState.showHiddenFiles = $0 }
            )) {
                Image(systemName: "eye")
            }
            .help("Show hidden files")
        }

        ToolbarItem {
            if appState.isLoading {
                ProgressView()
                    .controlSize(.small)
            }
        }
    }

    // MARK: - Context Menus

    /// Returns the right-clicked file plus any other selected files.
    private func affectedFiles(for file: AndroidFile) -> [AndroidFile] {
        if appState.selectedFileIDs.contains(file.id) && appState.selectedFileIDs.count > 1 {
            return appState.sortedFiles.filter { appState.selectedFileIDs.contains($0.id) }
        }
        return [file]
    }

    @ViewBuilder
    private func fileContextMenu(for file: AndroidFile) -> some View {
        let files = affectedFiles(for: file)
        let count = files.count

        if count == 1, file.isNavigable {
            Button("Open") {
                Task { await appState.navigateTo(path: file.path) }
            }
            Divider()
        }

        Button(count > 1 ? "Pull \(count) Items to Mac…" : "Pull to Mac…") {
            pullFilesToMac(files)
        }

        if count == 1 {
            Button("Copy Path") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(file.path, forType: .string)
            }
        }

        Divider()

        Button(count > 1 ? "Delete \(count) Items" : "Delete", role: .destructive) {
            filesToDelete = files
            showDeleteConfirmation = true
        }
    }

    @ViewBuilder
    private var backgroundContextMenu: some View {
        Button("Push File Here…") {
            pushFileFromMac()
        }

        Button("New Folder…") {
            showNewFolderAlert = true
        }

        Divider()

        Button("Refresh") {
            Task { await appState.refresh() }
        }
    }

    // MARK: - Actions

    private func handleDoubleTap(_ file: AndroidFile) {
        if file.isNavigable {
            Task { await appState.navigateTo(path: file.path) }
        } else {
            pullFilesToMac([file])
        }
    }

    private func pullFilesToMac(_ files: [AndroidFile]) {
        guard let device = appState.deviceManager.selectedDevice else { return }

        if files.count == 1, let file = files.first {
            // Single file: use save panel
            let panel = NSSavePanel()
            panel.nameFieldStringValue = file.name
            panel.canCreateDirectories = true
            guard panel.runModal() == .OK, let url = panel.url else { return }
            Task {
                await appState.transferManager.pullFile(
                    device: device.serial,
                    remotePath: file.path,
                    toLocal: url.path
                )
            }
        } else {
            // Multiple files: pick a destination folder
            let panel = NSOpenPanel()
            panel.canChooseFiles = false
            panel.canChooseDirectories = true
            panel.canCreateDirectories = true
            panel.prompt = "Save Here"
            guard panel.runModal() == .OK, let folder = panel.url else { return }
            for file in files {
                let dest = folder.appendingPathComponent(file.name).path
                Task {
                    await appState.transferManager.pullFile(
                        device: device.serial,
                        remotePath: file.path,
                        toLocal: dest
                    )
                }
            }
        }
    }

    private func pushFileFromMac() {
        guard let device = appState.deviceManager.selectedDevice else { return }

        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true

        guard panel.runModal() == .OK else { return }

        for url in panel.urls {
            let remotePath = appState.currentPath.hasSuffix("/")
                ? "\(appState.currentPath)\(url.lastPathComponent)"
                : "\(appState.currentPath)/\(url.lastPathComponent)"

            Task {
                await appState.transferManager.pushFile(
                    device: device.serial,
                    localPath: url.path,
                    toRemote: remotePath
                )
                await appState.refresh()
            }
        }
    }

    private func handleFileDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let device = appState.deviceManager.selectedDevice else { return false }
        let currentPath = appState.currentPath
        let state = appState

        for provider in providers {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier) { data, _ in
                guard let data = data as? Data,
                      let url = URL(dataRepresentation: data, relativeTo: nil) else { return }

                let remotePath = currentPath.hasSuffix("/")
                    ? "\(currentPath)\(url.lastPathComponent)"
                    : "\(currentPath)/\(url.lastPathComponent)"

                Task { @MainActor in
                    await state.transferManager.pushFile(
                        device: device.serial,
                        localPath: url.path,
                        toRemote: remotePath
                    )
                    await state.refresh()
                }
            }
        }
        return true
    }
}
