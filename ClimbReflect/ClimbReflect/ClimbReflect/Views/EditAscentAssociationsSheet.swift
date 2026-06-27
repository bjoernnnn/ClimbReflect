import SwiftUI
import SwiftData

struct EditAscentAssociationsSheet: View {
    @Bindable var ascent: Ascent
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @Query(sort: \Project.name) private var allProjects: [Project]
    @Query(sort: \Shoe.startYear, order: .reverse) private var allShoes: [Shoe]

    private var activeProjects: [Project] { allProjects.filter(\.isActive) }
    private var activeShoes: [Shoe] { allShoes.filter { !$0.isRetired } }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.bg.ignoresSafeArea()
                Form {
                    // Projekt-Zuordnung
                    Section {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                projectChip(nil, label: "Kein Projekt")
                                ForEach(activeProjects) { p in
                                    projectChip(p, label: p.name)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    } header: {
                        Text("Projekt").foregroundStyle(Theme.textTertiary)
                    }
                    .listRowBackground(Theme.surface)

                    // Schuh-Zuordnung
                    if !activeShoes.isEmpty || ascent.shoeName != nil {
                        Section {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(activeShoes) { s in
                                        shoeChip(s, label: s.name)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        } header: {
                            Text("Schuh").foregroundStyle(Theme.textTertiary)
                        }
                        .listRowBackground(Theme.surface)
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Begehung zuordnen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fertig") { dismiss() }
                        .fontWeight(.semibold)
                        .foregroundStyle(Theme.accent)
                }
            }
        }
        .preferredColorScheme(.dark)
        .tint(Theme.accent)
    }

    @ViewBuilder
    private func projectChip(_ project: Project?, label: String) -> some View {
        let selected = ascent.project?.id == project?.id && (project != nil || ascent.project == nil)
        Button {
            ascent.project = project
            ascent.projectName = project?.name
        } label: {
            Text(label)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Capsule().fill(selected ? Theme.accent : Theme.bgElevated))
                .foregroundStyle(selected ? Theme.bg : Theme.textSecondary)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func shoeChip(_ shoe: Shoe?, label: String) -> some View {
        let selected = ascent.shoe?.id == shoe?.id && (shoe != nil || ascent.shoe == nil)
        Button {
            ascent.shoe = shoe
            ascent.shoeName = shoe?.name
        } label: {
            Text(label)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Capsule().fill(selected ? Theme.accent2 : Theme.bgElevated))
                .foregroundStyle(selected ? Theme.bg : Theme.textSecondary)
        }
        .buttonStyle(.plain)
    }
}
