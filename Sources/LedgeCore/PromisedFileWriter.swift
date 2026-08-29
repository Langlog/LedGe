import Foundation

public enum PromisedFileWriterError: Error, Equatable {
    case invalidSource(URL)
    case invalidDestination(URL)
    case sourceEqualsDestination(URL)
    case destinationOccupied(URL)
    case incompleteWrite(URL)
}

public struct PromisedFileWriter: Sendable {
    public init() {}

    public func write(
        sourceURL: URL,
        destinationURL: URL,
        fileManager: FileManager = .default
    ) throws {
        let source = sourceURL.standardizedFileURL
        let destination = destinationURL.standardizedFileURL

        guard source.isFileURL,
              fileManager.fileExists(atPath: source.path)
        else { throw PromisedFileWriterError.invalidSource(source) }
        guard destination.isFileURL,
              fileManager.fileExists(
                atPath: destination.deletingLastPathComponent().path
              )
        else {
            throw PromisedFileWriterError.invalidDestination(destination)
        }
        guard source != destination else {
            throw PromisedFileWriterError.sourceEqualsDestination(source)
        }
        guard !fileManager.fileExists(atPath: destination.path) else {
            throw PromisedFileWriterError.destinationOccupied(destination)
        }

        let stagingURL = destination.deletingLastPathComponent()
            .appendingPathComponent(
                ".ledge-promise-\(UUID().uuidString)",
                isDirectory: false
            )
        defer {
            if fileManager.fileExists(atPath: stagingURL.path) {
                try? fileManager.removeItem(at: stagingURL)
            }
        }

        do {
            try fileManager.copyItem(at: source, to: stagingURL)
            try fileManager.moveItem(at: stagingURL, to: destination)
            guard fileManager.fileExists(atPath: destination.path) else {
                throw PromisedFileWriterError.incompleteWrite(destination)
            }
        } catch {
            throw error
        }
    }
}
