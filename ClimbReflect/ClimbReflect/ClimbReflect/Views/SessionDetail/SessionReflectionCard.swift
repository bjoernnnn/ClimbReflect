import SwiftUI

/// PG-5: aus SessionDetailView ausgelagert (reiner Refactor, keine
/// Verhaltensänderung) – Reflexion (EF-5) inkl. Technik-Fokus, Fokus-Rating,
/// Textfelder.
struct SessionReflectionCard: View {
    @Bindable var session: ClimbSession
    @Binding var isExpanded: Bool
    var isTextFieldFocused: FocusState<Bool>.Binding

    /// Bereits erfasste Inhalte → Karte startet aufgeklappt statt eingeklappt.
    private var hasReflectionContent: Bool {
        (session.isClimbing && (!session.techniqueFocusesRaw.isEmpty || session.focusRating != nil))
            || !(session.learned ?? "").isEmpty
            || !(session.hardestPart ?? "").isEmpty
            || !(session.improveNext ?? "").isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("Reflexion")
                    .font(.headline)
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                Image(systemName: hasReflectionContent ? "checkmark.seal.fill" : "checkmark.seal")
                    .foregroundStyle(hasReflectionContent ? Theme.gold : Theme.textTertiary)
                    .symbolEffect(.bounce, value: hasReflectionContent)
            }

            if isExpanded {
                if session.isClimbing {
                    techniqueFocusPicker
                    Divider().overlay(Theme.separator)
                    focusRatingPicker
                    Divider().overlay(Theme.separator)
                }

                reflectionField(
                    "Was habe ich gelernt?",
                    icon: "lightbulb.fill",
                    placeholder: session.isClimbing
                        ? "z. B. Hüfteinsatz beim Überhang verbessert…"
                        : "z. B. Max-Hangs erstmals an 10 mm gehalten…",
                    text: Binding(
                        get: { session.learned ?? "" },
                        set: { session.learned = $0.isEmpty ? nil : $0 }
                    )
                )

                reflectionField(
                    "Was war am schwersten?",
                    icon: "exclamationmark.triangle.fill",
                    placeholder: session.isClimbing
                        ? "z. B. Fingerkraft am Ende der Session…"
                        : "z. B. Letzter Satz Repeaters…",
                    text: Binding(
                        get: { session.hardestPart ?? "" },
                        set: { session.hardestPart = $0.isEmpty ? nil : $0 }
                    )
                )

                reflectionField(
                    "Was will ich verbessern?",
                    icon: "arrow.up.circle.fill",
                    placeholder: session.isClimbing
                        ? "z. B. Mehr Fokus auf Füße und Balance…"
                        : "z. B. Nächstes Mal 2 kg mehr Zusatzlast…",
                    text: Binding(
                        get: { session.improveNext ?? "" },
                        set: { session.improveNext = $0.isEmpty ? nil : $0 }
                    )
                )
            } else {
                Text("Was hast du gelernt, was war schwer, was nimmst du mit?")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
                Button("Reflexion schreiben") {
                    withAnimation(.snappy) { isExpanded = true }
                }
                .buttonStyle(.bordered)
            }
        }
        .card()
        .onAppear {
            if hasReflectionContent { isExpanded = true }
        }
    }

    // MARK: - Technik-Fokus (P3.6)

    private var techniqueFocusPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Technik-Fokus")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.textSecondary)
                Spacer()
                if !session.techniqueFocuses.isEmpty {
                    Button("Löschen") {
                        session.techniqueFocusesRaw = []
                        session.updateReflectionCompleted()
                        session.updatedAt = .now
                    }
                    .font(.caption)
                    .foregroundStyle(Theme.textTertiary)
                }
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 92), spacing: 8)], spacing: 8) {
                ForEach(TechniqueFocus.allCases) { focus in
                    let selected = session.techniqueFocuses.contains(focus)
                    Button {
                        var current = session.techniqueFocuses
                        if let idx = current.firstIndex(of: focus) {
                            current.remove(at: idx)
                        } else {
                            current.append(focus)
                        }
                        session.techniqueFocusesRaw = current.map(\.rawValue)
                        session.updateReflectionCompleted()
                        session.updatedAt = .now
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: focus.symbol)
                            Text(focus.label)
                        }
                        .font(.caption.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .background(Capsule().fill(selected ? Theme.accent2 : Theme.surfaceRaised))
                        .foregroundStyle(selected ? Theme.bg : Theme.textSecondary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .sensoryFeedback(.selection, trigger: session.techniqueFocusesRaw)
    }

    // MARK: - Fokus-Bewertung (A7)

    private var focusRatingPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Fokus-Bewertung")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.textSecondary)
                Spacer()
                if session.focusRating != nil {
                    Button("Löschen") {
                        session.focusRating = nil
                        session.updateReflectionCompleted()
                        session.updatedAt = .now
                    }
                    .font(.caption)
                    .foregroundStyle(Theme.textTertiary)
                }
            }

            HStack(spacing: 8) {
                ForEach(1...5, id: \.self) { star in
                    let active = (session.focusRating ?? 0) >= star
                    Button {
                        session.focusRating = session.focusRating == star ? nil : star
                        session.updateReflectionCompleted()
                        session.updatedAt = .now
                    } label: {
                        Image(systemName: active ? "star.fill" : "star")
                            .font(.title3)
                            .foregroundStyle(active ? Theme.accent : Theme.surfaceRaised)
                    }
                    .buttonStyle(.plain)
                    .animation(.easeInOut(duration: 0.1), value: session.focusRating)
                }
                Spacer()
                if let r = session.focusRating {
                    Text(focusRatingLabel(r))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.textSecondary)
                }
            }
        }
        .sensoryFeedback(.selection, trigger: session.focusRating)
    }

    private func focusRatingLabel(_ r: Int) -> String {
        switch r {
        case 1: return "Abgelenkt"
        case 2: return "Wenig Fokus"
        case 3: return "Okay"
        case 4: return "Fokussiert"
        default: return "Im Flow"
        }
    }

    // MARK: - Textfelder

    private func reflectionField(_ title: String, icon: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.textSecondary)

            TextField(placeholder, text: text, axis: .vertical)
                .font(.subheadline)
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(2...8)
                .focused(isTextFieldFocused)
                .inset()
                .onChange(of: text.wrappedValue) { _, _ in
                    session.updateReflectionCompleted()
                    session.updatedAt = .now
                }
        }
    }
}

// MARK: - EF-5: Reflexions-Vollständigkeit (aus vielen Session-Feldern abgeleitet)

extension ClimbSession {
    func updateReflectionCompleted() {
        let wasCompleted = reflectionCompleted
        reflectionCompleted =
            perceivedEffort != nil ||
            !limiterRaw.isEmpty ||
            // FB-6: Technik/Fokus zählen nur bei Klettersessions (Picker bei Training aus)
            (isClimbing && !techniqueFocusesRaw.isEmpty) ||
            (isClimbing && focusRating != nil) ||
            learned != nil ||
            hardestPart != nil ||
            improveNext != nil
        if !wasCompleted && reflectionCompleted {
            NotificationService.shared.cancelReminder(for: id)
        }
    }
}
