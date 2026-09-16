import SwiftUI

/// EF-4: Kachel-Raster statt fünf Listenzeilen – spart eine halbe Bildschirmhöhe
/// beim Anlegen einer Session.
struct SessionTypeGrid: View {
    @Binding var selection: SessionType

    private let types = SessionType.allCases.filter { $0 != .unknown }
    private let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(types) { type in
                let isSelected = type == selection
                Button {
                    selection = type
                } label: {
                    VStack(spacing: 6) {
                        Image(systemName: type.symbol)
                            .font(.title3)
                        Text(type.label)
                            .font(.caption.weight(.semibold))
                    }
                    .frame(maxWidth: .infinity, minHeight: 64)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous)
                            .fill(isSelected ? Theme.accent : Theme.surfaceRaised)
                    )
                    .foregroundStyle(isSelected ? Theme.bg : Theme.textSecondary)
                }
                .buttonStyle(.plain)
            }
        }
        .sensoryFeedback(.selection, trigger: selection)
    }
}

#Preview {
    struct Demo: View {
        @State var type = SessionType.boulder
        var body: some View {
            SessionTypeGrid(selection: $type)
                .padding()
        }
    }
    return Demo()
        .background(Theme.bg)
}
