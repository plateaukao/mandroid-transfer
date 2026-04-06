import SwiftUI

struct FileRowView: View {
    let file: AndroidFile

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: file.iconName)
                .foregroundStyle(file.isDirectory ? .blue : .secondary)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(file.name)
                    .lineLimit(1)
                if let target = file.symlinkTarget {
                    Text("→ \(target)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            Text(file.formattedSize)
                .foregroundStyle(.secondary)
                .frame(width: 80, alignment: .trailing)
                .font(.callout)

            Text(file.formattedDate)
                .foregroundStyle(.secondary)
                .frame(width: 140, alignment: .trailing)
                .font(.callout)
        }
        .padding(.vertical, 2)
    }
}
