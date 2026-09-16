import SwiftUI
import SwiftData

/// FS-7: statische Zusammenfassung nach einer Watch-Session – bündelt Erfolge,
/// Fortschritt und den Reflexions-Einstieg in einen Moment statt drei
/// Unterbrechungen. Kein Timer, keine Partikel, keine Sounds (S33: einziger
/// Feier-Kanal bleibt das AchievementUnlockOverlay).
struct SessionRecapSheet: View {
    let session: ClimbSession
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \ClimbSession.date, order: .reverse) private var allSessions: [ClimbSession]
    @Query private var allUnlocks: [AchievementUnlock]
    @State private var detent: PresentationDetent = .medium
    @State private var navigateToDetail = false

    private var recap: ProgressEngine.SessionRecap {
        ProgressEngine.sessionRecap(session, allSessions: allSessions)
    }

    private var sessionUnlocks: [AchievementUnlock] {
        allUnlocks.filter { $0.sessionID == session.id }.sorted { $0.unlockedAt < $1.unlockedAt }
    }

    private var milestones: [ProgressEngine.Milestone] {
        guard let discipline = recap.discipline else { return [] }
        return Array(ProgressEngine.milestones(allSessions, discipline: discipline).prefix(2))
    }

    private var headline: (text: String, gold: Bool) {
        if let project = recap.projectsCompleted.first {
            return ("\(project) geschafft", true)
        }
        if let firstTop = recap.firstTopGrades.first {
            return ("Erster Top in \(firstTop)", true)
        }
        if let hardest = recap.hardestTop {
            return (hardest, false)
        }
        return ("\(recap.ascents) Begehung\(recap.ascents == 1 ? "" : "en")", false)
    }

    /// Erst-Tops ab dem zweiten – der erste steckt ggf. schon in der Hauptaussage.
    private var additionalFirstTops: [String] {
        let usedAsHeadline = recap.projectsCompleted.isEmpty && !recap.firstTopGrades.isEmpty
        return Array(recap.firstTopGrades.dropFirst(usedAsHeadline ? 1 : 0))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    statsLine
                    if !additionalFirstTops.isEmpty {
                        firstTopChips
                    }
                    if !sessionUnlocks.isEmpty {
                        unlockedSection
                    }
                    if !milestones.isEmpty {
                        nextSection
                    }
                }
                .padding(20)
            }
            .background(Theme.bg)
            .safeAreaInset(edge: .bottom) { buttons }
            .navigationDestination(isPresented: $navigateToDetail) {
                SessionDetailView(session: session)
            }
        }
        .presentationDetents([.medium, .large], selection: $detent)
        .presentationDragIndicator(.visible)
        .accessibilityElement(children: .contain)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: session.sessionType.symbol)
                    .foregroundStyle(Theme.accent)
                Text("\(session.sessionType.label) · \(session.date.formatted(.dateTime.weekday(.wide).day().month(.wide)))")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
            }
            Text(headline.text)
                .font(Theme.Typo.metricHero)
                .foregroundStyle(headline.gold ? Theme.gold : Theme.textPrimary)
        }
    }

    private var statsLine: some View {
        Text("\(recap.tops) Top\(recap.tops == 1 ? "" : "s") · \(recap.ascents) Begehung\(recap.ascents == 1 ? "" : "en") · \(session.durationMinutes) Min")
            .font(.subheadline)
            .foregroundStyle(Theme.textSecondary)
    }

    private var firstTopChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(additionalFirstTops, id: \.self) { grade in
                    Text("Erstmals \(grade)")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(Theme.gold.opacity(0.15)))
                        .foregroundStyle(Theme.gold)
                }
            }
        }
    }

    private var unlockedSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Freigeschaltet")
                .font(Theme.Typo.section)
                .foregroundStyle(Theme.textPrimary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(sessionUnlocks, id: \.id) { unlock in
                        VStack(spacing: 4) {
                            AchievementMedallion(
                                symbol: AchievementDefinition.definition(id: unlock.definitionID)?.symbol ?? "star.fill",
                                state: .unlocked(material: unlock.material), size: 44)
                            Text(AchievementDefinition.definition(id: unlock.definitionID)?.title ?? "")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(Theme.textPrimary)
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                                .frame(width: 64)
                        }
                    }
                }
            }
        }
    }

    private var nextSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Als Nächstes")
                .font(Theme.Typo.section)
                .foregroundStyle(Theme.textPrimary)
            VStack(spacing: 10) {
                ForEach(Array(milestones.enumerated()), id: \.offset) { index, milestone in
                    MilestoneRow(milestone)
                    if index < milestones.count - 1 {
                        Divider().overlay(Theme.separator)
                    }
                }
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous).fill(Theme.surfaceRaised))
        }
    }

    private var buttons: some View {
        VStack(spacing: 10) {
            Button("Kurz reflektieren") {
                detent = .large
                navigateToDetail = true
            }
            .buttonStyle(.borderedProminent)
            .frame(maxWidth: .infinity)
            .controlSize(.large)

            Button("Später") { dismiss() }
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity)
                .controlSize(.large)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.bar)
    }
}
