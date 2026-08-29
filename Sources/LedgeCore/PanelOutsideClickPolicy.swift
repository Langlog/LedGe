public enum PanelOutsideClickPolicy {
    public static func shouldDismiss(
        surface: LedgeSurface,
        clickIsInsidePanel: Bool,
        externalFileDragIsActive: Bool
    ) -> Bool {
        guard surface == .note || surface == .files else { return false }
        return !clickIsInsidePanel && !externalFileDragIsActive
    }
}
