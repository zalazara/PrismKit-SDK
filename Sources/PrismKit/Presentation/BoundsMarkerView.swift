import SwiftUI

/// A dashed rectangle marking a measured frame, colored by role.
struct BoundsMarkerView: View {
    let measurement: ResolvedMeasurement
    let isSelected: Bool

    var body: some View {
        let frame = measurement.frame
        Rectangle()
            .strokeBorder(
                isSelected ? OverlayStyle.selectionColor : OverlayStyle.color(for: measurement.role),
                style: StrokeStyle(lineWidth: isSelected ? 2 : 1, dash: [4, 3])
            )
            .frame(width: max(1, frame.width), height: max(1, frame.height))
            .position(x: frame.midX, y: frame.midY)
    }
}
