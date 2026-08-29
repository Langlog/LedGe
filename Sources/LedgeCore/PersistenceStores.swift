import Foundation

private struct VersionedPayload<Value: Codable>: Codable {
    let schemaVersion: Int
    let value: Value
}

private struct JSONDiskStore<Value: Codable> {
    let directory: URL
    let fileName: String
    let fallback: Value
    let fileManager: FileManager

    func load() throws -> Value {
        let fileURL = directory.appendingPathComponent(fileName)
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return fallback
        }
        let payload = try JSONDecoder().decode(
            VersionedPayload<Value>.self,
            from: Data(contentsOf: fileURL)
        )
        return payload.value
    }

    func save(_ value: Value) throws {
        try fileManager.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        let payload = VersionedPayload(schemaVersion: 1, value: value)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let fileURL = directory.appendingPathComponent(fileName)
        try encoder.encode(payload).write(to: fileURL, options: .atomic)
        try fileManager.setAttributes(
            [.posixPermissions: 0o600],
            ofItemAtPath: fileURL.path
        )
    }
}

public struct ShelfStore {
    private let store: JSONDiskStore<ShelfState>

    public init(
        directory: URL,
        fileManager: FileManager = .default
    ) {
        store = JSONDiskStore(
            directory: directory,
            fileName: "shelf.json",
            fallback: ShelfState(),
            fileManager: fileManager
        )
    }

    public func load() throws -> ShelfState {
        try store.load()
    }

    public func save(_ state: ShelfState) throws {
        try store.save(state)
    }
}

public struct SettingsStore {
    private let store: JSONDiskStore<LedgeSettings>

    public init(
        directory: URL,
        fileManager: FileManager = .default
    ) {
        store = JSONDiskStore(
            directory: directory,
            fileName: "settings.json",
            fallback: .default,
            fileManager: fileManager
        )
    }

    public func load() throws -> LedgeSettings {
        try store.load()
    }

    public func save(_ settings: LedgeSettings) throws {
        try store.save(settings)
    }
}
