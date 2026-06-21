import SwiftUI

// Detail-Ansicht eines einzelnen Versuchs — zeigt alle gespeicherten Infos + Löschen

struct AscentDetailView: View {
    let attempt: WatchAttempt
    let onDelete: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var showDeleteConfirm = false

    private static let timeFmt: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "de_DE")
        f.dateFormat = "HH:mm 'Uhr'"
        return f
    }()

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                // Header: Grad + Ergebnis-Farbe
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill((attempt.result?.color ?? WatchTheme.textTert).opacity(0.15))
                    VStack(spacing: 4) {
                        HStack(spacing: 6) {
                            Image(systemName: attempt.result?.symbol ?? "circle")
                                .foregroundStyle(attempt.result?.color ?? WatchTheme.textTert)
                                .font(.system(size: 18))
                            Text(attempt.grade ?? "–")
                                .font(.system(size: 22, weight: .bold, design: .rounded))
                                .foregroundStyle(WatchTheme.textPrimary)
                        }
                        if let style = attempt.style {
                            Text(style.label)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(WatchTheme.gold)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(WatchTheme.gold.opacity(0.15))
                                .clipShape(Capsule())
                        }
                    }
                    .padding(.vertical, 12)
                }

                // Details
                VStack(spacing: 0) {
                    detailRow(icon: "clock",
                              label: "Uhrzeit",
                              value: Self.timeFmt.string(from: attempt.date))

                    if let hr = attempt.heartRateAtBanking, hr > 0 {
                        Divider().background(WatchTheme.elevated)
                        detailRow(icon: "heart.fill",
                                  label: "Herzfrequenz",
                                  value: "\(Int(hr)) BPM",
                                  valueColor: WatchTheme.danger)
                    }

                    if let dur = attempt.durationSeconds, dur > 0 {
                        Divider().background(WatchTheme.elevated)
                        detailRow(icon: "timer",
                                  label: "Dauer",
                                  value: formatDuration(dur))
                    }

                    if attempt.altitudeGain > 0.5 {
                        Divider().background(WatchTheme.elevated)
                        detailRow(icon: "arrow.up.right",
                                  label: "Höhenmeter",
                                  value: String(format: "%.1f m", attempt.altitudeGain))
                    }

                    Divider().background(WatchTheme.elevated)
                    detailRow(icon: "scalemass",
                              label: "Skala",
                              value: attempt.gradeSystem.label)
                }
                .background(WatchTheme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 10))

                // Löschen
                Button(role: .destructive) {
                    showDeleteConfirm = true
                } label: {
                    Label("Löschen", systemImage: "trash")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(WatchTheme.danger)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(WatchTheme.danger.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
                .confirmationDialog("Versuch löschen?", isPresented: $showDeleteConfirm) {
                    Button("Löschen", role: .destructive) {
                        onDelete()
                        dismiss()
                    }
                    Button("Abbrechen", role: .cancel) {}
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
        }
        .background(WatchTheme.bg)
    }

    private func formatDuration(_ t: Double) -> String {
        let s = Int(t)
        return String(format: "%d:%02d", s / 60, s % 60)
    }

    private func detailRow(icon: String, label: String, value: String,
                           valueColor: Color = WatchTheme.textPrimary) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundStyle(WatchTheme.textTert)
                .frame(width: 16)
            Text(label)
                .font(.footnote)
                .foregroundStyle(WatchTheme.textSecond)
            Spacer()
            Text(value)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(valueColor)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }
}
