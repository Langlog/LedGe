import AppKit
import LedgeCore
import SwiftUI

struct LedgeRootView: View {
    @ObservedObject var model: AppModel
    let onDismiss: () -> Void
    let onOpenNote: () -> Void

    var body: some View {
        ZStack {
            if model.surface == .prompt {
                prompt
            } else if model.surface != .hidden {
                VStack(spacing: 0) {
                    toolbar
                    if model.surface == .files {
                        Divider().opacity(0.65)
                        FileShelfView(model: model)
                    } else if model.surface == .note {
                        Divider().opacity(0.65)
                        NoteView(model: model)
                    }
                }
                .ledgePanelSurface()
                .padding(2)
            }

            FileDropReceiver(
                isEnabled: model.isExternalDragActive,
                onTargeted: { targeted in
                    model.isDropTargeted = targeted
                    if targeted {
                        model.send(.externalFileDragEntered)
                    }
                },
                onDrop: { urls in
                    model.isExternalDragActive = false
                    model.send(.externalFileDragEntered)
                    return model.receiveExternalFileMove(urls)
                }
            )
        }
    }

    private var prompt: some View {
        Button(action: onOpenNote) {
            Image(systemName: "chevron.up")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(LedgeStyle.accentInk)
                .frame(
                    width: CompactPromptGeometry.size.width,
                    height: CompactPromptGeometry.size.height
                )
        }
        .buttonStyle(PromptButtonStyle())
        .background(.ultraThickMaterial)
        .clipShape(BottomEdgeTabShape())
        .contentShape(BottomEdgeTabShape())
        .overlay {
            BottomEdgeTabShape()
                .stroke(LedgeStyle.hairline, lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.15), radius: 11, y: -2)
        .accessibilityLabel("打开 Ledge 便签")
        .help("打开便签")
    }

    private var toolbar: some View {
        ZStack(alignment: .trailing) {
            HStack(spacing: 0) {
                toolButton(
                    title: "便签",
                    systemImage: "text.alignleft",
                    selected: model.surface == .note
                ) {
                    onOpenNote()
                }
                Divider()
                    .frame(height: 34)
                toolButton(
                    title: "文件移动",
                    systemImage: "tray.full",
                    selected: model.surface == .files
                ) {
                    model.send(.filesSelected)
                }
            }

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .semibold))
                    .frame(width: 30, height: 30)
                    .background(LedgeStyle.controlFill)
                    .clipShape(Circle())
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(LedgeStyle.secondaryInk)
            .help("隐藏 Ledge")
            .padding(.trailing, 14)
        }
        .frame(height: 62)
    }

    private func toolButton(
        title: String,
        systemImage: String,
        selected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Label(title, systemImage: systemImage)
                    .font(.system(size: 13, weight: .semibold))
                Capsule()
                    .fill(selected ? LedgeStyle.accent : Color.clear)
                    .frame(width: 24, height: 3)
            }
            .foregroundStyle(
                selected ? LedgeStyle.accentInk : LedgeStyle.secondaryInk
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(selected ? LedgeStyle.accentSoft : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .animation(.easeOut(duration: 0.07), value: selected)
    }
}

private struct BottomEdgeTabShape: Shape {
    func path(in rect: CGRect) -> Path {
        let radius = min(
            CompactPromptGeometry.topCornerRadius,
            min(rect.width / 2, rect.height)
        )
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + radius))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + radius, y: rect.minY),
            control: CGPoint(x: rect.minX, y: rect.minY)
        )
        path.addLine(to: CGPoint(x: rect.maxX - radius, y: rect.minY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY + radius),
            control: CGPoint(x: rect.maxX, y: rect.minY)
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

private struct PromptButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.88 : 1)
            .animation(
                .easeOut(duration: 0.055),
                value: configuration.isPressed
            )
    }
}

private struct FileShelfView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        Group {
            if model.resolvedItems.isEmpty {
                emptyState
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(model.resolvedItems) { resolved in
                            FileCard(model: model, resolved: resolved)
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 16)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            model.isDropTargeted
                ? LedgeStyle.accentSoft.opacity(0.75)
                : Color.clear
        )
        .overlay {
            if model.isDropTargeted {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(
                        LedgeStyle.accent,
                        style: StrokeStyle(lineWidth: 2, dash: [7, 5])
                    )
                    .padding(10)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 7) {
            Image(systemName: "arrow.down.doc")
                .font(.system(size: 27, weight: .light))
                .foregroundStyle(LedgeStyle.accentInk)
                .accessibilityHidden(true)
            Text("把文件放在这里")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(LedgeStyle.ink)
            Text("拖入即移动到中转站 · 拖出即还原")
                .font(.system(size: 11))
                .foregroundStyle(LedgeStyle.secondaryInk)
        }
    }
}

private struct FileCard: View {
    @ObservedObject var model: AppModel
    let resolved: ResolvedShelfItem

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 9) {
                fileIcon
                Text(resolved.item.displayName)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(
                        resolved.isAvailable
                            ? LedgeStyle.ink
                            : LedgeStyle.secondaryInk
                    )
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(width: 104)
                if !resolved.isAvailable {
                    Text("源文件不可用")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.orange)
                }
            }
            .frame(width: 126, height: 124)
            .background(LedgeStyle.cardSurface)
            .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .stroke(LedgeStyle.hairline, lineWidth: 1)
            }
            .overlay {
                if let url = resolved.url {
                    FileDragHandle(
                        itemID: resolved.id,
                        url: url,
                        onPromiseFulfilled: { id in
                            model.completePromisedFileExport(id: id)
                        }
                    )
                }
            }

            if !resolved.item.storage.isTransit {
                Button {
                    model.removeItem(id: resolved.id)
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                        .frame(width: 21, height: 21)
                        .background(.ultraThickMaterial)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(LedgeStyle.secondaryInk)
                .padding(6)
            }
        }
    }

    @ViewBuilder
    private var fileIcon: some View {
        if let url = resolved.url {
            Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                .resizable()
                .scaledToFit()
                .frame(width: 44, height: 44)
        } else {
            Image(systemName: "questionmark.folder")
                .font(.system(size: 37, weight: .light))
                .foregroundStyle(.orange.opacity(0.8))
                .frame(width: 44, height: 44)
        }
    }
}

private struct NoteView: View {
    @ObservedObject var model: AppModel
    @State private var wantsFocus = false

    var body: some View {
        PlainTextEditor(
            text: $model.draft,
            wantsFocus: wantsFocus,
            placeholder: "先写在这里……"
        )
        .background(LedgeStyle.editorSurface)
        .onAppear { wantsFocus = true }
    }
}
