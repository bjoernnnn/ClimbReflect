import SwiftUI

// 3 Fragen nach der Session für spätere Trainingsanalyse

struct SessionEndQuestionnaireView: View {
    let dto: WatchSessionDTO
    let skipFocus: Bool      // C5: im Training ist Fokus bereits via Zielkapazität gesetzt
    let onComplete: (WatchSessionDTO) -> Void

    init(dto: WatchSessionDTO, skipFocus: Bool = false, onComplete: @escaping (WatchSessionDTO) -> Void) {
        self.dto = dto
        self.skipFocus = skipFocus
        self.onComplete = onComplete
    }

    @State private var step = 0
    @State private var rpe: Int = 6
    @State private var rpeValue: Double = 6
    @State private var focus: WatchSessionFocus? = nil
    @State private var energy: WatchSessionEnergy? = nil

    private var stepCount: Int { skipFocus ? 2 : 3 }

    var body: some View {
        ZStack {
            WatchTheme.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                progressDots
                    .padding(.top, 4)
                    .padding(.bottom, 8)

                Group {
                    if step == 0 { rpeStep }
                    else if step == 1 && !skipFocus { focusStep }
                    else { energyStep }
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
                .id(step)
            }
        }
        .navigationBarBackButtonHidden(true)
    }

    // MARK: - Schritt 1: RPE

    private var rpeStep: some View {
        VStack(spacing: 10) {
            questionHeader(icon: "gauge.with.dots.needle.67percent",
                           title: "Anstrengung",
                           subtitle: "Wie hart war die Session?")

            // Große Zahl – primäre Eingabe per Digital Crown
            Text("\(Int(rpeValue))")
                .font(.system(size: 44, weight: .bold, design: .rounded))
                .foregroundStyle(rpeColor(Int(rpeValue)))
                .focusable(true)
                .digitalCrownRotation($rpeValue, from: 1, through: 10, by: 1,
                                      sensitivity: .low, isContinuous: false,
                                      isHapticFeedbackEnabled: true)
                .onChange(of: rpeValue) { _, v in rpe = Int(v) }

            // Visueller Indikator (zeigt aktuellen Wert, nicht primäre Eingabe)
            HStack(spacing: 0) {
                ForEach(1...10, id: \.self) { val in
                    RoundedRectangle(cornerRadius: 3)
                        .fill(val <= Int(rpeValue) ? rpeColor(val) : WatchTheme.surface)
                        .frame(maxWidth: .infinity, minHeight: 6, maxHeight: 6)
                }
            }
            .animation(.easeInOut(duration: 0.1), value: Int(rpeValue))

            HStack {
                Text("Locker").font(.system(size: 9)).foregroundStyle(WatchTheme.textTert)
                Spacer()
                Text("Maximal").font(.system(size: 9)).foregroundStyle(WatchTheme.textTert)
            }

            nextButton(label: "Weiter") { withAnimation { step = skipFocus ? 2 : 1 } }
        }
        .padding(.horizontal, 8)
    }

    // MARK: - Schritt 2: Fokus

    private var focusStep: some View {
        VStack(spacing: 8) {
            questionHeader(icon: "scope",
                           title: "Schwerpunkt",
                           subtitle: "Was stand heute im Fokus?")

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                ForEach(WatchSessionFocus.allCases) { f in
                    Button { withAnimation { focus = focus == f ? nil : f } } label: {
                        HStack(spacing: 5) {
                            Image(systemName: f.symbol)
                                .font(.system(size: 11))
                                .foregroundStyle(focus == f ? WatchTheme.bg : WatchTheme.accent)
                            Text(f.label)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(focus == f ? WatchTheme.bg : WatchTheme.textPrimary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(focus == f ? WatchTheme.accent : WatchTheme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 9))
                    }
                    .buttonStyle(.plain)
                }
            }

            nextButton(label: "Weiter") { withAnimation { step = 2 } }
        }
        .padding(.horizontal, 8)
    }

    // MARK: - Schritt 3: Energie

    private var energyStep: some View {
        VStack(spacing: 8) {
            questionHeader(icon: "leaf.fill",
                           title: "Zustand",
                           subtitle: "Wie warst du heute drauf?")

            VStack(spacing: 6) {
                ForEach(WatchSessionEnergy.allCases) { e in
                    Button { withAnimation { energy = e } } label: {
                        HStack(spacing: 8) {
                            Image(systemName: e.symbol)
                                .font(.system(size: 14))
                                .foregroundStyle(energy == e ? WatchTheme.bg : e.color)
                                .frame(width: 20)
                            Text(e.label)
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(energy == e ? WatchTheme.bg : WatchTheme.textPrimary)
                            Spacer()
                            if energy == e {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(WatchTheme.bg)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(energy == e ? e.color : WatchTheme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
            }

            nextButton(label: "Fertig") {
                onComplete(dto.withQuestionnaire(rpe: rpe, focus: focus, energy: energy))
            }
        }
        .padding(.horizontal, 8)
    }

    // MARK: - Hilfsmethoden

    // Normalisiert step → dot-Index (bei skipFocus: step 0→0, step 2→1)
    private var dotIndex: Int {
        skipFocus && step == 2 ? 1 : step
    }

    private var progressDots: some View {
        HStack(spacing: 6) {
            ForEach(0..<stepCount, id: \.self) { i in
                Circle()
                    .fill(i == dotIndex ? WatchTheme.accent : WatchTheme.surface)
                    .frame(width: i == dotIndex ? 6 : 5, height: i == dotIndex ? 6 : 5)
                    .animation(.easeInOut, value: step)
            }
        }
    }

    private func questionHeader(icon: String, title: String, subtitle: String) -> some View {
        VStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(WatchTheme.accent)
            Text(title)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(WatchTheme.textPrimary)
            Text(subtitle)
                .font(.system(size: 10))
                .foregroundStyle(WatchTheme.textSecond)
        }
    }

    private func nextButton(label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(WatchTheme.bg)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background(WatchTheme.accent)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }

    private func rpeColor(_ val: Int) -> Color {
        switch val {
        case 1...4: return WatchTheme.accent
        case 5...7: return WatchTheme.gold
        default:    return WatchTheme.danger
        }
    }
}
