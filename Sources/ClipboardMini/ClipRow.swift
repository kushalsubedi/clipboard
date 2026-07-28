import SwiftUI

struct ClipRow: View {
    @EnvironmentObject var store: ClipboardStore
    let clip: Clip
    let isExpanded: Bool
    let onToggleExpand: () -> Void

    @State private var editedContent: String = ""
    @State private var isEditing = false

    private var relativeTime: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: clip.createdAt, relativeTo: Date())
    }

    private var preview: String {
        clip.content.replacingOccurrences(of: "\n", with: " ")
    }

    private var thumbnail: NSImage? {
        guard clip.kind == .image, let data = clip.data else { return nil }
        return NSImage(data: data)
    }

    private var richText: AttributedString? {
        guard clip.kind == .rtf, let data = clip.data,
              let attributed = NSAttributedString(rtf: data, documentAttributes: nil) else { return nil }
        return AttributedString(attributed)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 8) {
                if clip.pinned {
                    Image(systemName: "pin.fill")
                        .font(.caption2)
                        .foregroundStyle(.tint)
                }
                clipContent
                    .frame(maxWidth: .infinity, alignment: .leading)
                VStack(alignment: .trailing, spacing: 2) {
                    Text(relativeTime)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    if clip.kind != .text {
                        Image(systemName: clip.kind == .image ? "photo" : "textformat")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if isExpanded {
                if isEditing {
                    editingControls
                } else {
                    actionRow
                }
            }
        }
        .padding(10)
        .background(Color.primary.opacity(isExpanded ? 0.08 : 0.04))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isExpanded ? Color.accentColor.opacity(0.4) : .clear, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            isEditing = false
            onToggleExpand()
        }
        .contextMenu {
            Button("Copy") { store.copyToClipboard(clip) }
            Button(clip.pinned ? "Unpin" : "Pin") { store.togglePin(clip) }
            Button("Delete", role: .destructive) { store.deleteClip(clip) }
        }
    }

    @ViewBuilder
    private var clipContent: some View {
        switch clip.kind {
        case .image:
            if let thumbnail {
                Image(nsImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: isExpanded ? 260 : 56, alignment: .leading)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            } else {
                Text(preview)
                    .font(.system(.callout, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
        case .rtf:
            if isExpanded, let richText {
                Text(richText)
                    .textSelection(.enabled)
            } else {
                Text(preview)
                    .font(.system(.callout, design: .rounded))
                    .lineLimit(3)
            }
        case .text:
            Text(isExpanded ? clip.content : preview)
                .font(.system(.callout, design: .monospaced))
                .lineLimit(isExpanded ? nil : 3)
        }
    }

    private var editingControls: some View {
        VStack(alignment: .trailing, spacing: 6) {
            TextEditor(text: $editedContent)
                .font(.system(.callout, design: .monospaced))
                .frame(minHeight: 80, maxHeight: 160)
                .padding(4)
                .background(Color.primary.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 6))

            HStack {
                Spacer()
                Button("Cancel") { isEditing = false }
                Button("Save") {
                    store.updateClip(clip, newContent: editedContent)
                    isEditing = false
                }
                .keyboardShortcut(.defaultAction)
            }
            .font(.caption)
        }
    }

    private var actionRow: some View {
        HStack(spacing: 14) {
            actionButton("doc.on.doc", "Copy") {
                store.copyToClipboard(clip)
            }
            if clip.kind == .text {
                actionButton("pencil", "Edit") {
                    editedContent = clip.content
                    isEditing = true
                }
            }
            actionButton(clip.pinned ? "pin.slash" : "pin", clip.pinned ? "Unpin" : "Pin") {
                store.togglePin(clip)
            }
            actionButton("trash", "Delete", role: .destructive) {
                store.deleteClip(clip)
            }
            Spacer()
        }
        .font(.caption)
    }

    @ViewBuilder
    private func actionButton(_ icon: String, _ label: String, role: ButtonRole? = nil, action: @escaping () -> Void) -> some View {
        Button(role: role, action: action) {
            Label(label, systemImage: icon)
                .labelStyle(.iconOnly)
        }
        .buttonStyle(.plain)
        .foregroundStyle(role == .destructive ? .red : .secondary)
        .help(label)
    }
}
