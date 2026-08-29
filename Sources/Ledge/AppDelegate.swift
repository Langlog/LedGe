import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let model = AppModel()
    private var panelController: LedgePanelController?
    private var edgeController: EdgeActivationController?
    private var settingsWindowController: NSWindowController?
    private var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        configureStatusItem()

        let previewSurface = ProcessInfo.processInfo
            .environment["LEDGE_PREVIEW_SURFACE"]
        switch previewSurface {
        case "files":
            model.surface = .files
        case "note":
            model.surface = .note
        case "peek", "prompt":
            model.surface = .prompt
        default:
            break
        }

        let panelController = LedgePanelController(model: model)
        self.panelController = panelController
        edgeController = EdgeActivationController(
            model: model,
            panelController: panelController
        )
        panelController.install()

        if previewSurface == nil {
            edgeController?.start()
        } else if previewSurface == "settings" {
            showSettings()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        model.flushDraft()
        edgeController?.stop()
        panelController?.uninstall()
    }

    @objc
    private func showSettings() {
        if let settingsWindowController {
            settingsWindowController.showWindow(nil)
            NSApp.activate(ignoringOtherApps: true)
            settingsWindowController.window?.makeKeyAndOrderFront(nil)
            return
        }

        let view = SettingsView(
            model: model,
            onQuit: { NSApp.terminate(nil) }
        )
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 560),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "Ledge Settings"
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false
        window.center()
        window.contentView = NSHostingView(rootView: view)

        let controller = NSWindowController(window: window)
        settingsWindowController = controller
        controller.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    private func configureStatusItem() {
        let item = NSStatusBar.system.statusItem(
            withLength: NSStatusItem.squareLength
        )
        item.button?.image = NSImage(
            systemSymbolName: "rectangle.bottomhalf.inset.filled",
            accessibilityDescription: "Ledge Settings"
        )
        item.button?.toolTip = "Ledge Settings"
        item.button?.target = self
        item.button?.action = #selector(showSettings)
        statusItem = item
    }
}
