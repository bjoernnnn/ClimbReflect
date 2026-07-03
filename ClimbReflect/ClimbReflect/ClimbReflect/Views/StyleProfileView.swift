import SwiftUI
import SwiftData

/// Unterseite „Stil & Limiter“ (Konzept ⑤) – Analyse on demand, hält die
/// Hauptseite frei. Zeigt Send-Quoten je Stil-Merkmal (nur n ≥ minSampleSize,
/// Stichprobe ausgewiesen) und die häufigsten Limiter im Zeitraum.
struct StyleProfileView: View {
    @Query(sort: \ClimbSession.date, order: .reverse) private var sessions: [ClimbSession]

    let discipline: ProgressEngine.Discipline
    let monthsBack: Int?

    private var rates: [ProgressEngine.StyleRate] {
        ProgressEngine.styleRates(sessions, discipline: discipline, monthsBack: monthsBack)
    }
    private var limiters: [(limiter: Limiter, count: Int)] {
        ProgressEngine.limiterCounts(sessions, monthsBack: monthsBack)
    }

    private let categoryOrder = ["Wandwinkel", "Grifftyp", "Kletterart"]

    var body: some View {
        ZStack {
            MountainBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if rates.isEmpty {
                        Text("Noch zu wenige getaggte Begehungen für belastbare Quoten.")
                            .font(.subheadline).foregroundStyle(Theme.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 8)
                    } else {
                        ForEach(categoryOrder, id: \.self) { category in
                            let group = rates.filter { $0.category == category }
                            if !group.isEmpty {
                                section(title: category, rows: group)
                            }
                        }
                    }

                    if !limiters.isEmpty {
                        limiterSection
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
        }
        .navigationTitle("Stil & Limiter")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .preferredColorScheme(.dark)
    }

    private func section(title: String, rows: [ProgressEngine.StyleRate]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline).foregroundStyle(Theme.textPrimary)
            ForEach(rows) { rate in
                rateRow(rate)
            }
        }
    }

    private func rateRow(_ rate: ProgressEngine.StyleRate) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(rate.label)
                    .font(.subheadline).foregroundStyle(Theme.textPrimary)
                Spacer()
                Text("\(Int((rate.sendRate * 100).rounded())) %")
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                    .foregroundStyle(Theme.textPrimary)
                Text("(\(rate.sample))")
                    .font(.caption).foregroundStyle(Theme.textTertiary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.bgElevated)
                    Capsule().fill(Theme.accent)
                        .frame(width: geo.size.width * CGFloat(rate.sendRate))
                }
            }
            .frame(height: 6)
        }
    }

    private var limiterSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Limiter")
                .font(.headline).foregroundStyle(Theme.textPrimary)
            ForEach(limiters, id: \.limiter) { entry in
                HStack {
                    Text(entry.limiter.label)
                        .font(.subheadline).foregroundStyle(Theme.textPrimary)
                    Spacer()
                    Text("\(entry.count)×")
                        .font(.subheadline.weight(.semibold).monospacedDigit())
                        .foregroundStyle(Theme.textSecondary)
                }
            }
        }
    }
}
