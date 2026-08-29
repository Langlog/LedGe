import AppKit
import LedgeCore

@MainActor
final class EdgeActivationController {
    private let model: AppModel
    private weak var panelController: LedgePanelController?
    private var timer: Timer?
    private var globalDragMonitor: Any?
    private var localDragMonitor: Any?
    private var globalClickMonitor: Any?
    private var localClickMonitor: Any?
    private var lastInsideAt = Date.distantPast
    private var suppressPromptUntilMouseUp = false
    private var baselineDragPasteboardChangeCount = NSPasteboard(
        name: .drag
    ).changeCount
    private var activeFileDragChangeCount: Int?
    private var activeFileDragLastSeenAt: TimeInterval?

    init(
        model: AppModel,
        panelController: LedgePanelController
    ) {
        self.model = model
        self.panelController = panelController
    }

    func start() {
        stop()
        baselineDragPasteboardChangeCount = NSPasteboard(
            name: .drag
        ).changeCount
        timer = Timer.scheduledTimer(
            timeInterval: 0.03,
            target: self,
            selector: #selector(timerDidFire),
            userInfo: nil,
            repeats: true
        )
        let dragEvents: NSEvent.EventTypeMask = [.leftMouseDragged, .leftMouseUp]
        globalDragMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: dragEvents
        ) { [weak self] event in
            let eventType = event.type
            Task { @MainActor in
                self?.handleDragEvent(eventType)
            }
        }
        localDragMonitor = NSEvent.addLocalMonitorForEvents(
            matching: dragEvents
        ) { [weak self] event in
            self?.handleDragEvent(event.type)
            return event
        }

        globalClickMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: .leftMouseDown
        ) { [weak self] _ in
            let location = NSEvent.mouseLocation
            Task { @MainActor in
                self?.handleMouseDown(at: location)
            }
        }
        localClickMonitor = NSEvent.addLocalMonitorForEvents(
            matching: .leftMouseDown
        ) { [weak self] event in
            self?.handleMouseDown(at: NSEvent.mouseLocation)
            return event
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        if let globalDragMonitor {
            NSEvent.removeMonitor(globalDragMonitor)
        }
        if let localDragMonitor {
            NSEvent.removeMonitor(localDragMonitor)
        }
        if let globalClickMonitor {
            NSEvent.removeMonitor(globalClickMonitor)
        }
        if let localClickMonitor {
            NSEvent.removeMonitor(localClickMonitor)
        }
        globalDragMonitor = nil
        localDragMonitor = nil
        globalClickMonitor = nil
        localClickMonitor = nil
        activeFileDragChangeCount = nil
        activeFileDragLastSeenAt = nil
        suppressPromptUntilMouseUp = false
    }

    @objc
    private func timerDidFire() {
        let location = NSEvent.mouseLocation
        guard let panelController,
              let pointerScreen = panelController.screenContaining(location)
        else { return }

        let targetScreen = model.settings.displayMode == .mainDisplay
            ? (NSScreen.main ?? pointerScreen)
            : pointerScreen
        panelController.move(to: targetScreen)

        let zone = EdgeActivationGeometry.pointerZone(
            in: targetScreen.frame,
            sensitivity: model.settings.wakeSensitivity
        )
        let pointerIsInZone = zone.contains(location)
        let pointerIsInPanel = panelController
            .visibleSurfaceContains(location)

        if pointerIsInZone, !suppressPromptUntilMouseUp {
            lastInsideAt = Date()
            panelController.showPrompt()
        } else if pointerIsInPanel {
            lastInsideAt = Date()
        } else if model.surface == .prompt,
                  Date().timeIntervalSince(lastInsideAt) > 0.38 {
            panelController.pointerLeftPrompt()
        } else if model.surface == .files,
                  !model.isExternalDragActive,
                  Date().timeIntervalSince(lastInsideAt) > 0.75 {
            panelController.hide()
        }
    }

    private func handleDragEvent(_ eventType: NSEvent.EventType) {
        if eventType == .leftMouseUp {
            let dragPasteboard = NSPasteboard(name: .drag)
            baselineDragPasteboardChangeCount = dragPasteboard.changeCount
            activeFileDragChangeCount = nil
            activeFileDragLastSeenAt = nil
            suppressPromptUntilMouseUp = false
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .milliseconds(140))
                guard let self, !self.model.isDropTargeted else { return }
                self.model.isExternalDragActive = false
            }
            return
        }
        guard eventType == .leftMouseDragged else { return }
        let dragPasteboard = NSPasteboard(name: .drag)
        let options: [NSPasteboard.ReadingOptionKey: Any] = [
            .urlReadingFileURLsOnly: true
        ]
        let containsFileURLs = dragPasteboard
            .readObjects(forClasses: [NSURL.self], options: options)?
            .compactMap { $0 as? URL }
            .contains { url in
                url.isFileURL
                    && FileManager.default.fileExists(atPath: url.path)
            } ?? false
        let pasteboardChangeCount = dragPasteboard.changeCount
        let currentTime = ProcessInfo.processInfo.systemUptime
        let isFileDrag = FileDragActivationPolicy.shouldRevealShelf(
            pasteboardContainsFileURLs: containsFileURLs,
            pasteboardChangeCount: pasteboardChangeCount,
            baselineChangeCount: baselineDragPasteboardChangeCount,
            activeFileDragChangeCount: activeFileDragChangeCount,
            activeFileDragLastSeenAt: activeFileDragLastSeenAt,
            currentTime: currentTime
        )
        guard isFileDrag else {
            suppressPromptUntilMouseUp = true
            if model.surface == .prompt {
                panelController?.hide(force: true)
            }
            return
        }
        activeFileDragChangeCount = pasteboardChangeCount
        activeFileDragLastSeenAt = currentTime
        suppressPromptUntilMouseUp = false

        let location = NSEvent.mouseLocation
        guard let panelController,
              let pointerScreen = panelController.screenContaining(location)
        else { return }
        let targetScreen = model.settings.displayMode == .mainDisplay
            ? (NSScreen.main ?? pointerScreen)
            : pointerScreen
        guard EdgeActivationGeometry.dragZone(
            in: targetScreen.frame
        ).contains(location) else { return }

        lastInsideAt = Date()
        model.isExternalDragActive = true
        panelController.move(to: targetScreen)
        panelController.showFiles()
    }

    private func handleMouseDown(at location: NSPoint) {
        baselineDragPasteboardChangeCount = NSPasteboard(
            name: .drag
        ).changeCount
        activeFileDragChangeCount = nil
        activeFileDragLastSeenAt = nil
        suppressPromptUntilMouseUp = true
        guard let panelController else { return }

        if PanelOutsideClickPolicy.shouldDismiss(
            surface: model.surface,
            clickIsInsidePanel: panelController.panelContains(location),
            externalFileDragIsActive: model.isExternalDragActive
        ) {
            panelController.hide(force: true)
            return
        }

        guard model.surface == .prompt,
              panelController.promptContains(location)
        else { return }
        panelController.activatePrompt()
    }
}
