import CoreGraphics
import Testing
@testable import LedgeCore

@Suite("Compact prompt geometry")
struct CompactPromptGeometryTests {
    @Test("The compact prompt is a small bottom-edge tab")
    func promptSize() {
        #expect(CompactPromptGeometry.size == CGSize(width: 48, height: 26))
    }

    @Test("The bottom is square while only the top corners are rounded")
    func tabHitTesting() {
        let bounds = CGRect(origin: .zero, size: CompactPromptGeometry.size)

        #expect(
            CompactPromptGeometry.contains(
                CGPoint(x: bounds.midX, y: bounds.midY),
                in: bounds
            )
        )
        #expect(
            CompactPromptGeometry.contains(
                CGPoint(x: bounds.minX + 1, y: bounds.minY + 1),
                in: bounds
            )
        )
        #expect(
            !CompactPromptGeometry.contains(
                CGPoint(x: bounds.minX + 1, y: bounds.maxY - 1),
                in: bounds
            )
        )
    }
}

@Suite("Expanded panel geometry")
struct ExpandedPanelGeometryTests {
    @Test("Note and files share the files panel size")
    func sharedExpandedSize() {
        #expect(
            ExpandedPanelGeometry.size
                == CGSize(width: 720, height: 224)
        )
    }
}
