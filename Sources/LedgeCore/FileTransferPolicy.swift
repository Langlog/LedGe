public enum FileTransferOperation: Equatable, Sendable {
    case none
    case copy
    case move
}

public enum FileImportPolicy {
    public static let advertisedOperation = FileTransferOperation.move
}

public enum FileExportPolicy {
    public static let advertisedOperation = FileTransferOperation.copy
}
