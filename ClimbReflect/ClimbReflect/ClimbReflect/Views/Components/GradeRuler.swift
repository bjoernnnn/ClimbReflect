import SwiftUI

/// EF-1: horizontale Grad-Leiter zum Wischen statt Wheel-Picker. Rastet auf
/// den mittigen Grad ein (.viewAligned), Haptik pro Raste.
/// KR-6: ScrollViewReader steuert die Startposition explizit (scrollPosition
/// allein traf sie bei iOS 17 nicht verlässlich, wenn das Ziel-Item noch
/// nicht geladen war); isReady blendet Rückschreibungen aus, bis die erste
/// gezielte Positionierung abgeschlossen ist.
struct GradeRuler: View {
    let grades: [String]
    @Binding var selection: String

    private let itemWidth: CGFloat = 64
    @State private var isReady = false

    private var scrollBinding: Binding<String?> {
        Binding(
            get: { selection },
            set: { if isReady, let newValue = $0 { selection = newValue } }
        )
    }

    var body: some View {
        GeometryReader { geo in
            ScrollViewReader { proxy in
                VStack(spacing: 6) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 0) {
                            ForEach(grades, id: \.self) { grade in
                                Text(grade)
                                    .font(Theme.Typo.metric)
                                    .monospacedDigit()
                                    .foregroundStyle(grade == selection ? Theme.accent : Theme.textSecondary)
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
                    .scrollPosition(id: scrollBinding, anchor: .center)
                    .contentMargins(.horizontal, max(0, (geo.size.width - itemWidth) / 2), for: .scrollContent)
                    .frame(height: 44)

                    Capsule().fill(Theme.accent).frame(width: 16, height: 3)
                }
                .onAppear {
                    proxy.scrollTo(selection, anchor: .center)
                    Task {
                        await Task.yield()
                        isReady = true
                    }
                }
                .onChange(of: grades) { _, _ in
                    proxy.scrollTo(selection, anchor: .center)
                }
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
