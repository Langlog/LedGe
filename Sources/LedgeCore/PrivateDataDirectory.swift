import Foundation

public struct PrivateDataDirectory {
    private let directory: URL
    private let fileManager: FileManager

    public init(
        directory: URL,
        fileManager: FileManager = .default
    ) {
        self.directory = directory
        self.fileManager = fileManager
    }

    public func prepare() throws {
        try fileManager.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        try fileManager.setAttributes(
            [.posixPermissions: 0o700],
            ofItemAtPath: directory.path
        )

        for fileName in ["draft.txt", "shelf.json", "settings.json"] {
            let fileURL = directory.appendingPathComponent(fileName)
            guard fileManager.fileExists(atPath: fileURL.path) else { continue }
            try fileManager.setAttributes(
                [.posixPermissions: 0o600],
                ofItemAtPath: fileURL.path
            )
        }
    }
}
