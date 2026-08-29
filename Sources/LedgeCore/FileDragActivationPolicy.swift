import Foundation

public enum FileDragActivationPolicy {
    public static func shouldRevealShelf(
        pasteboardContainsFileURLs: Bool,
        pasteboardChangeCount: Int,
        baselineChangeCount: Int,
        activeFileDragChangeCount: Int?,
        activeFileDragLastSeenAt: TimeInterval?,
        currentTime: TimeInterval,
        maximumIdleDuration: TimeInterval = 0.45
    ) -> Bool {
        guard pasteboardContainsFileURLs else { return false }
        if pasteboardChangeCount != baselineChangeCount {
            return true
        }
        guard activeFileDragChangeCount == pasteboardChangeCount,
              let activeFileDragLastSeenAt
        else { return false }
        let idleDuration = currentTime - activeFileDragLastSeenAt
        return idleDuration >= 0 && idleDuration <= maximumIdleDuration
    }
}
