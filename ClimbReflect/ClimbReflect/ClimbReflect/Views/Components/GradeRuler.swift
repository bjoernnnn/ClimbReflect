import SwiftUI

/// EF-1: horizontale Grad-Leiter zum Wischen statt Wheel-Picker. Rastet auf
/// den mittigen Grad ein (.viewAligned), Haptik pro Raste.
struct GradeRuler: View {
    let grades: [String]
    @Binding var selection: String

    private let itemWidth: CGFloat = 64

    private var scrollBinding: Binding<String?> {
        Binding(get: { selection }, set: { if let newValue = $0 { selection = newValue } })
    }

    var body: some View {
        GeometryReader { geo in
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 0) {
                    ForEach(grades, id: \.self) { grade in
                        Text(grade)
                            .font(Theme.Typo.metric)
                            .monospacedDigit()
                            .foregroundStyle(grade == selection ? Theme.textPrimary : Theme.textTertiary)
                            .frame(width: itemWidth)
                            .id(grade)
                            .scrollTransition(.interactive) { content, phase in
                                content
                                    .opacity(phase.isIdentity ? 1 : 0.35)
                                    .scaleEffect(phase.isIdentity ? 1 : 0.8)
                            }
                            .onTapGesture {
                                withAnimation(.snappy) { selection = grade }
                            }
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: scrollBinding)
            .contentMargins(.horizontal, max(0, (geo.size.width - itemWidth) / 2), for: .scrollContent)
            .overlay {
                Capsule()
                    .fill(Theme.accent)
                    .frame(width: 2, height: 18)
                    .allowsHitTesting(false)
            }
        }
        .frame(height: 64)
        .sensoryFeedback(.selection, trigger: selection)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Grad")
        .accessibilityValue(selection)
        .accessibilityAdjustableAction { direction in
            guard let idx = grades.firstIndex(of: selection) else { return }
            switch direction {
            case .increment: if idx + 1 < grades.count { selection = grades[idx + 1] }
            case .decrement: if idx - 1 >= 0 { selection = grades[idx - 1] }
            @unknown default: break
            }
        }
    }
}

#Preview("Boulder") {
    struct Demo: View {
        @State var grade = "6B"
        var body: some View {
            GradeRuler(grades: GradeSystem.fontainebleau.grades, selection: $grade)
        }
    }
    return Demo()
        .background(Theme.bg)
}

#Preview("Seil") {
    struct Demo: View {
        @State var grade = "6a"
        var body: some View {
            GradeRuler(grades: GradeSystem.french.grades, selection: $grade)
        }
    }
    return Demo()
        .background(Theme.bg)
}
