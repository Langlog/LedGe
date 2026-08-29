import Foundation
import Testing
@testable import LedgeCore

@Suite("Panel shortcuts")
struct PanelShortcutPolicyTests {
    @Test("Escape dismisses the expanded panel")
    func escapeDismissesPanel() {
        #expect(PanelShortcutPolicy.shouldDismiss(keyCode: 53))
        #expect(!PanelShortcutPolicy.shouldDismiss(keyCode: 36))
        #expect(!PanelShortcutPolicy.shouldDismiss(keyCode: 51))
    }
}

@Suite("Panel outside-click dismissal")
struct PanelOutsideClickDismissalTests {
    @Test("An outside click dismisses either expanded surface")
    func outsideClickDismissesExpandedPanel() {
        for surface in [LedgeSurface.note, .files] {
            #expect(
                PanelOutsideClickPolicy.shouldDismiss(
                    surface: surface,
                    clickIsInsidePanel: false,
                    externalFileDragIsActive: false
                )
            )
        }
    }

    @Test("Inside clicks, the prompt, and active file drags stay visible")
    func legitimateInteractionStaysVisible() {
        #expect(
            !PanelOutsideClickPolicy.shouldDismiss(
                surface: .note,
                clickIsInsidePanel: true,
                externalFileDragIsActive: false
            )
        )
        #expect(
            !PanelOutsideClickPolicy.shouldDismiss(
                surface: .prompt,
                clickIsInsidePanel: false,
                externalFileDragIsActive: false
            )
        )
        #expect(
            !PanelOutsideClickPolicy.shouldDismiss(
                surface: .files,
                clickIsInsidePanel: false,
                externalFileDragIsActive: true
            )
        )
    }
}

@Suite("Finder file export protocol")
struct FinderFileExportProtocolTests {
    @Test("Finder imports advertise move while file promises advertise copy")
    func finderTransferProtocol() {
        #expect(FileImportPolicy.advertisedOperation == .move)
        #expect(FileExportPolicy.advertisedOperation == .copy)
    }
}

@Suite("Text editing shortcuts")
struct TextEditingShortcutTests {
    @Test("Select all supports both Control-A and Command-A")
    func selectAll() {
        #expect(
            TextEditingShortcutPolicy.action(
                character: "a",
                command: false,
                control: true
            ) == .selectAll
        )
        #expect(
            TextEditingShortcutPolicy.action(
                character: "A",
                command: true,
                control: false
            ) == .selectAll
        )
    }

    @Test("Copy and paste use Command-C and Command-V")
    func clipboard() {
        #expect(
            TextEditingShortcutPolicy.action(
                character: "c",
                command: true,
                control: false
            ) == .copy
        )
        #expect(
            TextEditingShortcutPolicy.action(
                character: "v",
                command: true,
                control: false
            ) == .paste
        )
        #expect(
            TextEditingShortcutPolicy.action(
                character: "c",
                command: false,
                control: true
            ) == nil
        )
    }
}

@Suite("Settings")
struct SettingsTests {
    @Test("Defaults match the product decisions")
    func defaults() {
        let settings = LedgeSettings.default

        #expect(settings.displayMode == .followsPointer)
        #expect(settings.removeAfterSuccessfulDrag)
        #expect(settings.wakeSensitivity == .balanced)
        #expect(!settings.launchAtLogin)
    }

    @Test("Settings survive JSON round-trip")
    func roundTrip() throws {
        let original = LedgeSettings(
            displayMode: .mainDisplay,
            removeAfterSuccessfulDrag: false,
            wakeSensitivity: .eager,
            launchAtLogin: true
        )

        let data = try JSONEncoder().encode(original)
        let restored = try JSONDecoder().decode(LedgeSettings.self, from: data)

        #expect(restored == original)
    }
}

@Suite("Shelf state")
struct ShelfStateTests {
    @Test("Adding several references preserves input order and the old value")
    func immutableBatchAdd() {
        let original = ShelfState()
        let items = [
            ShelfItem(id: UUID(), displayName: "one.txt", bookmark: Data([1])),
            ShelfItem(id: UUID(), displayName: "Folder", bookmark: Data([2]))
        ]

        let updated = original.adding(items)

        #expect(original.items.isEmpty)
        #expect(updated.items.map(\.displayName) == ["one.txt", "Folder"])
    }

    @Test("Removing an item returns a new state")
    func immutableRemove() {
        let first = ShelfItem(id: UUID(), displayName: "one.txt", bookmark: Data([1]))
        let second = ShelfItem(id: UUID(), displayName: "two.txt", bookmark: Data([2]))
        let original = ShelfState(items: [first, second])

        let updated = original.removing(id: first.id)

        #expect(original.items.count == 2)
        #expect(updated.items == [second])
    }

