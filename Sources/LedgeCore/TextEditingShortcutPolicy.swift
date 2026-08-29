public enum TextEditingShortcutAction: Equatable, Sendable {
    case selectAll
    case copy
    case paste
}

public enum TextEditingShortcutPolicy {
    public static func action(
        character: String,
        command: Bool,
        control: Bool
    ) -> TextEditingShortcutAction? {
        switch character.lowercased() {
        case "a" where command || control:
            .selectAll
        case "c" where command:
            .copy
        case "v" where command:
            .paste
        default:
            nil
        }
    }
}
