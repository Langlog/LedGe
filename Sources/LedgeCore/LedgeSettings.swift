import Foundation

public enum DisplayMode: String, Codable, CaseIterable, Sendable {
    case followsPointer
    case mainDisplay
}

public enum WakeSensitivity: String, Codable, CaseIterable, Sendable {
    case discreet
    case balanced
    case eager
}

public struct LedgeSettings: Codable, Equatable, Sendable {
    public let displayMode: DisplayMode
    public let removeAfterSuccessfulDrag: Bool
    public let wakeSensitivity: WakeSensitivity
    public let launchAtLogin: Bool

    public init(
        displayMode: DisplayMode,
        removeAfterSuccessfulDrag: Bool,
        wakeSensitivity: WakeSensitivity,
        launchAtLogin: Bool
    ) {
        self.displayMode = displayMode
        self.removeAfterSuccessfulDrag = removeAfterSuccessfulDrag
        self.wakeSensitivity = wakeSensitivity
        self.launchAtLogin = launchAtLogin
    }

    public static let `default` = LedgeSettings(
        displayMode: .followsPointer,
        removeAfterSuccessfulDrag: true,
        wakeSensitivity: .balanced,
        launchAtLogin: false
    )

    public func with(
        displayMode: DisplayMode? = nil,
        removeAfterSuccessfulDrag: Bool? = nil,
        wakeSensitivity: WakeSensitivity? = nil,
        launchAtLogin: Bool? = nil
    ) -> LedgeSettings {
        LedgeSettings(
            displayMode: displayMode ?? self.displayMode,
            removeAfterSuccessfulDrag:
                removeAfterSuccessfulDrag ?? self.removeAfterSuccessfulDrag,
            wakeSensitivity: wakeSensitivity ?? self.wakeSensitivity,
            launchAtLogin: launchAtLogin ?? self.launchAtLogin
        )
    }
}
