import CoreGraphics

public enum EdgeActivationGeometry {
    public static func pointerZone(
        in screen: CGRect,
        sensitivity: WakeSensitivity
    ) -> CGRect {
        let dimensions: (width: CGFloat, height: CGFloat) = switch sensitivity {
        case .discreet:
            (180, 3)
        case .balanced:
            (240, 5)
        case .eager:
            (320, 7)
        }
        let width = min(dimensions.width, screen.width)
        return CGRect(
            x: screen.midX - width / 2,
            y: screen.minY,
            width: width,
            height: dimensions.height
        )
    }

    public static func dragZone(in screen: CGRect) -> CGRect {
        let width = min(max(screen.width * 0.72, 720), screen.width)
        return CGRect(
            x: screen.midX - width / 2,
            y: screen.minY,
            width: width,
            height: 96
        )
    }
}
