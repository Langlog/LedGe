import AppKit
import LedgeCore
import SwiftUI
import UniformTypeIdentifiers

struct FileDropReceiver: NSViewRepresentable {
    let isEnabled: Bool
    let onTargeted: (Bool) -> Void
    let onDrop: ([URL]) -> Bool

    func makeNSView(context: Context) -> FileDropReceiverView {
        let view = FileDropReceiverView()
        view.isEnabled = isEnabled
        view.onTargeted = onTargeted
        view.onDrop = onDrop
        return view
    }

    func updateNSView(_ view: FileDropReceiverView, context: Context) {
        view.isEnabled = isEnabled
        view.onTargeted = onTargeted
        view.onDrop = onDrop
    }
}

final class FileDropReceiverView: NSView {
    var isEnabled = false
    var onTargeted: ((Bool) -> Void)?
    var onDrop: (([URL]) -> Bool)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        registerForDraggedTypes([.fileURL])
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        registerForDraggedTypes([.fileURL])
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        isEnabled ? self : nil
    }

    override func draggingEntered(_ sender: any NSDraggingInfo) -> NSDragOperation {
        guard isEnabled, !fileURLs(from: sender).isEmpty else { return [] }
        onTargeted?(true)
        return nsDragOperation(for: FileImportPolicy.advertisedOperation)
    }

    override func draggingUpdated(_ sender: any NSDraggingInfo) -> NSDragOperation {
        guard isEnabled, !fileURLs(from: sender).isEmpty else { return [] }
        return nsDragOperation(for: FileImportPolicy.advertisedOperation)
    }

    override func draggingExited(_ sender: (any NSDraggingInfo)?) {
        onTargeted?(false)
    }

    override func performDragOperation(_ sender: any NSDraggingInfo) -> Bool {
        guard isEnabled else { return false }
        let urls = fileURLs(from: sender)
        onTargeted?(false)
        guard !urls.isEmpty else { return false }
        return onDrop?(urls) ?? false
    }

    private func fileURLs(from sender: any NSDraggingInfo) -> [URL] {
        let options: [NSPasteboard.ReadingOptionKey: Any] = [
            .urlReadingFileURLsOnly: true
        ]
        return sender.draggingPasteboard
            .readObjects(forClasses: [NSURL.self], options: options)?
            .compactMap { ($0 as? URL)?.standardizedFileURL } ?? []
    }

    private func nsDragOperation(
        for operation: FileTransferOperation
    ) -> NSDragOperation {
        switch operation {
        case .none:
            []
        case .copy:
            .copy
        case .move:
            .move
        }
    }
}

struct FileDragHandle: NSViewRepresentable {
    let itemID: UUID
    let url: URL
    let onPromiseFulfilled: @MainActor @Sendable (UUID) -> Void

    func makeNSView(context: Context) -> FileDragSourceView {
        let view = FileDragSourceView()
        update(view)
        return view
    }

    func updateNSView(_ view: FileDragSourceView, context: Context) {
        update(view)
    }

    private func update(_ view: FileDragSourceView) {
        view.itemID = itemID
        view.url = url
        view.onPromiseFulfilled = onPromiseFulfilled
    }
}

final class FileDragSourceView: NSView, NSDraggingSource {
    var itemID: UUID?
    var url: URL?
    var onPromiseFulfilled: (@MainActor @Sendable (UUID) -> Void)?
    private var mouseDownEvent: NSEvent?
    private var startedDragging = false
    private var promiseDelegate: FilePromiseExportDelegate?
    private var promiseProvider: NSFilePromiseProvider?

    override var acceptsFirstResponder: Bool { true }

    override func mouseDown(with event: NSEvent) {
        mouseDownEvent = event
        startedDragging = false
    }

