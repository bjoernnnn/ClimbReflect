import SwiftUI

// C5: Zielkapazität vor dem Training wählen

struct TrainingSetupView: View {
    let onStart: (WatchTrainingTarget) -> Void

    @State private var selected: WatchTrainingTarget = .fingerStrength

    var body: some View {
        VStack(spacing: 0) {
            Text("Zielkapazität")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(WatchTheme.textPrimary)
                .padding(.top, 12)
                .padding(.bottom, 8)

            ScrollView {
                VStack(spacing: 6) {
                    ForEach(WatchTrainingTarget.allCases) { target in
                        Button { selected = target } label: {
                            HStack(spacing: 10) {
                                Image(systemName: target.symbol)
                                    .font(.system(size: 14))
                                    .foregroundStyle(selected == target ? WatchTheme.bg : WatchTheme.accent)
                                    .frame(width: 20)
                                Text(target.label)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(selected == target ? WatchTheme.bg : WatchTheme.textPrimary)
                                Spacer()
                                if selected == target {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundStyle(WatchTheme.bg)
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 9)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(selected == target ? WatchTheme.accent : WatchTheme.surface)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 8)
            }

            Button { onStart(selected) } label: {
                Text("Los gehts")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(WatchTheme.bg)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(WatchTheme.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 8)
            .padding(.bottom, 8)
        }
        .background(WatchTheme.bg)
    }
}
