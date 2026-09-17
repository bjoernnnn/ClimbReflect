import SwiftUI

/// PG-5: aus SessionDetailView ausgelagert (reiner Refactor, keine
/// Verhaltensänderung) – Kurz-Check (EF-5) inkl. RPE, Limiter, Watch-Chips.
struct SessionQuickCheckCard: View {
    @Bindable var session: ClimbSession

    private let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Kurz-Check")
                .font(.headline)
                .foregroundStyle(Theme.textPrimary)

            if session.sessionFocusLabel != nil || session.energyLabel != nil {
                watchQuestionnaireChips
                Divider().overlay(Theme.separator)
            }

            rpePicker

            Divider().overlay(Theme.separator)

            limiterPicker
        }
        .card()
    }

    // MARK: - RPE

    private var rpePicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Anstrengung (RPE)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.textSecondary)
                Spacer()
                if let rpe = session.perceivedEffort {
                    Text("\(rpe)/10")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(rpeColor(rpe))
                }
            }

            HStack(spacing: 5) {
                ForEach(1...10, id: \.self) { value in
                    let selected = session.perceivedEffort == value
                    Button {
                        session.perceivedEffort = value
                        session.updateReflectionCompleted()
                        session.updatedAt = .now
                    } label: {
                        Text("\(value)")
                            .font(.caption.weight(.bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 9)
                            .background(
                                RoundedRectangle.theme(Theme.Radius.small)
                                    .fill(selected ? rpeColor(value) : Theme.surfaceRaised)
                            )
                            .foregroundStyle(selected ? Theme.bg : Theme.textSecondary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .sensoryFeedback(.selection, trigger: session.perceivedEffort)
    }

    // E18: eine Accent-Intensitätsskala statt Gold/Rot-Stufen – eine harte Session ist kein Fehler.
    private func rpeColor(_ rpe: Int) -> Color {
        Theme.accent.opacity(0.35 + Double(rpe) * 0.065)
    }

    // MARK: - Limiter

    // RP-2: Auf der Watch erfasster Schwerpunkt + Zustand (read-only Chips)
    private var watchQuestionnaireChips: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Auf der Uhr erfasst")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.textSecondary)

            HStack(spacing: 8) {
                if let focus = session.sessionFocusLabel {
                    readOnlyChip("Schwerpunkt", value: focus, icon: "scope")
                }
                if let energy = session.energyLabel {
                    readOnlyChip("Zustand", value: energy, icon: "bolt.heart.fill")
                }
            }
        }
    }

    private func readOnlyChip(_ title: String, value: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(Theme.accent2)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(Theme.textSecondary)
                Text(value)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle.theme(Theme.Radius.small).fill(Theme.surfaceRaised)
        )
    }

    private var limiterPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            // FB-6: bei Training ist es die Zielkapazität, nicht der limitierende Faktor
            Text(session.isClimbing ? "Limitierende Faktoren" : "Trainiert")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.textSecondary)

            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(Limiter.allCases) { limiter in
                    let active = session.limiters.contains(limiter)
                    Button { toggleLimiter(limiter) } label: {
                        Text(limiter.label)
                            .font(.caption.weight(.semibold))
                            .lineLimit(1)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle.theme(Theme.Radius.small)
                                    .fill(active ? Theme.accent2.opacity(0.2) : Theme.surfaceRaised)
                                    .overlay(
                                        RoundedRectangle.theme(Theme.Radius.small)
                                            .stroke(active ? Theme.accent2 : Color.clear, lineWidth: 1)
                                    )
                            )
                            .foregroundStyle(active ? Theme.accent2 : Theme.textSecondary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .sensoryFeedback(.selection, trigger: session.limiterRaw)
    }

    private func toggleLimiter(_ limiter: Limiter) {
        var current = session.limiters
        if let idx = current.firstIndex(of: limiter) {
            current.remove(at: idx)
        } else {
            current.append(limiter)
        }
        session.limiterRaw = current.map(\.rawValue)
        session.updateReflectionCompleted()
        session.updatedAt = .now
    }
}