    @Test("Only a successful external drag triggers automatic removal")
    func successfulDragPolicy() {
        #expect(RemovalPolicy.removeAfterSuccessfulDrag.shouldRemove(
            dragOperationSucceeded: true
        ))
        #expect(!RemovalPolicy.removeAfterSuccessfulDrag.shouldRemove(
            dragOperationSucceeded: false
        ))
        #expect(!RemovalPolicy.keep.shouldRemove(dragOperationSucceeded: true))
    }
}

@Suite("Draft persistence")
struct DraftStoreTests {
    @Test("Plain text is atomically saved and restored")
    func roundTrip() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let store = DraftStore(directory: directory)

        try store.save("先放在这里。\nSecond line.")

        #expect(try store.load() == "先放在这里。\nSecond line.")
        try? FileManager.default.removeItem(at: directory)
    }

    @Test("A missing draft is an empty string")
    func missingDraft() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)

        #expect(try DraftStore(directory: directory).load() == "")
    }

    @Test("Draft and its directory are private to the current user")
    func privatePermissions() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try DraftStore(directory: directory).save("private")

        let directoryAttributes = try FileManager.default.attributesOfItem(
            atPath: directory.path
        )
        let fileAttributes = try FileManager.default.attributesOfItem(
            atPath: directory.appendingPathComponent("draft.txt").path
        )

        #expect((directoryAttributes[.posixPermissions] as? NSNumber)?.intValue == 0o700)
        #expect((fileAttributes[.posixPermissions] as? NSNumber)?.intValue == 0o600)
        try? FileManager.default.removeItem(at: directory)
    }
}

@Suite("Edge activation")
struct EdgeActivationGeometryTests {
    @Test("Balanced pointer zone is centered, narrow and shallow")
    func pointerZone() {
        let screen = CGRect(x: 100, y: 50, width: 1_600, height: 1_000)
        let zone = EdgeActivationGeometry.pointerZone(
            in: screen,
            sensitivity: .balanced
        )

        #expect(zone.midX == screen.midX)
        #expect(zone.minY == screen.minY)
        #expect(zone.width == 240)
        #expect(zone.height == 5)
    }

    @Test("Drag zone is wider and taller than the pointer zone")
    func dragZone() {
        let screen = CGRect(x: 0, y: 0, width: 1_440, height: 900)
        let pointer = EdgeActivationGeometry.pointerZone(
            in: screen,
            sensitivity: .balanced
        )
        let drag = EdgeActivationGeometry.dragZone(in: screen)

        #expect(drag.width > pointer.width)
        #expect(drag.height > pointer.height)
        #expect(drag.minY == screen.minY)
    }
}

@Suite("Activation state machine")
struct ActivationStateMachineTests {
    @Test("Pointer proximity only reveals the compact prompt")
    func pointerProximityRequiresConfirmation() {
        #expect(
            LedgeActivationState.transition(
                from: .hidden,
                on: .pointerEntered
            ) == .prompt
        )
    }

    @Test("Clicking the compact prompt opens the note")
    func promptClickPrioritizesNote() {
        #expect(
            LedgeActivationState.transition(
                from: .prompt,
                on: .promptClicked
            ) == .note
        )
    }

    @Test("Dragging a file opens the file shelf directly")
    func externalDragPrioritizesFiles() {
        #expect(
            LedgeActivationState.transition(
                from: .hidden,
                on: .externalFileDragEntered
            ) == .files
        )
        #expect(
            LedgeActivationState.transition(
                from: .prompt,
                on: .externalFileDragEntered
            ) == .files
        )
    }

    @Test("Leaving the edge only dismisses an unconfirmed prompt")
    func leavingEdgeDismissesPromptOnly() {
        #expect(
            LedgeActivationState.transition(
                from: .prompt,
                on: .pointerLeft
            ) == .hidden
        )
        #expect(
            LedgeActivationState.transition(
                from: .note,
                on: .pointerLeft
            ) == .note
        )
    }

    @Test("Dismiss always returns to the hidden state")
    func explicitDismiss() {
        for surface in [
            LedgeSurface.prompt,
            .files,
            .note
        ] {
            #expect(
                LedgeActivationState.transition(
                    from: surface,
                    on: .dismissed
                ) == .hidden
            )
        }
    }
}

