import Foundation

public struct TransitImport: Equatable, Sendable {
    public let item: ShelfItem
    public let originalURL: URL
    public let storedURL: URL

    public init(item: ShelfItem, originalURL: URL, storedURL: URL) {
        self.item = item
        self.originalURL = originalURL
        self.storedURL = storedURL
    }
}

public enum TransitStoreError: Error, Equatable {
    case invalidSource(URL)
    case duplicateSource(URL)
    case nestedSources(URL, URL)
    case sourceInsideTransit(URL)
    case unsafeStoredPath(String)
    case rollbackDestinationOccupied(URL)
    case moveFailed(URL)
}

public struct TransitStore {
    private enum StagingOperation {
        case move
        case copy
    }

    private let directory: URL
    private let fileManager: FileManager

    public init(directory: URL, fileManager: FileManager = .default) {
        self.directory = directory.standardizedFileURL
        self.fileManager = fileManager
    }

    public func stage(_ sourceURLs: [URL]) throws -> [TransitImport] {
        try stage(sourceURLs, operation: .move)
    }

    public func stageExternalMove(
        _ sourceURLs: [URL]
    ) throws -> [TransitImport] {
        try stage(sourceURLs, operation: .copy)
    }

    private func stage(
        _ sourceURLs: [URL],
        operation: StagingOperation
    ) throws -> [TransitImport] {
        let sources = try validatedSources(sourceURLs)
        guard !sources.isEmpty else { return [] }
        try prepareDirectory()

        var imports: [TransitImport] = []
        do {
            for source in sources {
                imports.append(try stageOne(source, operation: operation))
            }
            return imports
        } catch {
            switch operation {
            case .move:
                try? rollback(imports)
            case .copy:
                try? discardStagedCopies(imports)
            }
            throw error
        }
    }

    public func resolve(_ item: ShelfItem) -> URL? {
        guard case .transit(let relativePath) = item.storage,
              let storedURL = safeStoredURL(
                for: item,
                relativePath: relativePath
              ),
              fileManager.fileExists(atPath: storedURL.path),
              containerIsSafe(storedURL.deletingLastPathComponent())
        else { return nil }
        return storedURL
    }

    public func rollback(_ imports: [TransitImport]) throws {
        var firstError: Error?
        for transitImport in imports.reversed() {
            do {
                try rollbackOne(transitImport)
            } catch {
                if firstError == nil { firstError = error }
            }
        }
        if let firstError { throw firstError }
    }

    public func discardStagedCopies(_ imports: [TransitImport]) throws {
        var firstError: Error?
        for transitImport in imports.reversed() {
            do {
                try finalizeExport(transitImport.item)
            } catch {
                if firstError == nil { firstError = error }
            }
        }
        if let firstError { throw firstError }
    }

    public func finalizeExport(_ item: ShelfItem) throws {
        guard case .transit(let relativePath) = item.storage,
              let storedURL = safeStoredURL(
                for: item,
                relativePath: relativePath
              ),
              containerIsSafe(storedURL.deletingLastPathComponent())
        else {
            throw TransitStoreError.unsafeStoredPath(item.displayName)
        }

        if fileManager.fileExists(atPath: storedURL.path) {
            try fileManager.removeItem(at: storedURL)
        }
        try removeContainerIfEmpty(storedURL.deletingLastPathComponent())
    }

    public func recoverItems(excluding items: [ShelfItem]) throws -> [ShelfItem] {
        try prepareDirectory()
        let knownPaths = Set(items.compactMap { item -> String? in
            guard case .transit(let path) = item.storage else { return nil }
            return path
        })
        let containers = try fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [
                .isDirectoryKey,
                .isSymbolicLinkKey,
                .creationDateKey
            ],
            options: [.skipsHiddenFiles]
        )

