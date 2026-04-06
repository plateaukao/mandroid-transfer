import SwiftUI

struct TransferStatusView: View {
    @Environment(AppState.self) var appState

    var body: some View {
        VStack(spacing: 0) {
            if !appState.transferManager.activeTasks.isEmpty {
                ForEach(appState.transferManager.activeTasks) { task in
                    activeTaskRow(task)
                }
            }

            if !appState.transferManager.completedTasks.isEmpty {
                HStack {
                    let completed = appState.transferManager.completedTasks
                    let failed = completed.filter { $0.status == .failed }.count
                    let succeeded = completed.count - failed

                    if succeeded > 0 {
                        Label("\(succeeded) completed", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                    if failed > 0 {
                        Label("\(failed) failed", systemImage: "xmark.circle.fill")
                            .foregroundStyle(.red)
                    }

                    Spacer()

                    Button("Clear") {
                        appState.transferManager.clearCompleted()
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                }
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
            }
        }
        .background(.bar)
    }

    private func activeTaskRow(_ task: TransferTask) -> some View {
        HStack(spacing: 8) {
            Image(systemName: task.direction == .push ? "arrow.up.circle" : "arrow.down.circle")
                .foregroundStyle(task.direction == .push ? .blue : .green)

            Text(task.fileName)
                .lineLimit(1)
                .font(.caption)

            ProgressView(value: task.progress)
                .frame(maxWidth: 200)

            Text("\(Int(task.progress * 100))%")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 36, alignment: .trailing)

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
    }
}
