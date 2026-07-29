import SwiftUI

struct ClipRow: View {
    @EnvironmentObject var store: ClipboardStore
    let clip: Clip
    let isExpanded: Bool
    let onToggleExpand: () -> Void

    @State private var editedContent: String = ""
    @State private var isEditing = false
    @State private var showQR = false

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
        let adapted = NSMutableAttributedString(attributedString: attributed)
        let fullRange = NSRange(location: 0, length: adapted.length)
        adapted.enumerateAttribute(.foregroundColor, in: fullRange) { value, range, _ in
            // RTF hardcodes the source app's text color (usually black, or white
            // from dark-themed apps). Either extreme is invisible against one of
            // the popover's appearances, so remap it to the adaptive label color.
            // Genuinely colored text (e.g. syntax highlighting) is left alone.
            guard let color = (value as? NSColor)?.usingColorSpace(.sRGB) else {
                if value == nil {
                    adapted.addAttribute(.foregroundColor, value: NSColor.labelColor, range: range)
                }
                return
            }
            let isGrayish = abs(color.redComponent - color.greenComponent) < 0.1
                && abs(color.greenComponent - color.blueComponent) < 0.1
            if isGrayish && (color.brightnessComponent < 0.3 || color.brightnessComponent > 0.8) {
                adapted.addAttribute(.foregroundColor, value: NSColor.labelColor, range: range)
            }
        }
        return AttributedString(adapted)
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
        .popover(isPresented: $showQR, arrowEdge: .bottom) {
            QRCodePopover(text: clip.content)
                .environmentObject(store)
        }
        .onTapGesture {
            isEditing = false
            onToggleExpand()
        }
        .contextMenu {
            Button("Copy") { store.copyToClipboard(clip) }
            if clip.kind != .image {
                Button("Show QR Code") { showQR = true }
            }
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
            if clip.kind != .image {
                actionButton("qrcode", "QR Code") {
                    showQR = true
                }
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

struct QRCodePopover: View {
    @EnvironmentObject var store: ClipboardStore
    let text: String
    @State private var copied = false

    var body: some View {
        VStack(spacing: 10) {
            if let qrImage = QRCode.image(for: text) {
                Image(nsImage: qrImage)
                    .interpolation(.none)
                    .resizable()
                    .frame(width: 180, height: 180)
                    .padding(10) // quiet zone so scanners can lock on
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                Button {
                    if let png = QRCode.pngData(for: text) {
                        store.copyGeneratedImage(png)
                        copied = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { copied = false }
                    }
                } label: {
                    Label(copied ? "Copied" : "Copy QR Image",
                          systemImage: copied ? "checkmark" : "doc.on.doc")
                        .font(.caption)
                }
            } else {
                Label("Too much text for a QR code (max \(QRCode.maxBytes) bytes)",
                      systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 180)
            }
        }
        .padding(14)
    }
}
