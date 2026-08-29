import Foundation

public struct FileResolution: Equatable, Sendable {
    public let url: URL?
    public let isAvailable: Bool
    public let bookmarkIsStale: Bool

    public init(
        url: URL?,
        isAvailable: Bool,
        bookmarkIsStale: Bool
    ) {
        self.url = url
        self.isAvailable = isAvailable
        self.bookmarkIsStale = bookmarkIsStale
    }
}

public struct FileReferenceCodec {
    private let fileManager: FileManager

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    public func makeItem(for url: URL) throws -> ShelfItem {
        let values = try url.resourceValues(forKeys: [.isDirectoryKey])
        let bookmark = try url.bookmarkData(
            options: [.minimalBookmark],
            includingResourceValuesForKeys: [.isDirectoryKey],
            relativeTo: nil
        )
        return ShelfItem(
            displayName: url.lastPathComponent,
            bookmark: bookmark,
            isDirectory: values.isDirectory ?? false
        )
    }

    public func resolve(_ item: ShelfItem) -> FileResolution {
        guard case .bookmark(let bookmark) = item.storage else {
            return FileResolution(
                url: nil,
                isAvailable: false,
                bookmarkIsStale: false
            )
        }
        var stale = false
        guard let url = try? URL(
            resolvingBookmarkData: bookmark,
            options: [.withoutUI],
            relativeTo: nil,
            bookmarkDataIsStale: &stale
        ), fileManager.fileExists(atPath: url.path) else {
            return FileResolution(
                url: nil,
                isAvailable: false,
                bookmarkIsStale: stale
            )
        }
        return FileResolution(
            url: url,
            isAvailable: true,
            bookmarkIsStale: stale
        )
    }
}
