import Foundation
import Testing
@testable import LedgeCore

@Suite("Finder file promises")
struct PromisedFileWriterTests {
    @Test("A promised file is fully copied before its source may be removed")
    func writesFileWithoutRemovingSource() throws {
        let workspace = try makeWorkspace()
        let source = workspace.appendingPathComponent("source.txt")
        let destination = workspace.appendingPathComponent("delivered.txt")
        try Data("complete payload".utf8).write(to: source)

        try PromisedFileWriter().write(
            sourceURL: source,
            destinationURL: destination
        )

        #expect(try Data(contentsOf: destination) == Data("complete payload".utf8))
        #expect(try Data(contentsOf: source) == Data("complete payload".utf8))
        try? FileManager.default.removeItem(at: workspace)
    }

    @Test("A promised folder includes all nested contents")
    func writesFolder() throws {
        let workspace = try makeWorkspace()
        let source = workspace.appendingPathComponent("Source Folder")
        let destination = workspace.appendingPathComponent("Delivered Folder")
        try FileManager.default.createDirectory(
            at: source,
            withIntermediateDirectories: true
        )
        try Data("nested".utf8).write(
            to: source.appendingPathComponent("nested.txt")
        )

        try PromisedFileWriter().write(
            sourceURL: source,
            destinationURL: destination
        )

        #expect(
            try Data(contentsOf: destination.appendingPathComponent("nested.txt"))
                == Data("nested".utf8)
        )
        #expect(FileManager.default.fileExists(atPath: source.path))
        try? FileManager.default.removeItem(at: workspace)
    }

    @Test("A failed promise never alters its source or an occupied destination")
    func failurePreservesBothSides() throws {
        let workspace = try makeWorkspace()
        let source = workspace.appendingPathComponent("source.txt")
        let destination = workspace.appendingPathComponent("occupied.txt")
        try Data("source".utf8).write(to: source)
        try Data("destination".utf8).write(to: destination)

        #expect(throws: PromisedFileWriterError.self) {
            try PromisedFileWriter().write(
                sourceURL: source,
                destinationURL: destination
            )
        }
        #expect(try Data(contentsOf: source) == Data("source".utf8))
        #expect(try Data(contentsOf: destination) == Data("destination".utf8))
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
}
