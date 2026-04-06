import SwiftUI

@main
struct MandroidTransferApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
        }
        .windowResizability(.contentMinSize)
        .defaultSize(width: 900, height: 600)
        .commands {
            CommandGroup(after: .newItem) {
                Button("New Folder…") {
                    NotificationCenter.default.post(name: .newFolderRequested, object: nil)
                }
                .keyboardShortcut("n", modifiers: [.command, .shift])
            }

            CommandMenu("Go") {
                Button("Back") {
                    Task { await appState.goBack() }
                }
                .keyboardShortcut("[", modifiers: .command)
                .disabled(!appState.canGoBack)

                Button("Forward") {
                    Task { await appState.goForward() }
                }
                .keyboardShortcut("]", modifiers: .command)
                .disabled(!appState.canGoForward)

                Button("Enclosing Folder") {
                    Task { await appState.navigateUp() }
                }
                .keyboardShortcut(.upArrow, modifiers: .command)
                .disabled(!appState.canGoUp)

                Divider()

                Button("Refresh") {
                    Task { await appState.refresh() }
                }
                .keyboardShortcut("r", modifiers: .command)
            }

            CommandMenu("View") {
                Toggle("Show Hidden Files", isOn: Binding(
                    get: { appState.showHiddenFiles },
                    set: { appState.showHiddenFiles = $0 }
                ))
                .keyboardShortcut(".", modifiers: [.command, .shift])

                Divider()

                Picker("Sort By", selection: Binding(
                    get: { appState.sortOrder },
                    set: { appState.sortOrder = $0 }
                )) {
                    ForEach(AppState.SortOrder.allCases, id: \.self) { order in
                        Text(order.rawValue).tag(order)
                    }
                }

                Toggle("Ascending", isOn: Binding(
                    get: { appState.sortAscending },
                    set: { appState.sortAscending = $0 }
                ))
            }
        }
    }
}

extension Notification.Name {
    static let newFolderRequested = Notification.Name("newFolderRequested")
}
