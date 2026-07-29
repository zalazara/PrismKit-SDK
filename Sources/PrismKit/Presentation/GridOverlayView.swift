import SwiftUI

/// A subtle alignment grid drawn at the configured grid size.
struct GridOverlayView: View {
    let gridSize: CGFloat

    var body: some View {
        Canvas { context, size in
            guard gridSize >= 1 else { return }
            var path = Path()
            var x: CGFloat = 0
            while x <= size.width {
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
                x += gridSize
            }
            var y: CGFloat = 0
            while y <= size.height {
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                y += gridSize
            }
            context.stroke(path, with: .color(OverlayStyle.gridColor), lineWidth: 0.5)
        }
    }
}

/// A dashed boundary marking the safe area within the scope.
struct SafeAreaOverlayView: View {
    let size: CGSize
    let insets: EdgeInsets

    var body: some View {
        let rect = CGRect(
            x: insets.leading,
            y: insets.top,
            width: max(0, size.width - insets.leading - insets.trailing),
            height: max(0, size.height - insets.top - insets.bottom)
        )
        Path(rect)
            .stroke(
                OverlayStyle.safeAreaColor,
                style: StrokeStyle(lineWidth: 1, dash: [6, 4])
            )
    }
}
