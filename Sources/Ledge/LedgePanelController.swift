import AppKit
import Combine
import LedgeCore
import QuartzCore
import SwiftUI

final class LedgePanel: NSPanel {
    var onDismissShortcut: (() -> Void)?

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func sendEvent(_ event: NSEvent) {
        if event.type == .keyDown,
           PanelShortcutPolicy.shouldDismiss(keyCode: event.keyCode) {
            onDismissShortcut?()
            return
        }
        super.sendEvent(event)
    }
}

@MainActor
final class LedgePanelController {
    private let model: AppModel
    private let panel: LedgePanel
    private var surfaceSubscription: AnyCancellable?
    private var currentScreen: NSScreen?
    private var displayedSurface: LedgeSurface = .hidden
    private var isDismissing = false
    private var dismissalGeneration = 0

    init(model: AppModel) {
        self.model = model
        panel = LedgePanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
    }

    func install() {
        panel.level = .statusBar
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .stationary
        ]
        panel.hidesOnDeactivate = false
        panel.isMovable = false
        panel.becomesKeyOnlyIfNeeded = false
        panel.animationBehavior = .none
        panel.isExcludedFromWindowsMenu = true
        panel.onDismissShortcut = { [weak self] in
            self?.hide(force: true)
        }
        panel.contentView = NSHostingView(
            rootView: LedgeRootView(
                model: model,
                onDismiss: { [weak self] in self?.hide(force: true) },
                onOpenNote: { [weak self] in self?.openNote() }
            )
        )
        surfaceSubscription = model.$surface
            .removeDuplicates()
            .sink { [weak self] surface in
                self?.apply(surface)
            }
        if let screen = NSScreen.main ?? NSScreen.screens.first {
            move(to: screen)
            apply(model.surface)
        }
    }

    func uninstall() {
        panel.onDismissShortcut = nil
        surfaceSubscription?.cancel()
        surfaceSubscription = nil
    }

    func move(to screen: NSScreen) {
        guard currentScreen != screen else { return }
        currentScreen = screen
        panel.setFrame(frame(for: model.surface, on: screen), display: true)
    }

    func screenContaining(_ point: NSPoint) -> NSScreen? {
        NSScreen.screens.first { NSMouseInRect(point, $0.frame, false) }
    }

    func frameContains(_ point: NSPoint, margin: CGFloat = 0) -> Bool {
        panel.frame.insetBy(dx: -margin, dy: -margin).contains(point)
    }

    func panelContains(_ point: NSPoint) -> Bool {
        frameContains(point)
    }

    func visibleSurfaceContains(_ point: NSPoint) -> Bool {
        switch model.surface {
        case .prompt:
            promptContains(point)
        case .files, .note:
            frameContains(point, margin: 24)
        case .hidden:
            false
        }
    }

    func promptContains(_ point: NSPoint) -> Bool {
        let localPoint = CGPoint(
            x: point.x - panel.frame.minX,
            y: point.y - panel.frame.minY
        )
        return CompactPromptGeometry.contains(
            localPoint,
            in: CGRect(origin: .zero, size: panel.frame.size)
        )
    }

    func showPrompt() {
        model.send(.pointerEntered)
    }

    func pointerLeftPrompt() {
        model.send(.pointerLeft)
    }

    func showFiles() {
        model.send(.externalFileDragEntered)
    }

    func activatePrompt() {
        openNote()
    }

    func hide(force: Bool = false) {
        guard model.surface != .hidden, !isDismissing else { return }
        guard force || !panel.isKeyWindow else { return }
        if panel.isKeyWindow {
            panel.resignKey()
            NSApp.deactivate()
        }
        if model.surface == .note || model.surface == .files {
            animateDismissal(from: model.surface)
        } else {
            model.send(.dismissed)
        }
    }

    private func openNote() {
        if model.surface == .prompt {
            model.send(.promptClicked)
            return
        }
        if model.surface != .note {
            model.send(.noteSelected)
            return
        }
        focusNote()
    }

    private func focusNote() {
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKey()
        panel.makeKeyAndOrderFront(nil)
    }

    private func apply(_ surface: LedgeSurface) {
        let previousSurface = displayedSurface
        displayedSurface = surface

        switch surface {
        case .hidden:
            panel.hasShadow = false
            panel.orderOut(nil)
            panel.alphaValue = 1
        case .prompt, .files, .note:
            if isDismissing {
                dismissalGeneration += 1
                isDismissing = false
                panel.alphaValue = 1
            }
            panel.hasShadow = true
            show(
                surface,
                previousSurface: previousSurface,
                enteringFromHidden: previousSurface == .hidden
            )
            if surface == .note {
                focusNote()
            }
        }
    }

    private func animateDismissal(from surface: LedgeSurface) {
        guard let screen = currentScreen ?? NSScreen.main,
              !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        else {
            model.send(.dismissed)
            return
        }

        isDismissing = true
        dismissalGeneration += 1
        let generation = dismissalGeneration
        let compactFrame = frame(for: .prompt, on: screen)
        let targetFrame = compactFrame.offsetBy(
            dx: 0,
            dy: -compactFrame.height
        )

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.14
            context.timingFunction = CAMediaTimingFunction(
                controlPoints: 0.40,
                0,
                0.65,
                1
            )
            panel.animator().setFrame(targetFrame, display: true)
            panel.animator().alphaValue = 0
        } completionHandler: { [weak self] in
            guard let self,
                  self.dismissalGeneration == generation
            else { return }

            if self.model.surface != surface
                || self.model.isExternalDragActive {
                self.isDismissing = false
                self.panel.alphaValue = 1
                self.show(
                    self.model.surface,
                    previousSurface: surface,
                    enteringFromHidden: false
                )
                return
            }

            self.isDismissing = false
            self.model.send(.dismissed)
            self.panel.alphaValue = 1
        }
    }

    private func show(
        _ surface: LedgeSurface,
        previousSurface: LedgeSurface,
        enteringFromHidden: Bool
    ) {
        guard let screen = currentScreen ?? NSScreen.main else { return }
        let targetFrame = frame(for: surface, on: screen)
        let reduceMotion = NSWorkspace.shared
            .accessibilityDisplayShouldReduceMotion

        if reduceMotion {
            panel.setFrame(targetFrame, display: true)
            panel.alphaValue = 1
            panel.orderFrontRegardless()
            return
        }

        if enteringFromHidden || !panel.isVisible {
            let initialFrame = initialFrame(
                for: surface,
                targetFrame: targetFrame,
                on: screen
            )
            panel.setFrame(initialFrame, display: true)
            panel.alphaValue = surface == .prompt ? 0.72 : 0
            panel.orderFrontRegardless()
            animate(
                to: targetFrame,
                duration: surface == .prompt ? 0.095 : 0.075,
                fadesIn: true
            )
        } else {
            panel.orderFrontRegardless()
            if previousSurface == .prompt,
               surface == .note || surface == .files {
                animatePopOut(to: targetFrame, surface: surface)
                return
            }
            animate(
                to: targetFrame,
                duration: previousDuration(
                    from: previousSurface,
                    to: surface
                ),
                fadesIn: false
            )
        }
    }

    private func initialFrame(
        for surface: LedgeSurface,
        targetFrame: NSRect,
        on screen: NSScreen
    ) -> NSRect {
        guard surface == .prompt else {
            return targetFrame.offsetBy(dx: 0, dy: -10)
        }
        return NSRect(
            x: targetFrame.minX,
            y: screen.frame.minY - targetFrame.height,
            width: targetFrame.width,
            height: targetFrame.height
        )
    }

    private func animatePopOut(
        to targetFrame: NSRect,
        surface: LedgeSurface
    ) {
        let overshootFrame = NSRect(
            x: targetFrame.minX - 7,
            y: targetFrame.minY,
            width: targetFrame.width + 14,
            height: targetFrame.height + 9
        )
        animate(
            to: overshootFrame,
            duration: 0.067,
            fadesIn: false
        ) { [weak self] in
            guard let self,
                  self.displayedSurface == surface
            else { return }
            self.animate(
                to: targetFrame,
                duration: 0.036,
                fadesIn: false
            )
        }
    }

    private func animate(
        to frame: NSRect,
        duration: TimeInterval,
        fadesIn: Bool,
        completion: (() -> Void)? = nil
    ) {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = duration
            context.timingFunction = CAMediaTimingFunction(
                controlPoints: 0.16,
                1,
                0.30,
                1
            )
            panel.animator().setFrame(frame, display: true)
            if fadesIn {
                panel.animator().alphaValue = 1
            }
        } completionHandler: {
            completion?()
        }
    }

    private func frame(
        for surface: LedgeSurface,
        on screen: NSScreen
    ) -> NSRect {
        let size: NSSize = switch surface {
        case .hidden:
            CompactPromptGeometry.size
        case .prompt:
            CompactPromptGeometry.size
        case .files, .note:
            ExpandedPanelGeometry.size
        }
        let bottomInset: CGFloat = surface == .prompt ? 0 : 14
        return NSRect(
            x: screen.frame.midX - size.width / 2,
            y: screen.frame.minY + bottomInset,
            width: size.width,
            height: size.height
        )
    }

    private func previousDuration(
        from previous: LedgeSurface,
        to current: LedgeSurface
    ) -> TimeInterval {
        if previous == .prompt,
           current == .note || current == .files {
            return 0.085
        }
        return 0.07
    }
}
