import SwiftUI
import SwiftData

/// Erfolge-Tab „Gipfelmarken" (ERFOLGE-KONZEPT-V2 · 6.4): Sammlung-Header,
/// „In Reichweite", Kategorie-Chips, Grid. Ersetzt den horizontalen Streifen
/// aus dem alten StatsEngine-Ableitungssystem (Alt-Code-Abbau folgt in EP-12).
struct AchievementsView: View {
    @Query(sort: \ClimbSession.date, order: .reverse) private var sessions: [ClimbSession]
    @Query private var projects: [Project]
    @Query private var unlocks: [AchievementUnlock]

    @State private var selectedCategory: AchievementCategory?
    @State private var selectedDefinitionID: String?

    private var viewData: [AchievementViewData] {
        AchievementViewModel.build(sessions: sessions, projects: projects, unlocks: unlocks)
    }

    private var unlockedCount: Int { viewData.filter(\.isUnlocked).count }
    private var totalCount: Int { AchievementDefinition.all.count }

    private var inReach: [AchievementViewData] {
        Array(viewData
            .filter { !$0.isUnlocked && !$0.definition.isHidden && ($0.progress?.fraction ?? 0) >= 0.5 }
            .sorted { ($0.progress?.fraction ?? 0) > ($1.progress?.fraction ?? 0) }
            .prefix(3))
    }

    private var filtered: [AchievementViewData] {
        guard let selectedCategory else { return viewData }
        return viewData.filter { $0.definition.category == selectedCategory }
    }

    private var selectedData: AchievementViewData? {
        guard let selectedDefinitionID else { return nil }
        return viewData.first { $0.id == selectedDefinitionID }
    }

    private let columns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]

    var body: some View {
        NavigationStack {
            ZStack {
                MountainBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        header
                        if !inReach.isEmpty { inReachSection }
                        categoryChips
                        grid
                        betaLibraryLink
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Erfolge")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .sheet(isPresented: Binding(
                get: { selectedDefinitionID != nil },
                set: { if !$0 { selectedDefinitionID = nil } }
            )) {
                if let data = selectedData {
                    AchievementDetailSheet(data: data)
                        .presentationDetents([.medium, .large])
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Sammlung".uppercased())
                    .font(.caption2.weight(.semibold))
                    .tracking(0.4)
                    .foregroundStyle(Theme.textTertiary)
                (Text("\(unlockedCount) ")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)
                 + Text("von \(totalCount)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.textTertiary))
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.bgElevated)
                    Capsule().fill(Theme.accentGradient)
                        .frame(width: geo.size.width * CGFloat(unlockedCount) / CGFloat(max(1, totalCount)))
                }
            }
            .frame(height: 4)
        }
    }

    // MARK: - In Reichweite

    private var inReachSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("In Reichweite")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.textPrimary)
            ForEach(inReach) { data in
                Button { selectedDefinitionID = data.id } label: {
                    HStack(spacing: 12) {
                        AchievementMedallion(symbol: data.definition.symbol,
                                             state: .locked(progress: data.progress?.fraction), size: 46)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(data.definition.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Theme.textPrimary)
                            Text(data.progress?.remainingText ?? "")
                                .font(.caption)
                                .foregroundStyle(Theme.textTertiary)
                                .lineLimit(1)
                        }
                        Spacer(minLength: 8)
                        Text("\(Int(((data.progress?.fraction ?? 0) * 100).rounded())) %")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Theme.accent)
                            .monospacedDigit()
                    }
                    .padding(11)
                    .background(RoundedRectangle(cornerRadius: 16).fill(Theme.surface))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.surfaceStroke, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Kategorie-Chips

    private var categoryChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                categoryChip(nil, label: "Alle")
                ForEach(AchievementCategory.allCases) { cat in
                    categoryChip(cat, label: cat.label)
                }
            }
            .padding(.vertical, 2)
        }
        .scrollClipDisabled()
    }

    private func categoryChip(_ category: AchievementCategory?, label: String) -> some View {
        let active = selectedCategory == category
        return Button { selectedCategory = category } label: {
            Text(label)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Capsule().fill(active ? Theme.accent : Theme.bgElevated))
                .foregroundStyle(active ? Theme.bg : Theme.textSecondary)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Grid

    private var grid: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(filtered) { data in
                Button { selectedDefinitionID = data.id } label: {
                    AchievementTile(data: data)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var betaLibraryLink: some View {
        NavigationLink(destination: BetaLibraryView()) {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(Theme.accent.opacity(0.12)).frame(width: 44, height: 44)
                    Image(systemName: "text.magnifyingglass")
                        .font(.system(size: 18))
                        .foregroundStyle(Theme.accent)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text("Beta-Bibliothek")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.textPrimary)
                    Text("Tipps & Techniken für Kletterprobleme")
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textTertiary)
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 14).fill(Theme.surface))
        }
        .buttonStyle(.plain)
    }
}
