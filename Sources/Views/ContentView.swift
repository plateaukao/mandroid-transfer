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
        .navigationTitle(appState.deviceManager.selectedDevice.map { "Mandroid — \($0.serial)" } ?? "Mandroid")
        .task {
            await appState.checkADBAvailability()
            await appState.deviceManager.refreshDevices()
            if appState.deviceManager.selectedDevice != nil {
                await appState.detectStorageVolumes()
                await appState.navigateToDefaultFolder()
            }
        }
        .sheet(isPresented: Binding(
            get: { appState.showADBSetup },
            set: { appState.showADBSetup = $0 }
        )) {
            ADBSetupView()
                .environment(appState)
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
