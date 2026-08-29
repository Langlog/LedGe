import CoreGraphics

public enum CompactPromptGeometry {
    public static let size = CGSize(width: 48, height: 26)
    public static let topCornerRadius: CGFloat = 10

    public static func contains(
        _ point: CGPoint,
        in bounds: CGRect
    ) -> Bool {
        guard bounds.contains(point) else { return false }

        let radius = min(
            topCornerRadius,
            min(bounds.width / 2, bounds.height)
        )
        guard point.y > bounds.maxY - radius else {
            return true
        }

        if point.x >= bounds.minX + radius,
           point.x <= bounds.maxX - radius {
            return true
        }

        let center = point.x < bounds.midX
            ? CGPoint(
                x: bounds.minX + radius,
                y: bounds.maxY - radius
            )
            : CGPoint(
                x: bounds.maxX - radius,
                y: bounds.maxY - radius
            )
        let deltaX = point.x - center.x
        let deltaY = point.y - center.y
        return deltaX * deltaX + deltaY * deltaY <= radius * radius
    }
}
