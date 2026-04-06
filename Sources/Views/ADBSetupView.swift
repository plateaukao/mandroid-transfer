import SwiftUI
import AppKit

struct ADBSetupView: View {
    @Environment(AppState.self) var appState
    @State private var pathText = ""
    @State private var errorText: String?

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "terminal")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)

            Text("ADB Not Found")
                .font(.headline)

            Text("Mandroid Transfer requires the Android Debug Bridge (ADB) tool to communicate with your device. Please locate the **adb** binary on your system.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 360)

            HStack {
                TextField("Path to adb", text: $pathText)
                    .textFieldStyle(.roundedBorder)

                Button("Browse…") {
                    browseForADB()
                }
            }
            .padding(.horizontal)

            if let errorText {
                Text(errorText)
                    .foregroundStyle(.red)
                    .font(.caption)
            }

            HStack {
                Link("Install Android SDK", destination: URL(string: "https://developer.android.com/studio")!)
                    .font(.caption)

                Spacer()

                Button("Use Path") {
                    Task { await applyPath() }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(pathText.isEmpty)
            }
            .padding(.horizontal)
        }
        .padding(24)
        .frame(width: 440)
        .interactiveDismissDisabled()
    }

    private func browseForADB() {
        let panel = NSOpenPanel()
        panel.title = "Select ADB Binary"
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.showsHiddenFiles = true
        panel.directoryURL = URL(fileURLWithPath: "/usr/local/bin")

        if panel.runModal() == .OK, let url = panel.url {
            pathText = url.path
        }
    }

    private func applyPath() async {
        let path = pathText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard FileManager.default.isExecutableFile(atPath: path) else {
            errorText = "File is not executable or does not exist."
            return
        }
        errorText = nil
        await appState.setADBPath(path)
    }
}