    override func mouseDragged(with event: NSEvent) {
        guard !startedDragging,
              let itemID,
              let url,
              let mouseDownEvent
        else { return }
        startedDragging = true

        let promiseDelegate = FilePromiseExportDelegate(
            itemID: itemID,
            sourceURL: url,
            onFulfilled: { [weak self] id in
                self?.onPromiseFulfilled?(id)
            },
            onFinished: { [weak self] in
                self?.promiseProvider = nil
                self?.promiseDelegate = nil
            }
        )
        let promiseProvider = NSFilePromiseProvider(
            fileType: promisedFileType(for: url),
            delegate: promiseDelegate
        )
        promiseProvider.userInfo = url
        self.promiseDelegate = promiseDelegate
        self.promiseProvider = promiseProvider

        let draggingItem = NSDraggingItem(
            pasteboardWriter: promiseProvider
        )
        let icon = NSWorkspace.shared.icon(forFile: url.path)
        icon.size = NSSize(width: 48, height: 48)
        let imageFrame = NSRect(
            x: max(0, bounds.midX - 24),
            y: max(0, bounds.midY - 24),
            width: 48,
            height: 48
        )
        draggingItem.setDraggingFrame(imageFrame, contents: icon)
        beginDraggingSession(
            with: [draggingItem],
            event: mouseDownEvent,
            source: self
        )
    }

    override func mouseUp(with event: NSEvent) {
        if !startedDragging, let url {
            NSWorkspace.shared.open(url)
        }
        mouseDownEvent = nil
    }

    func draggingSession(
        _ session: NSDraggingSession,
        sourceOperationMaskFor context: NSDraggingContext
    ) -> NSDragOperation {
        guard context != .withinApplication else { return [] }
        switch FileExportPolicy.advertisedOperation {
        case .none:
            return []
        case .copy:
            return .copy
        case .move:
            return .move
        }
    }

    func draggingSession(
        _ session: NSDraggingSession,
        endedAt screenPoint: NSPoint,
        operation: NSDragOperation
    ) {
        if operation.isEmpty {
            promiseProvider = nil
            promiseDelegate = nil
        }
    }

    private func promisedFileType(for url: URL) -> String {
        let values = try? url.resourceValues(
            forKeys: [.contentTypeKey, .isDirectoryKey]
        )
        if let contentType = values?.contentType,
           contentType.conforms(to: .data)
            || contentType.conforms(to: .directory) {
            return contentType.identifier
        }
        return values?.isDirectory == true
            ? UTType.directory.identifier
            : UTType.data.identifier
    }
}

final class FilePromiseExportDelegate: NSObject,
    NSFilePromiseProviderDelegate,
    @unchecked Sendable {
    private let itemID: UUID
    private let sourceURL: URL
    private let fileName: String
    private let writer = PromisedFileWriter()
    private let queue: OperationQueue
    private let onFulfilled: @MainActor @Sendable (UUID) -> Void
    private let onFinished: @MainActor @Sendable () -> Void

    init(
        itemID: UUID,
        sourceURL: URL,
        onFulfilled: @escaping @MainActor @Sendable (UUID) -> Void,
        onFinished: @escaping @MainActor @Sendable () -> Void
    ) {
        self.itemID = itemID
        self.sourceURL = sourceURL.standardizedFileURL
        fileName = sourceURL.lastPathComponent
        self.onFulfilled = onFulfilled
        self.onFinished = onFinished
        queue = OperationQueue()
        queue.name = "app.ledge.file-promise"
        queue.qualityOfService = .userInitiated
        queue.maxConcurrentOperationCount = 1
        super.init()
    }

    @MainActor
    func filePromiseProvider(
        _ filePromiseProvider: NSFilePromiseProvider,
        fileNameForType fileType: String
    ) -> String {
        fileName
    }

    func operationQueue(
        for filePromiseProvider: NSFilePromiseProvider
    ) -> OperationQueue {
        queue
    }

    nonisolated func filePromiseProvider(
        _ filePromiseProvider: NSFilePromiseProvider,
        writePromiseTo url: URL,
        completionHandler: @escaping (Error?) -> Void
    ) {
        do {
            try writer.write(
                sourceURL: sourceURL,
                destinationURL: url
            )
            completionHandler(nil)
            Task { @MainActor in
                onFulfilled(itemID)
                onFinished()
            }
        } catch {
            completionHandler(error)
            Task { @MainActor in
                onFinished()
            }
        }
    }
}
