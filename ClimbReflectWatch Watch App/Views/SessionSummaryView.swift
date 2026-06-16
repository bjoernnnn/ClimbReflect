import SwiftUI

// W7.1: Post-Session Zusammenfassung inkl. Fragebogen-Antworten

struct SessionSummaryView: View {
    let dto: WatchSessionDTO?
    let onDone: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                // Header
                VStack(spacing: 4) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(WatchTheme.accent)
                    Text("Gute Session!")
                        .font(.headline)
                        .foregroundStyle(WatchTheme.textPrimary)
                }
                .padding(.top, 6)

                if let dto {
                    // Workout-Statistiken
                    VStack(spacing: 0) {
                        statRow("Dauer",    value: formatDuration(dto.durationSeconds), icon: "clock.fill")
                        Divider().background(WatchTheme.elevated)
                        statRow("Versuche", value: "\(dto.ascents.count)", icon: "figure.climbing")
                        Divider().background(WatchTheme.elevated)
                        statRow("Tops",
                                value: "\(dto.ascents.filter { $0.resultRaw == "top" }.count)",
                                icon: "checkmark.circle.fill")
                        if let hr = dto.avgHeartRate {
                            Divider().background(WatchTheme.elevated)
                            statRow("Ø HF", value: "\(Int(hr)) BPM", icon: "heart.fill")
                        }
                        if let kcal = dto.activeEnergyKcal {
                            Divider().background(WatchTheme.elevated)
                            statRow("Energie", value: "\(Int(kcal)) kcal", icon: "flame.fill")
                        }
                        if dto.altitudeTotalGain > 1 {
                            Divider().background(WatchTheme.elevated)
                            statRow("Höhenmeter",
                                    value: String(format: "%.0f m", dto.altitudeTotalGain),
                                    icon: "arrow.up.right")
                        }
                    }
                    .background(WatchTheme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                    // Fragebogen-Antworten (falls vorhanden)
                    if dto.rpe != nil || dto.focusRaw != nil || dto.energyRaw != nil {
                        VStack(spacing: 0) {
                            if let rpe = dto.rpe {
                                questRow("Anstrengung", value: rpeLabel(rpe),
                                         icon: "gauge.with.dots.needle.67percent",
                                         color: rpeColor(rpe))
                            }
                            if let focusRaw = dto.focusRaw,
                               let focus = WatchSessionFocus(rawValue: focusRaw) {
                                if dto.rpe != nil { Divider().background(WatchTheme.elevated) }
                                questRow("Fokus", value: focus.label,
                                         icon: focus.symbol, color: WatchTheme.accent)
                            }
                            if let energyRaw = dto.energyRaw,
                               let energy = WatchSessionEnergy(rawValue: energyRaw) {
                                if dto.rpe != nil || dto.focusRaw != nil {
                                    Divider().background(WatchTheme.elevated)
                                }
                                questRow("Zustand", value: energy.label,
                                         icon: energy.symbol, color: energy.color)
                            }
                        }
                        .background(WatchTheme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }

                    Text("An iPhone übertragen")
                        .font(.system(size: 10))
                        .foregroundStyle(WatchTheme.textTert)
                        .multilineTextAlignment(.center)
                }

                Button("Fertig", action: onDone)
                    .buttonStyle(.borderedProminent)
                    .tint(WatchTheme.accent)
                    .padding(.bottom, 4)
            }
            .padding(.horizontal, 10)
        }
        .background(WatchTheme.bg)
        .navigationBarBackButtonHidden(true)
    }

    // MARK: - Row-Helpers

    private func statRow(_ label: String, value: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundStyle(WatchTheme.textTert)
                .frame(width: 16)
            Text(label).foregroundStyle(WatchTheme.textSecond).font(.footnote)
            Spacer()
            Text(value).foregroundStyle(WatchTheme.textPrimary).font(.footnote.weight(.semibold))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }

    private func questRow(_ label: String, value: String, icon: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundStyle(color)
                .frame(width: 16)
            Text(label).foregroundStyle(WatchTheme.textSecond).font(.footnote)
            Spacer()
            Text(value).foregroundStyle(WatchTheme.textPrimary).font(.footnote.weight(.semibold))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }

    // MARK: - Hilfsmethoden

    private func formatDuration(_ seconds: Double) -> String {
        let s = Int(seconds)
        let h = s / 3600, m = (s % 3600) / 60
        return h > 0 ? "\(h)h \(m)min" : "\(m) min"
    }

    private func rpeLabel(_ val: Int) -> String {
        switch val {
        case 1...3: return "Locker (\(val))"
        case 4...6: return "Mittel (\(val))"
        case 7...8: return "Hart (\(val))"
        default:    return "Maximal (\(val))"
        }
    }

    private func rpeColor(_ val: Int) -> Color {
        switch val {
        case 1...4: return WatchTheme.accent
        case 5...7: return WatchTheme.gold
        default:    return WatchTheme.danger
        }
    }
}
