import AppKit
import Combine
import LedgeCore
import ServiceManagement

struct ResolvedShelfItem: Identifiable {
    let item: ShelfItem
    let url: URL?

    var id: ShelfItem.ID { item.id }
    var isAvailable: Bool { url != nil }
    var isTransit: Bool { item.storage.isTransit }
}

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var shelf: ShelfState
    @Published var draft: String {
        didSet { persistDraft() }
    }
    @Published private(set) var settings: LedgeSettings
    @Published var surface: LedgeSurface = .hidden
    @Published var isDropTargeted = false
    @Published var isExternalDragActive = false
    @Published var persistenceMessage: String?

    let dataDirectory: URL

    private let shelfStore: ShelfStore
    private let settingsStore: SettingsStore
    private let draftStore: DraftStore
    private let transitStore: TransitStore
    private let fileManager: FileManager
    private let referenceCodec = FileReferenceCodec()
    private var draftSaveTask: Task<Void, Never>?

    init(fileManager: FileManager = .default) {
        let applicationSupport = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? fileManager.homeDirectoryForCurrentUser
        let directory = applicationSupport.appendingPathComponent(
            "Ledge",
            isDirectory: true
        )
        let newShelfStore = ShelfStore(
            directory: directory,
            fileManager: fileManager
        )
        let newTransitStore = TransitStore(
            directory: directory.appendingPathComponent(
                "Transit",
                isDirectory: true
            ),
            fileManager: fileManager
        )
        try? PrivateDataDirectory(
            directory: directory,
            fileManager: fileManager
        ).prepare()
        let loadedShelf = (try? newShelfStore.load()) ?? ShelfState()
        let retainedItems = loadedShelf.items.filter { item in
            !item.storage.isTransit || newTransitStore.resolve(item) != nil
        }
        let recoveredItems = (
            try? newTransitStore.recoverItems(excluding: retainedItems)
        ) ?? []
        let reconciledShelf = ShelfState(
            items: retainedItems + recoveredItems
        )

        dataDirectory = directory
        shelfStore = newShelfStore
        settingsStore = SettingsStore(directory: directory, fileManager: fileManager)
        draftStore = DraftStore(directory: directory, fileManager: fileManager)
        transitStore = newTransitStore
        self.fileManager = fileManager
        shelf = reconciledShelf
        settings = (try? settingsStore.load()) ?? .default
        draft = (try? draftStore.load()) ?? ""

        if reconciledShelf != loadedShelf {
            try? newShelfStore.save(reconciledShelf)
        }
    }

    var resolvedItems: [ResolvedShelfItem] {
        shelf.items.map { item in
            let url: URL? = switch item.storage {
            case .bookmark:
                referenceCodec.resolve(item).url
            case .transit:
                transitStore.resolve(item)
            }
            return ResolvedShelfItem(
                item: item,
                url: url
            )
        }
    }

    func receiveExternalFileMove(_ urls: [URL]) -> Bool {
        guard !urls.isEmpty else { return false }

        do {
            let imports = try transitStore.stageExternalMove(urls)
            guard !imports.isEmpty else { return false }
            let updatedShelf = shelf.adding(imports.map(\.item))
            do {
                try shelfStore.save(updatedShelf)
            } catch {
                try transitStore.discardStagedCopies(imports)
                throw error
            }
            shelf = updatedShelf
            persistenceMessage = nil
            return true
        } catch {
            recoverTransitOrphans()
            persistenceMessage = "文件未能完整移入中转站，原文件仍保留在原位置。"
            return false
        }
    }

    func send(_ event: LedgeActivationEvent) {
        surface = LedgeActivationState.transition(
            from: surface,
            on: event
        )
    }

    func removeItem(id: ShelfItem.ID) {
        shelf = shelf.removing(id: id)
        persistShelf()
    }

    func completePromisedFileExport(id: ShelfItem.ID) {
        guard settings.removeAfterSuccessfulDrag,
              let item = shelf.items.first(where: { $0.id == id })
        else { return }

        do {
            switch item.storage {
            case .transit:
                try transitStore.finalizeExport(item)
            case .bookmark:
                if let sourceURL = referenceCodec.resolve(item).url,
                   fileManager.fileExists(atPath: sourceURL.path) {
                    try fileManager.removeItem(at: sourceURL)
                }
            }
            shelf = shelf.removing(id: id)
            persistShelf()
        } catch {
            persistenceMessage = "文件已拖出，但中转记录暂时无法清理。"
        }
    }

    func setDisplayMode(_ value: DisplayMode) {
        updateSettings(settings.with(displayMode: value))
    }

    func setWakeSensitivity(_ value: WakeSensitivity) {
        updateSettings(settings.with(wakeSensitivity: value))
    }

    func setRemoveAfterDrag(_ value: Bool) {
        updateSettings(settings.with(removeAfterSuccessfulDrag: value))
    }

    func setLaunchAtLogin(_ value: Bool) {
        do {
            if value {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            updateSettings(settings.with(launchAtLogin: value))
        } catch {
            persistenceMessage = value
                ? "无法启用登录时启动。请先将 Ledge 放到“应用程序”文件夹。"
                : "无法关闭登录时启动，请在系统设置的“登录项”中修改。"
        }
    }

    func revealDataDirectory() {
        do {
            try FileManager.default.createDirectory(
                at: dataDirectory,
                withIntermediateDirectories: true,
                attributes: [.posixPermissions: 0o700]
            )
            NSWorkspace.shared.activateFileViewerSelecting([dataDirectory])
        } catch {
            persistenceMessage = "无法打开本地数据文件夹。"
        }
    }

    func flushDraft() {
        draftSaveTask?.cancel()
        draftSaveTask = nil
        persistDraftImmediately()
    }

    private func updateSettings(_ newValue: LedgeSettings) {
        settings = newValue
        do {
            try settingsStore.save(newValue)
            persistenceMessage = nil
        } catch {
            persistenceMessage = "设置暂时无法保存。"
        }
    }

    private func persistShelf() {
        do {
            try shelfStore.save(shelf)
            persistenceMessage = nil
        } catch {
            persistenceMessage = "文件架暂时无法保存。"
        }
    }

    private func recoverTransitOrphans() {
        guard let recoveredItems = try? transitStore.recoverItems(
            excluding: shelf.items
        ), !recoveredItems.isEmpty else { return }
        shelf = shelf.adding(recoveredItems)
        try? shelfStore.save(shelf)
    }

    private func persistDraft() {
        draftSaveTask?.cancel()
        draftSaveTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(180))
            guard !Task.isCancelled else { return }
            self?.draftSaveTask = nil
            self?.persistDraftImmediately()
        }
    }

    private func persistDraftImmediately() {
        do {
            try draftStore.save(draft)
            persistenceMessage = nil
        } catch {
            persistenceMessage = "便签暂时无法保存。"
        }
    }
}
