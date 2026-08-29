import Foundation

public struct DraftStore {
    private let directory: URL
    private let fileManager: FileManager

    public init(
        directory: URL,
        fileManager: FileManager = .default
    ) {
        self.directory = directory
        self.fileManager = fileManager
    }

    public func load() throws -> String {
        let fileURL = directory.appendingPathComponent("draft.txt")
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return ""
        }
        return try String(contentsOf: fileURL, encoding: .utf8)
    }

    public func save(_ text: String) throws {
        try fileManager.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        try fileManager.setAttributes(
            [.posixPermissions: 0o700],
            ofItemAtPath: directory.path
        )
        let data = Data(text.utf8)
        let fileURL = directory.appendingPathComponent("draft.txt")
        try data.write(to: fileURL, options: .atomic)
        try fileManager.setAttributes(
            [.posixPermissions: 0o600],
            ofItemAtPath: fileURL.path
        )
    }
}
