import SwiftUI

struct ContentView: View {
    @Environment(AppState.self) var appState

    var body: some View {
        VStack(spacing: 0) {
            NavigationSplitView {
                SidebarView()
                    .navigationSplitViewColumnWidth(min: 200, ideal: 240, max: 340)
            } detail: {
                FileListView()
            }

            if !appState.transferManager.activeTasks.isEmpty || !appState.transferManager.completedTasks.isEmpty {
                Divider()
                TransferStatusView()
            }
        }
        .frame(minWidth: 700, minHeight: 450)
        .task {
            appState.deviceManager.startPolling()
            // Wait briefly for device discovery, then load
            try? await Task.sleep(for: .seconds(1))
            if appState.deviceManager.selectedDevice != nil {
                await appState.navigateTo(path: "/sdcard")
            }
        }
        .alert("Error", isPresented: Binding(
            get: { appState.showError },
            set: { appState.showError = $0 }
        )) {
            Button("OK") { appState.showError = false }
        } message: {
            Text(appState.errorMessage ?? "Unknown error")
        }
    }
}
