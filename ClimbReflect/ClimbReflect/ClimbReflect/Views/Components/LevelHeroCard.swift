import SwiftUI

/// FS-3: Status quo → nächste Stufe auf einen Blick, ersetzt die reine
/// Vergangenheits-Anzeige der alten PB-Kacheln (Review 6.1).
/// PG-7: alle abgeleiteten Werte stecken in `Model`, einmal pro Render gebaut
/// (Abnahme 4.7 – AchievementViewModel.build lief vorher pro Computed Property).
struct LevelHeroCard: View {
    let sessions: [ClimbSession]
    let projects: [Project]
    let unlocks: [AchievementUnlock]
    let onOpenProgress: (ProgressEngine.Discipline) -> Void

    private struct Model {
        let discipline: ProgressEngine.Discipline
        let pb: ProgressEngine.PersonalBest?
        let nextGrade: String?
        let comfort: ProgressEngine.Milestone?
        let achievement: AchievementViewData?

        static let achievementCategories: Set<AchievementCategory> = [.schwierigkeit, .stil, .projekte, .ausdauer]

        init(sessions: [ClimbSession], projects: [Project], unlocks: [AchievementUnlock]) {
            let discipline: ProgressEngine.Discipline
            if let latest = sessions.first(where: \.isClimbing) {
                discipline = GradeDefaults.discipline(for: latest.sessionType)
            } else {
                discipline = .boulder
            }
            self.discipline = discipline

            let pb = ProgressEngine.personalBests(sessions, discipline: discipline).send
            self.pb = pb
            self.nextGrade = pb.flatMap { ProgressEngine.nextGrade(afterOrder: $0.order, discipline: discipline) }
            self.comfort = ProgressEngine.milestones(sessions, discipline: discipline, monthsBack: 6)
                .first { $0.kind == .comfortGrade }
            self.achievement = AchievementViewModel.build(sessions: sessions, projects: projects, unlocks: unlocks)
                .filter {
                    !$0.isUnlocked && !$0.definition.isHidden
                        && Self.achievementCategories.contains($0.definition.category)
                        && ($0.progress?.fraction ?? 0) > 0 && ($0.progress?.fraction ?? 0) < 1
                }
                .max { ($0.progress?.fraction ?? 0) < ($1.progress?.fraction ?? 0) }
        }

        var milestoneRows: [MilestoneRow] {
            var rows: [MilestoneRow] = []
            if let comfort { rows.append(MilestoneRow(comfort)) }
            if let achievement { rows.append(MilestoneRow(achievement: achievement)) }
            return Array(rows.prefix(2))
        }
    }

    var body: some View {
        let m = Model(sessions: sessions, projects: projects, unlocks: unlocks)
        Button {
            onOpenProgress(m.discipline)
        } label: {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text(m.discipline.label)
                            .font(Theme.Typo.label)
                            .foregroundStyle(Theme.textSecondary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Theme.textTertiary)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text(m.pb?.grade ?? "—")
                                .font(Theme.Typo.metricHero)
                                .foregroundStyle(m.pb != nil ? Theme.gold : Theme.textTertiary)
                                .contentTransition(.interpolate)
                            if let nextGrade = m.nextGrade {
                                Image(systemName: "arrow.right")
                                    .font(.subheadline)
                                    .foregroundStyle(Theme.textTertiary)
                                Text(nextGrade)
                                    .font(Theme.Typo.metric)
                                    .foregroundStyle(Theme.textSecondary)
                            }
                        }
                        if let pb = m.pb {
                            Text("Höchster Top · \(pb.date.formatted(.dateTime.month(.wide).year()))")
                                .font(.caption)
                                .foregroundStyle(Theme.textTertiary)
                        } else {
                            Text("Noch kein Top")
                                .font(.caption)
                                .foregroundStyle(Theme.textTertiary)
                        }
                    }
                }

                if !m.milestoneRows.isEmpty {
                    VStack(spacing: 12) {
                        ForEach(Array(m.milestoneRows.enumerated()), id: \.offset) { index, row in
                            row
                            if index < m.milestoneRows.count - 1 {
                                Divider().overlay(Theme.separator)
                            }
                        }
                    }
                }
            }
            .card()
        }
        .buttonStyle(.card)
        .animation(.snappy, value: m.pb?.grade)
        .accessibilityHint("Öffnet Fortschritt")
    }
}

#Preview("Voll") {
    let sessions = MockData.makeSessions()
    return LevelHeroCard(sessions: sessions, projects: [], unlocks: [], onOpenProgress: { _ in })
        .padding()
        .background(Theme.bg)
}

#Preview("Spärlich") {
    LevelHeroCard(sessions: [], projects: [], unlocks: [], onOpenProgress: { _ in })
        .padding()
        .background(Theme.bg)
}
