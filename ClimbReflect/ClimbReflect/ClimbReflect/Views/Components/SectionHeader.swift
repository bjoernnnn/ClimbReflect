import SwiftUI

/// PG-3: eine Abschnittsüberschrift für Seiten-Abschnitte außerhalb von Karten
/// (Heute, Fortschritt, Recap, Projekte). Titel innerhalb von Karten bleiben
/// Theme.Typo.cardTitle.
struct SectionHeader<Accessory: View>: View {
    let title: String
    @ViewBuilder var accessory: Accessory

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).font(Theme.Typo.section).foregroundStyle(Theme.textPrimary)
            Spacer()
            accessory
        }
        .accessibilityAddTraits(.isHeader)
    }
}

extension SectionHeader where Accessory == EmptyView {
    init(_ title: String) { self.init(title: title) { EmptyView() } }
}

#Preview {
    VStack(alignment: .leading, spacing: 20) {
        SectionHeader("Letzte Sessions")
        SectionHeader(title: "Angepinnt") {
            Text("3").font(.caption.weight(.semibold)).foregroundStyle(Theme.textSecondary)
        }
    }
    .padding()
    .background(Theme.bg)
}
