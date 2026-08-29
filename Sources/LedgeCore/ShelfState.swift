import Foundation

public enum ShelfItemStorage: Equatable, Hashable, Sendable {
    case bookmark(Data)
    case transit(relativePath: String)

    public var isTransit: Bool {
        if case .transit = self { return true }
        return false
    }
}

public struct ShelfItem: Codable, Equatable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public let displayName: String
    public let storage: ShelfItemStorage
    public let addedAt: Date
    public let isDirectory: Bool

    public init(
        id: UUID = UUID(),
        displayName: String,
        bookmark: Data,
        addedAt: Date = Date(),
        isDirectory: Bool = false
    ) {
        self.id = id
        self.displayName = displayName
        storage = .bookmark(bookmark)
        self.addedAt = addedAt
        self.isDirectory = isDirectory
    }

    public init(
        id: UUID = UUID(),
        displayName: String,
        transitRelativePath: String,
        addedAt: Date = Date(),
        isDirectory: Bool = false
    ) {
        self.id = id
        self.displayName = displayName
        storage = .transit(relativePath: transitRelativePath)
        self.addedAt = addedAt
        self.isDirectory = isDirectory
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case displayName
        case bookmark
        case transitRelativePath
        case addedAt
        case isDirectory
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        displayName = try container.decode(String.self, forKey: .displayName)
        addedAt = try container.decode(Date.self, forKey: .addedAt)
        isDirectory = try container.decodeIfPresent(
            Bool.self,
            forKey: .isDirectory
        ) ?? false

        if let relativePath = try container.decodeIfPresent(
            String.self,
            forKey: .transitRelativePath
        ) {
            storage = .transit(relativePath: relativePath)
        } else if let bookmark = try container.decodeIfPresent(
            Data.self,
            forKey: .bookmark
        ) {
            storage = .bookmark(bookmark)
        } else {
            throw DecodingError.dataCorruptedError(
                forKey: .transitRelativePath,
                in: container,
                debugDescription: "Shelf item has no storage payload."
            )
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(displayName, forKey: .displayName)
        try container.encode(addedAt, forKey: .addedAt)
        try container.encode(isDirectory, forKey: .isDirectory)

        switch storage {
        case .bookmark(let bookmark):
            try container.encode(bookmark, forKey: .bookmark)
        case .transit(let relativePath):
            try container.encode(
                relativePath,
                forKey: .transitRelativePath
            )
        }
    }
}

public struct ShelfState: Codable, Equatable, Sendable {
    public let items: [ShelfItem]

    public init(items: [ShelfItem] = []) {
        self.items = items
    }

    public func adding(_ newItems: [ShelfItem]) -> ShelfState {
        ShelfState(items: items + newItems)
    }

    public func removing(id: ShelfItem.ID) -> ShelfState {
        ShelfState(items: items.filter { $0.id != id })
    }

    public func replacing(_ item: ShelfItem) -> ShelfState {
        ShelfState(items: items.map { $0.id == item.id ? item : $0 })
    }
}

public enum RemovalPolicy: Sendable {
    case removeAfterSuccessfulDrag
    case keep

    public func shouldRemove(dragOperationSucceeded: Bool) -> Bool {
        self == .removeAfterSuccessfulDrag && dragOperationSucceeded
    }
}
