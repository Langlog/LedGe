import Foundation
import Testing
@testable import LedgeCore

@Suite("Transit store")
struct TransitStoreTests {
    @Test("A legacy bookmark item still decodes without moving anything")
    func legacyBookmarkCompatibility() throws {
        let original = LegacyShelfItem(
            id: UUID(),
            displayName: "legacy.txt",
            bookmark: Data([1, 2, 3]),
            addedAt: Date(timeIntervalSince1970: 12),
            isDirectory: false
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ShelfItem.self, from: data)

        #expect(decoded.storage == .bookmark(Data([1, 2, 3])))
    }

    @Test("Import moves a file into a private UUID container")
    func importsFileByMovingIt() throws {
        let workspace = try makeWorkspace()
        let source = workspace.appendingPathComponent("source.txt")
        try Data("payload".utf8).write(to: source)
        let store = makeStore(in: workspace)

        let imports = try store.stage([source])
        let imported = try #require(imports.first)
        let storedURL = try #require(store.resolve(imported.item))

        #expect(!FileManager.default.fileExists(atPath: source.path))
        #expect(storedURL.lastPathComponent == "source.txt")
        #expect(try Data(contentsOf: storedURL) == Data("payload".utf8))
        #expect(imported.item.storage.isTransit)
        try? FileManager.default.removeItem(at: workspace)
    }

    @Test("An external Finder move is copied into transit before Finder removes its source")
    func stagesExternalMoveWithoutRemovingSource() throws {
        let workspace = try makeWorkspace()
        let source = workspace.appendingPathComponent("finder-source.txt")
        try Data("payload".utf8).write(to: source)
        let store = makeStore(in: workspace)

        let imports = try store.stageExternalMove([source])
        let imported = try #require(imports.first)
        let storedURL = try #require(store.resolve(imported.item))

        #expect(FileManager.default.fileExists(atPath: source.path))
        #expect(try Data(contentsOf: source) == Data("payload".utf8))
        #expect(try Data(contentsOf: storedURL) == Data("payload".utf8))
        try? FileManager.default.removeItem(at: workspace)
    }

    @Test("Discarding a failed external move preserves the Finder source")
    func discardsExternalMoveCopyOnly() throws {
        let workspace = try makeWorkspace()
        let source = workspace.appendingPathComponent("preserved.txt")
        try Data("original".utf8).write(to: source)
        let store = makeStore(in: workspace)
        let imports = try store.stageExternalMove([source])

        try store.discardStagedCopies(imports)

        #expect(FileManager.default.fileExists(atPath: source.path))
        #expect(try Data(contentsOf: source) == Data("original".utf8))
        #expect(store.resolve(imports[0].item) == nil)
        try? FileManager.default.removeItem(at: workspace)
    }

    @Test("An external Finder folder move copies all contents before source cleanup")
    func stagesExternalFolderMove() throws {
        let workspace = try makeWorkspace()
        let source = workspace.appendingPathComponent(
            "Finder Folder",
            isDirectory: true
        )
        try FileManager.default.createDirectory(
            at: source,
            withIntermediateDirectories: true
        )
        try Data("nested".utf8).write(
            to: source.appendingPathComponent("nested.txt")
        )
        let store = makeStore(in: workspace)

        let imported = try #require(
            try store.stageExternalMove([source]).first
        )
        let storedURL = try #require(store.resolve(imported.item))

