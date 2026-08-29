public enum LedgeSurface: Equatable, Sendable {
    case hidden
    case prompt
    case files
    case note
}

public enum LedgeActivationEvent: Equatable, Sendable {
    case pointerEntered
    case pointerLeft
    case promptClicked
    case externalFileDragEntered
    case filesSelected
    case noteSelected
    case dismissed
}

public enum LedgeActivationState {
    public static func transition(
        from surface: LedgeSurface,
        on event: LedgeActivationEvent
    ) -> LedgeSurface {
        switch event {
        case .pointerEntered:
            surface == .hidden ? .prompt : surface
        case .pointerLeft:
            surface == .prompt ? .hidden : surface
        case .promptClicked:
            surface == .prompt ? .note : surface
        case .externalFileDragEntered, .filesSelected:
            .files
        case .noteSelected:
            .note
        case .dismissed:
            .hidden
        }
    }
}
