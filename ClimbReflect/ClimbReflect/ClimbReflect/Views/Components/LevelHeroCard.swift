import SwiftUI

/// FS-3: Status quo → nächste Stufe auf einen Blick, ersetzt die reine
/// Vergangenheits-Anzeige der alten PB-Kacheln (Review 6.1).
struct LevelHeroCard: View {
    let sessions: [ClimbSession]
    let projects: [Project]
    let unlocks: [AchievementUnlock]
    let onOpenProgress: (ProgressEngine.Discipline) -> Void

    private static let achievementCategories: Set<AchievementCategory> = [.schwierigkeit, .stil, .projekte, .ausdauer]

    private var discipline: ProgressEngine.Discipline {
        guard let latest = sessions.first(where: \.isClimbing) else { return .boulder }
        return GradeDefaults.discipline(for: latest.sessionType)
    }

    private var otherDiscipline: ProgressEngine.Discipline {
        discipline == .boulder ? .rope : .boulder
    }

    private var pb: ProgressEngine.PersonalBest? {
        ProgressEngine.personalBests(sessions, discipline: discipline).send
    }

    private var otherPB: ProgressEngine.PersonalBest? {
        ProgressEngine.personalBests(sessions, discipline: otherDiscipline).send
    }

    private var nextGradeValue: String? {
        pb.flatMap { ProgressEngine.nextGrade(afterOrder: $0.order, discipline: discipline) }
    }

    private var comfortMilestone: ProgressEngine.Milestone? {
        ProgressEngine.milestones(sessions, discipline: discipline, monthsBack: 6)
            .first { $0.kind == .comfortGrade }
    }

    private var bestAchievement: AchievementViewData? {
        AchievementViewModel.build(sessions: sessions, projects: projects, unlocks: unlocks)
            .filter {
                !$0.isUnlocked && !$0.definition.isHidden
                    && Self.achievementCategories.contains($0.definition.category)
                    && ($0.progress?.fraction ?? 0) > 0 && ($0.progress?.fraction ?? 0) < 1
            }
            .max { ($0.progress?.fraction ?? 0) < ($1.progress?.fraction ?? 0) }
    }

    private var milestoneRows: [MilestoneRow] {
        var rows: [MilestoneRow] = []
        if let comfortMilestone { rows.append(MilestoneRow(comfortMilestone)) }
        if let bestAchievement { rows.append(MilestoneRow(achievement: bestAchievement)) }
        return Array(rows.prefix(3))
    }

    private var streak: Int { StatsEngine.climbWeekStreak(sessions) }
    private var bestStreak: Int { StatsEngine.bestClimbWeekStreak(sessions) }

    var body: some View {
        Button {
            onOpenProgress(discipline)
        } label: {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text(discipline == .boulder ? "Bouldern" : "Seil")
                        .font(Theme.Typo.label)
                        .foregroundStyle(Theme.textSecondary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Theme.textTertiary)
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(pb?.grade ?? "—")
                            .font(Theme.Typo.metricHero)
                            .foregroundStyle(pb != nil ? Theme.gold : Theme.textTertiary)
                            .contentTransition(.interpolate)
                        if let nextGradeValue {
                            Image(systemName: "arrow.right")
                                .font(.subheadline)
                                .foregroundStyle(Theme.textTertiary)
                            Text(nextGradeValue)
                                .font(Theme.Typo.metric)
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }
                    if let pb {
                        Text("Höchster Top · \(pb.date.formatted(.dateTime.month(.wide).year()))")
                            .font(.caption)
                            .foregroundStyle(Theme.textTertiary)
                    } else {
                        Text("Noch kein Top")
                            .font(.caption)
                            .foregroundStyle(Theme.textTertiary)
                    }
                }

                if !milestoneRows.isEmpty {
                    VStack(spacing: 10) {
                        ForEach(Array(milestoneRows.enumerated()), id: \.offset) { index, row in
                            row
                            if index < milestoneRows.count - 1 {
                                Divider().overlay(Theme.separator)
                            }
                        }
                    }
                }

                if streak >= 1 {
                    HStack(spacing: 4) {
                        Label("\(streak) Woche\(streak == 1 ? "" : "n") in Folge", systemImage: "flame.fill")
                            .foregroundStyle(Theme.accent)
                        if bestStreak > streak {
                            Text("· Rekord \(bestStreak)")
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }
                    .font(.caption.weight(.semibold))
                }

                if let otherPB {
                    Text("\(otherDiscipline == .boulder ? "Bouldern" : "Seil") · \(otherPB.grade)")
                        .font(.caption)
                        .foregroundStyle(Theme.textTertiary)
                }
            }
            .card()
        }
        .buttonStyle(.card)
        .animation(.snappy, value: pb?.grade)
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