        #expect(FileManager.default.fileExists(atPath: source.path))
        #expect(
            try Data(contentsOf: storedURL.appendingPathComponent("nested.txt"))
                == Data("nested".utf8)
        )
        try? FileManager.default.removeItem(at: workspace)
    }

    @Test("Import preserves a folder and its contents")
    func importsDirectory() throws {
        let workspace = try makeWorkspace()
        let source = workspace.appendingPathComponent(
            "Folder",
            isDirectory: true
        )
        try FileManager.default.createDirectory(
            at: source,
            withIntermediateDirectories: true
        )
        try Data("nested".utf8).write(
            to: source.appendingPathComponent("nested.txt")
        )
        let store = makeStore(in: workspace)

        let imported = try #require(try store.stage([source]).first)
        let storedURL = try #require(store.resolve(imported.item))

        #expect(imported.item.isDirectory)
        #expect(
            FileManager.default.fileExists(
                atPath: storedURL
                    .appendingPathComponent("nested.txt")
                    .path
            )
        )
        try? FileManager.default.removeItem(at: workspace)
    }

    @Test("Two equal file names never collide")
    func duplicateNamesUseSeparateContainers() throws {
        let workspace = try makeWorkspace()
        let firstDirectory = workspace.appendingPathComponent("one")
        let secondDirectory = workspace.appendingPathComponent("two")
        try FileManager.default.createDirectory(
            at: firstDirectory,
            withIntermediateDirectories: true
        )
        try FileManager.default.createDirectory(
            at: secondDirectory,
            withIntermediateDirectories: true
        )
        let first = firstDirectory.appendingPathComponent("same.txt")
        let second = secondDirectory.appendingPathComponent("same.txt")
        try Data("one".utf8).write(to: first)
        try Data("two".utf8).write(to: second)
        let store = makeStore(in: workspace)

        let imports = try store.stage([first, second])
        let firstURL = try #require(store.resolve(imports[0].item))
        let secondURL = try #require(store.resolve(imports[1].item))

        #expect(firstURL != secondURL)
        #expect(try Data(contentsOf: firstURL) == Data("one".utf8))
        #expect(try Data(contentsOf: secondURL) == Data("two".utf8))
        try? FileManager.default.removeItem(at: workspace)
    }

    @Test("Invalid batches are rejected before any source moves")
    func validatesWholeBatchBeforeMoving() throws {
        let workspace = try makeWorkspace()
        let existing = workspace.appendingPathComponent("existing.txt")
        let missing = workspace.appendingPathComponent("missing.txt")
        try Data("safe".utf8).write(to: existing)
        let store = makeStore(in: workspace)

        #expect(throws: TransitStoreError.self) {
            try store.stage([existing, missing])
        }
        #expect(FileManager.default.fileExists(atPath: existing.path))
        try? FileManager.default.removeItem(at: workspace)
    }

    @Test("Rollback restores the source to its original path")
    func rollback() throws {
        let workspace = try makeWorkspace()
        let source = workspace.appendingPathComponent("return.txt")
        try Data("return".utf8).write(to: source)
        let store = makeStore(in: workspace)
        let imports = try store.stage([source])

        try store.rollback(imports)

        #expect(FileManager.default.fileExists(atPath: source.path))
        #expect(store.resolve(imports[0].item) == nil)
        try? FileManager.default.removeItem(at: workspace)
    }

    @Test("A tampered relative path cannot escape the transit root")
    func blocksPathTraversal() throws {
        let workspace = try makeWorkspace()
        let store = makeStore(in: workspace)
        let item = ShelfItem(
            id: UUID(),
            displayName: "outside.txt",
            transitRelativePath: "../outside.txt"
        )

        #expect(store.resolve(item) == nil)
        try? FileManager.default.removeItem(at: workspace)
    }

    @Test("The transit root itself cannot be imported into itself")
    func rejectsTransitRoot() throws {
        let workspace = try makeWorkspace()
        let transit = workspace.appendingPathComponent(
            "Transit",
            isDirectory: true
        )
        try FileManager.default.createDirectory(
            at: transit,
            withIntermediateDirectories: true
        )
        let store = makeStore(in: workspace)

        #expect(throws: TransitStoreError.self) {
            try store.stage([transit])
        }
        try? FileManager.default.removeItem(at: workspace)
    }

    @Test("Successful export removes the internal source")
    func finalizesExport() throws {
        let workspace = try makeWorkspace()
        let source = workspace.appendingPathComponent("export.txt")
        try Data("export".utf8).write(to: source)
        let store = makeStore(in: workspace)
        let imported = try #require(try store.stage([source]).first)
        let storedURL = try #require(store.resolve(imported.item))

        try store.finalizeExport(imported.item)

        #expect(!FileManager.default.fileExists(atPath: storedURL.path))
        #expect(store.resolve(imported.item) == nil)
        try? FileManager.default.removeItem(at: workspace)
    }

    @Test("Export cleanup refuses a symlinked UUID container")
    func rejectsSymlinkedExportContainer() throws {
        let workspace = try makeWorkspace()
        let source = workspace.appendingPathComponent("protected.txt")
        try Data("transit".utf8).write(to: source)
        let store = makeStore(in: workspace)
        let imported = try #require(try store.stage([source]).first)
        let storedURL = try #require(store.resolve(imported.item))
        let container = storedURL.deletingLastPathComponent()
        let preservedContainer = workspace.appendingPathComponent(
            "preserved-container",
            isDirectory: true
        )
        try FileManager.default.moveItem(
            at: container,
            to: preservedContainer
        )
        let outside = workspace.appendingPathComponent(
            "outside",
            isDirectory: true
        )
        try FileManager.default.createDirectory(
            at: outside,
            withIntermediateDirectories: true
        )
        let outsideFile = outside.appendingPathComponent("protected.txt")
        try Data("outside".utf8).write(to: outsideFile)
        try FileManager.default.createSymbolicLink(
            at: container,
            withDestinationURL: outside
        )

        #expect(throws: TransitStoreError.self) {
            try store.finalizeExport(imported.item)
        }
        #expect(try Data(contentsOf: outsideFile) == Data("outside".utf8))
        try? FileManager.default.removeItem(at: workspace)
    }

    @Test("An orphaned transit file is recoverable after restart")
    func recoversOrphan() throws {
        let workspace = try makeWorkspace()
        let source = workspace.appendingPathComponent("orphan.txt")
        try Data("orphan".utf8).write(to: source)
        let store = makeStore(in: workspace)
        let imported = try #require(try store.stage([source]).first)

        let recovered = try store.recoverItems(excluding: [])

        #expect(recovered == [imported.item])
        try? FileManager.default.removeItem(at: workspace)
    }

    @Test("A hidden transit file is also recoverable")
    func recoversHiddenOrphan() throws {
        let workspace = try makeWorkspace()
        let source = workspace.appendingPathComponent(".private-note")
        try Data("hidden".utf8).write(to: source)
        let store = makeStore(in: workspace)
        let imported = try #require(try store.stage([source]).first)

        let recovered = try store.recoverItems(excluding: [])

        #expect(recovered == [imported.item])
        try? FileManager.default.removeItem(at: workspace)
    }

    private func makeWorkspace() throws -> URL {
        let workspace = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: workspace,
            withIntermediateDirectories: true
        )
        return workspace
    }

    private func makeStore(in workspace: URL) -> TransitStore {
        TransitStore(
            directory: workspace.appendingPathComponent(
                "Transit",
                isDirectory: true
            )
        )
    }
}

private struct LegacyShelfItem: Encodable {
    let id: UUID
    let displayName: String
    let bookmark: Data
    let addedAt: Date
    let isDirectory: Bool
}
