public enum PanelShortcutPolicy {
    public static let escapeKeyCode: UInt16 = 53

    public static func shouldDismiss(keyCode: UInt16) -> Bool {
        keyCode == escapeKeyCode
    }
}