@Suite("File drag activation")
struct FileDragActivationTests {
    @Test("Only a fresh or active file drag session reveals the shelf")
    func requiresFreshFileDragSession() {
        #expect(
            FileDragActivationPolicy.shouldRevealShelf(
                pasteboardContainsFileURLs: true,
                pasteboardChangeCount: 12,
                baselineChangeCount: 11,
                activeFileDragChangeCount: nil,
                activeFileDragLastSeenAt: nil,
                currentTime: 10
            )
        )
        #expect(
            !FileDragActivationPolicy.shouldRevealShelf(
                pasteboardContainsFileURLs: true,
                pasteboardChangeCount: 12,
                baselineChangeCount: 12,
                activeFileDragChangeCount: nil,
                activeFileDragLastSeenAt: nil,
                currentTime: 10
            )
        )
        #expect(
            FileDragActivationPolicy.shouldRevealShelf(
                pasteboardContainsFileURLs: true,
                pasteboardChangeCount: 12,
                baselineChangeCount: 12,
                activeFileDragChangeCount: 12,
                activeFileDragLastSeenAt: 9.8,
                currentTime: 10
            )
        )
        #expect(
            !FileDragActivationPolicy.shouldRevealShelf(
                pasteboardContainsFileURLs: true,
                pasteboardChangeCount: 12,
                baselineChangeCount: 12,
                activeFileDragChangeCount: 12,
                activeFileDragLastSeenAt: 9.4,
                currentTime: 10
            )
        )
        #expect(
            !FileDragActivationPolicy.shouldRevealShelf(
                pasteboardContainsFileURLs: false,
                pasteboardChangeCount: 13,
                baselineChangeCount: 12,
                activeFileDragChangeCount: nil,
                activeFileDragLastSeenAt: nil,
                currentTime: 10
            )
        )
    }
}

@Suite("JSON persistence")
struct JSONPersistenceTests {
    @Test("Shelf state survives disk round-trip")
    func shelfRoundTrip() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let store = ShelfStore(directory: directory)
        let state = ShelfState(items: [
            ShelfItem(displayName: "reference.txt", bookmark: Data([7, 8, 9]))
        ])

        try store.save(state)

        #expect(try store.load() == state)
        try? FileManager.default.removeItem(at: directory)
    }

    @Test("Settings use defaults until first save")
    func settingsDefaultsAndRoundTrip() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let store = SettingsStore(directory: directory)

        #expect(try store.load() == .default)

        let updated = LedgeSettings.default.with(wakeSensitivity: .eager)
        try store.save(updated)
        #expect(try store.load() == updated)
        try? FileManager.default.removeItem(at: directory)
    }
}

@Suite("File references")
struct FileReferenceTests {
    @Test("A bookmark resolves to its source without copying it")
    func resolvesExistingSource() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        let source = directory.appendingPathComponent("source.txt")
        try Data("source".utf8).write(to: source)
        let codec = FileReferenceCodec()

        let item = try codec.makeItem(for: source)
        let resolution = codec.resolve(item)

        #expect(item.displayName == "source.txt")
        #expect(
            resolution.url?.resolvingSymlinksInPath()
                == source.resolvingSymlinksInPath()
        )
        #expect(resolution.isAvailable)
        try? FileManager.default.removeItem(at: directory)
    }

    @Test("A deleted source remains represented as unavailable")
    func reportsMissingSource() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        let source = directory.appendingPathComponent("gone.txt")
        try Data().write(to: source)
        let codec = FileReferenceCodec()
        let item = try codec.makeItem(for: source)

        try FileManager.default.removeItem(at: source)
        let resolution = codec.resolve(item)

        #expect(!resolution.isAvailable)
        #expect(resolution.url == nil)
        try? FileManager.default.removeItem(at: directory)
    }
}

@Suite("Private data directory")
struct PrivateDataDirectoryTests {
    @Test("Existing data is migrated to owner-only permissions")
    func repairsExistingPermissions() throws {
        let fileManager = FileManager.default
        let directory = fileManager.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fileManager.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o755]
        )
        for name in ["draft.txt", "shelf.json", "settings.json"] {
            let url = directory.appendingPathComponent(name)
            try Data().write(to: url)
            try fileManager.setAttributes(
                [.posixPermissions: 0o644],
                ofItemAtPath: url.path
            )
        }

        try PrivateDataDirectory(directory: directory).prepare()

        let directoryMode = try fileManager.attributesOfItem(
            atPath: directory.path
        )[.posixPermissions] as? NSNumber
        #expect(directoryMode?.intValue == 0o700)
        for name in ["draft.txt", "shelf.json", "settings.json"] {
            let mode = try fileManager.attributesOfItem(
                atPath: directory.appendingPathComponent(name).path
            )[.posixPermissions] as? NSNumber
            #expect(mode?.intValue == 0o600)
        }
        try? fileManager.removeItem(at: directory)
    }
}