        return try containers.compactMap { container in
            guard let id = UUID(uuidString: container.lastPathComponent),
                  containerIsSafe(container)
            else { return nil }
            let children = try fileManager.contentsOfDirectory(
                at: container,
                includingPropertiesForKeys: [
                    .isDirectoryKey,
                    .creationDateKey
                ],
                options: []
            )
            guard children.count == 1, let child = children.first else {
                return nil
            }
            let relativePath = "\(id.uuidString)/\(child.lastPathComponent)"
            guard !knownPaths.contains(relativePath) else { return nil }
            let values = try child.resourceValues(
                forKeys: [.isDirectoryKey, .creationDateKey]
            )
            let containerValues = try container.resourceValues(
                forKeys: [.creationDateKey]
            )
            return ShelfItem(
                id: id,
                displayName: child.lastPathComponent,
                transitRelativePath: relativePath,
                addedAt: containerValues.creationDate
                    ?? values.creationDate
                    ?? Date(),
                isDirectory: values.isDirectory ?? false
            )
        }
        .sorted { $0.addedAt < $1.addedAt }
    }

    private func validatedSources(_ sourceURLs: [URL]) throws -> [URL] {
        let sources = sourceURLs.map(\.standardizedFileURL)
        var paths = Set<String>()
        for source in sources {
            guard source.isFileURL,
                  fileManager.fileExists(atPath: source.path),
                  !source.lastPathComponent.isEmpty
            else { throw TransitStoreError.invalidSource(source) }
            guard paths.insert(source.path).inserted else {
                throw TransitStoreError.duplicateSource(source)
            }
            guard source != directory,
                  !isDescendant(source, of: directory)
            else {
                throw TransitStoreError.sourceInsideTransit(source)
            }
        }

        for (index, source) in sources.enumerated() {
            for other in sources.dropFirst(index + 1) {
                if isDescendant(source, of: other)
                    || isDescendant(other, of: source) {
                    throw TransitStoreError.nestedSources(source, other)
                }
            }
        }
        return sources
    }

    private func stageOne(
        _ source: URL,
        operation: StagingOperation
    ) throws -> TransitImport {
        let sourceValues = try source.resourceValues(
            forKeys: [.isDirectoryKey]
        )
        let id = UUID()
        let container = directory.appendingPathComponent(
            id.uuidString,
            isDirectory: true
        )
        try fileManager.createDirectory(
            at: container,
            withIntermediateDirectories: false,
            attributes: [.posixPermissions: 0o700]
        )
        let containerValues: URLResourceValues
        do {
            containerValues = try container.resourceValues(
                forKeys: [.creationDateKey]
            )
        } catch {
            try? fileManager.removeItem(at: container)
            throw error
        }
        let storedURL = container.appendingPathComponent(
            source.lastPathComponent,
            isDirectory: false
        )
        let relativePath = "\(id.uuidString)/\(source.lastPathComponent)"
        let item = ShelfItem(
            id: id,
            displayName: source.lastPathComponent,
            transitRelativePath: relativePath,
            addedAt: containerValues.creationDate ?? Date(),
            isDirectory: sourceValues.isDirectory ?? false
        )

        do {
            switch operation {
            case .move:
                try movePreservingSourceOnFailure(
                    from: source,
                    to: storedURL
                )
            case .copy:
                try fileManager.copyItem(at: source, to: storedURL)
            }
            return TransitImport(
                item: item,
                originalURL: source,
                storedURL: storedURL
            )
        } catch {
            try? fileManager.removeItem(at: container)
            throw error
        }
    }

    private func movePreservingSourceOnFailure(from source: URL, to target: URL) throws {
        do {
            try fileManager.moveItem(at: source, to: target)
            return
        } catch {
            if !fileManager.fileExists(atPath: source.path),
               fileManager.fileExists(atPath: target.path) {
                return
            }
            guard fileManager.fileExists(atPath: source.path),
                  !fileManager.fileExists(atPath: target.path)
            else { throw error }
        }

        do {
            try fileManager.copyItem(at: source, to: target)
            guard fileManager.fileExists(atPath: target.path) else {
                throw TransitStoreError.moveFailed(source)
            }
            try fileManager.removeItem(at: source)
        } catch {
            try? fileManager.removeItem(at: target)
            throw error
        }
    }

    private func rollbackOne(_ transitImport: TransitImport) throws {
        guard containerIsSafe(
            transitImport.storedURL.deletingLastPathComponent()
        ) else {
            throw TransitStoreError.unsafeStoredPath(
                transitImport.item.displayName
            )
        }
        guard fileManager.fileExists(atPath: transitImport.storedURL.path) else {
            return
        }
        guard !fileManager.fileExists(atPath: transitImport.originalURL.path) else {
            throw TransitStoreError.rollbackDestinationOccupied(
                transitImport.originalURL
            )
        }
        try movePreservingSourceOnFailure(
            from: transitImport.storedURL,
            to: transitImport.originalURL
        )
        try removeContainerIfEmpty(
            transitImport.storedURL.deletingLastPathComponent()
        )
    }

    private func safeStoredURL(
        for item: ShelfItem,
        relativePath: String
    ) -> URL? {
        let components = relativePath.split(
            separator: "/",
            omittingEmptySubsequences: false
        ).map(String.init)
        guard components.count == 2,
              components[0] == item.id.uuidString,
              components[1] == item.displayName,
              components.allSatisfy({ !$0.isEmpty && $0 != "." && $0 != ".." })
        else { return nil }
        let container = directory.appendingPathComponent(
            components[0],
            isDirectory: true
        )
        let result = container.appendingPathComponent(components[1])
            .standardizedFileURL
        guard result.deletingLastPathComponent() == container.standardizedFileURL
        else { return nil }
        return result
    }

    private func prepareDirectory() throws {
        try fileManager.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        try fileManager.setAttributes(
            [.posixPermissions: 0o700],
            ofItemAtPath: directory.path
        )
    }

    private func containerIsSafe(_ container: URL) -> Bool {
        guard container.deletingLastPathComponent().standardizedFileURL
                == directory,
              UUID(uuidString: container.lastPathComponent) != nil,
              let values = try? container.resourceValues(
                forKeys: [.isDirectoryKey, .isSymbolicLinkKey]
              )
        else { return false }
        return values.isDirectory == true && values.isSymbolicLink != true
    }

    private func removeContainerIfEmpty(_ container: URL) throws {
        guard fileManager.fileExists(atPath: container.path),
              containerIsSafe(container)
        else { return }
        let contents = try fileManager.contentsOfDirectory(atPath: container.path)
        if contents.isEmpty {
            try fileManager.removeItem(at: container)
        }
    }

    private func isDescendant(_ candidate: URL, of parent: URL) -> Bool {
        let candidateComponents = candidate.standardizedFileURL.pathComponents
        let parentComponents = parent.standardizedFileURL.pathComponents
        guard candidateComponents.count > parentComponents.count else {
            return false
        }
        return candidateComponents.prefix(parentComponents.count)
            .elementsEqual(parentComponents)
    }
}
