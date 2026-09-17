import SwiftUI

/// PG-2/E21: Druckzustand für tappbare Karten und Zeilen – minimales Einsinken
/// statt reiner .plain-Stille. Bei Reduce Motion nur Abdunklung.
struct CardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        PressedLabel(configuration: configuration)
    }

    private struct PressedLabel: View {
        let configuration: Configuration
        @Environment(\.accessibilityReduceMotion) private var reduceMotion

        var body: some View {
            configuration.label
                .contentShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
                .scaleEffect(configuration.isPressed && !reduceMotion ? 0.98 : 1)
                .opacity(configuration.isPressed ? 0.85 : 1)
                .animation(.snappy(duration: 0.18), value: configuration.isPressed)
        }
    }
}

extension ButtonStyle where Self == CardButtonStyle {
    static var card: CardButtonStyle { .init() }
}
