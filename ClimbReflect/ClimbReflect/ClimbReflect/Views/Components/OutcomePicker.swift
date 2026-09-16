import SwiftUI

/// EF-1: große Ergebnis-Buttons statt Segmented-Picker + separatem Stil-Picker.
struct OutcomePicker: View {
    let options: [AscentOutcome]
    @Binding var selection: AscentOutcome?

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: options.count), spacing: 8) {
            ForEach(options) { option in
                let isSelected = selection == option
                let isCelebratory = option.style == .flash || option.style == .onsight

                Button {
                    selection = option
                } label: {
                    VStack(spacing: 6) {
                        Image(systemName: option.symbol)
                            .font(.title3)
                        Text(option.label)
                            .font(.subheadline.weight(.semibold))
                    }
                    .frame(maxWidth: .infinity, minHeight: 72)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous)
                            .fill(isSelected ? (isCelebratory ? Theme.gold : Theme.accent) : Theme.surfaceRaised)
                    )
                    .foregroundStyle(isSelected ? Theme.bg : Theme.textSecondary)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: selection)
    }
}

#Preview("Boulder") {
    struct Demo: View {
        @State var outcome: AscentOutcome? = AscentOutcome.quick(for: .boulder)[1]
        var body: some View {
            OutcomePicker(options: AscentOutcome.quick(for: .boulder), selection: $outcome)
                .padding()
        }
    }
    return Demo()
        .background(Theme.bg)
}

#Preview("Seil") {
    struct Demo: View {
        @State var outcome: AscentOutcome? = nil
        var body: some View {
            OutcomePicker(options: AscentOutcome.quick(for: .rope), selection: $outcome)
                .padding()
        }
    }
    return Demo()
        .background(Theme.bg)
}
