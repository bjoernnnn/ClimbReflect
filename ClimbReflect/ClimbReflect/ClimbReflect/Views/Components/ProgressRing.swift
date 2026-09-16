import SwiftUI

/// FS-2: Fortschrittsring nur für echte Zählungen (n/Ziel) – kein Ring, wo es
/// keine echte Quote gibt (S32, E13).
struct ProgressRing: View {
    let current: Int
    let target: Int
    var size: CGFloat = 28

    private var fraction: Double {
        guard target > 0 else { return 0 }
        return min(1, max(0, Double(current) / Double(target)))
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Theme.surfaceRaised, lineWidth: size * 0.14)
            Circle()
                .trim(from: 0, to: fraction)
                .stroke(Theme.accent, style: StrokeStyle(lineWidth: size * 0.14, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .frame(width: size, height: size)
        .animation(.snappy, value: current)
        .accessibilityValue("\(current) von \(target)")
    }
}

#Preview {
    HStack(spacing: 20) {
        ProgressRing(current: 3, target: 5)
        ProgressRing(current: 5, target: 5)
        ProgressRing(current: 1, target: 5, size: 40)
    }
    .padding()
    .background(Theme.bg)
}
