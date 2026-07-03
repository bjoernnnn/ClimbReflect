import SwiftUI
import SwiftData

// Farben für ShoeCondition (View-Layer, außerhalb des Models)
extension ShoeCondition {
    var color: Color {
        switch self {
        case .neu:         return Theme.accent
        case .eingetragen: return Theme.gold
        case .benutzt:     return Theme.textSecondary
        case .resoled:     return Theme.accent2
        }
    }
}

struct ShoesView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Shoe.startYear, order: .reverse) private var shoes: [Shoe]

    @State private var editingShoe: Shoe? = nil
    @State private var showAddShoe = false

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            List {
                ForEach(shoes) { shoe in
                    Button { editingShoe = shoe } label: {
                        ShoeRowView(shoe: shoe)
                    }
                    .buttonStyle(.plain)
                }
                .onDelete(perform: deleteShoes)
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Schuhe")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showAddShoe = true } label: {
                    Image(systemName: "plus").foregroundStyle(Theme.accent)
                }
            }
        }
        .sheet(isPresented: $showAddShoe) {
            ShoeFormView(shoe: nil, allShoes: shoes, onSave: save)
        }
        .sheet(item: $editingShoe) { shoe in
            ShoeFormView(shoe: shoe, allShoes: shoes, onSave: save)
        }
        .preferredColorScheme(.dark)
        .onAppear { ensureDefaultShoe() }
    }

    // MARK: - Logic

    private func ensureDefaultShoe() {
        guard shoes.isEmpty else { return }
        let now = Date()
        let cal = Calendar.current
        let shoe = Shoe(
            name: "Eigener Schuh",
            startMonth: cal.component(.month, from: now),
            startYear: cal.component(.year, from: now)
        )
        shoe.condition = .eingetragen
        shoe.isBuiltInDefault = true
        context.insert(shoe)
        try? context.save()
        WatchSessionReceiver.shared.pushProjectsToWatch()
    }

    private func save(shoe: Shoe?, name: String, month: Int, year: Int,
                      condition: ShoeCondition, retired: Bool, defaultForTypes: [SessionType]) {
        if let shoe {
            shoe.name = name
            shoe.startMonth = month
            shoe.startYear = year
            shoe.condition = condition
            shoe.isRetired = retired
            shoe.defaultForTypesRaw = defaultForTypes.map(\.rawValue)
        } else {
            let s = Shoe(name: name, startMonth: month, startYear: year)
            s.condition = condition
            s.defaultForTypesRaw = defaultForTypes.map(\.rawValue)
            context.insert(s)
        }
        // SH-B2: Typ kann nur einem Schuh zugehören — anderen entziehen
        let target = shoe ?? (try? context.fetch(FetchDescriptor<Shoe>()))?.last
        for other in shoes where other.id != target?.id {
            let cleaned = other.defaultForTypes.filter { !defaultForTypes.contains($0) }
            other.defaultForTypesRaw = cleaned.map(\.rawValue)
        }
        try? context.save()
        WatchSessionReceiver.shared.pushProjectsToWatch()
    }

    private func deleteShoes(at offsets: IndexSet) {
        for idx in offsets { context.delete(shoes[idx]) }
        try? context.save()
        WatchSessionReceiver.shared.pushProjectsToWatch()
    }
}

// MARK: - Schuh-Zeile

private struct ShoeRowView: View {
    let shoe: Shoe

    private func monthName(_ m: Int) -> String {
        let df = DateFormatter()
        df.locale = Locale(identifier: "de_DE")
        df.dateFormat = "MM"
        return df.string(from: Calendar.current.date(from: DateComponents(month: m)) ?? .now)
    }

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(shoe.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(shoe.isRetired ? Theme.textTertiary : Theme.textPrimary)
                Text("seit \(monthName(shoe.startMonth)) \(shoe.startYear)")
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer()
            HStack(spacing: 6) {
                if !shoe.isRetired {
                    conditionChip(shoe.condition)
                } else {
                    Text("Inaktiv")
                        .font(.caption2)
                        .foregroundStyle(Theme.textTertiary)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Capsule().fill(Theme.bgElevated))
                }
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(Theme.textTertiary)
            }
        }
        .padding(.vertical, 2)
    }

    private func conditionChip(_ c: ShoeCondition) -> some View {
        HStack(spacing: 3) {
            Image(systemName: c.symbol).font(.system(size: 9))
            Text(c.rawValue).font(.caption2.weight(.semibold))
        }
        .foregroundStyle(c.color)
        .padding(.horizontal, 6).padding(.vertical, 2)
        .background(Capsule().fill(c.color.opacity(0.12)))
    }
}

// MARK: - Schuh-Formular

struct ShoeFormView: View {
    var shoe: Shoe?
    var allShoes: [Shoe] = []
    var onSave: (Shoe?, String, Int, Int, ShoeCondition, Bool, [SessionType]) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var month: Int
    @State private var year: Int
    @State private var condition: ShoeCondition
    @State private var isRetired: Bool
    @State private var defaultForTypes: [SessionType]

    private let climbingTypes: [SessionType] = [.boulder, .lead, .topRope, .autoBelay]

    private var years: [Int] {
        let y = Calendar.current.component(.year, from: .now)
        return Array(stride(from: y, through: y - 10, by: -1))
    }
    private let monthLabels: [String] = {
        let df = DateFormatter()
        df.locale = Locale(identifier: "de_DE")
        df.dateFormat = "MMMM"
        return (1...12).map { m in
            df.string(from: Calendar.current.date(from: DateComponents(month: m)) ?? .now)
        }
    }()

    init(shoe: Shoe?, allShoes: [Shoe] = [], onSave: @escaping (Shoe?, String, Int, Int, ShoeCondition, Bool, [SessionType]) -> Void) {
        self.shoe = shoe
        self.allShoes = allShoes
        self.onSave = onSave
        let now = Date()
        _name           = State(initialValue: shoe?.name ?? "")
        _month          = State(initialValue: shoe?.startMonth ?? Calendar.current.component(.month, from: now))
        _year           = State(initialValue: shoe?.startYear ?? Calendar.current.component(.year, from: now))
        _condition      = State(initialValue: shoe?.condition ?? .neu)
        _isRetired      = State(initialValue: shoe?.isRetired ?? false)
        _defaultForTypes = State(initialValue: shoe?.defaultForTypes ?? [])
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.bg.ignoresSafeArea()
                Form {
                    Section {
                        TextField("Name (z. B. Solution Comp)", text: $name)
                            .foregroundStyle(Theme.textPrimary)
                    } header: {
                        Text("Name").foregroundStyle(Theme.textTertiary)
                    }
                    .listRowBackground(Theme.surface)

                    Section {
                        Picker("Monat", selection: $month) {
                            ForEach(1...12, id: \.self) { m in
                                Text(monthLabels[m - 1]).tag(m)
                            }
                        }
                        .foregroundStyle(Theme.textPrimary).tint(Theme.accent)

                        Picker("Jahr", selection: $year) {
                            ForEach(years, id: \.self) { y in Text(String(y)).tag(y) }
                        }
                        .foregroundStyle(Theme.textPrimary).tint(Theme.accent)
                    } header: {
                        Text("Getragen seit").foregroundStyle(Theme.textTertiary)
                    }
                    .listRowBackground(Theme.surface)

                    // Zustand
                    Section {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(ShoeCondition.allCases) { c in
                                    let selected = condition == c
                                    Button { condition = c } label: {
                                        HStack(spacing: 4) {
                                            Image(systemName: c.symbol).font(.system(size: 11))
                                            Text(c.rawValue).font(.caption.weight(.semibold))
                                        }
                                        .foregroundStyle(selected ? Theme.bg : c.color)
                                        .padding(.horizontal, 12).padding(.vertical, 6)
                                        .background(Capsule().fill(selected ? c.color : c.color.opacity(0.12)))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    } header: {
                        Text("Zustand").foregroundStyle(Theme.textTertiary)
                    }
                    .listRowBackground(Theme.surface)

                    // SH-B: Standard-Schuh je Kletterart
                    Section {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 8)], spacing: 8) {
                            ForEach(climbingTypes) { type in
                                let selected = defaultForTypes.contains(type)
                                let takenByOther = !selected && allShoes.contains {
                                    $0.id != shoe?.id && $0.defaultForTypes.contains(type)
                                }
                                Button {
                                    if selected {
                                        defaultForTypes.removeAll { $0 == type }
                                    } else {
                                        defaultForTypes.append(type)
                                    }
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: type.symbol).font(.system(size: 11))
                                        Text(type.label).font(.caption.weight(.semibold))
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 7)
                                    .background(
                                        Capsule().fill(
                                            selected ? Theme.accent :
                                            takenByOther ? Theme.bgElevated.opacity(0.5) : Theme.bgElevated
                                        )
                                    )
                                    .foregroundStyle(
                                        selected ? Theme.bg :
                                        takenByOther ? Theme.textTertiary : Theme.textSecondary
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 4)
                        if defaultForTypes.isEmpty {
                            Text("Kein Standard – wird nicht automatisch vorausgewählt.")
                                .font(.caption)
                                .foregroundStyle(Theme.textTertiary)
                        }
                    } header: {
                        Text("Standard für").foregroundStyle(Theme.textTertiary)
                    } footer: {
                        Text("Dieser Schuh wird beim Starten einer Session dieses Typs automatisch vorausgewählt.")
                            .foregroundStyle(Theme.textTertiary)
                    }
                    .listRowBackground(Theme.surface)

                    if shoe != nil {
                        Section {
                            Toggle("Inaktiv (retired)", isOn: $isRetired)
                                .tint(Theme.accent)
                                .foregroundStyle(Theme.textPrimary)
                        }
                        .listRowBackground(Theme.surface)
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle(shoe == nil ? "Schuh anlegen" : "Schuh bearbeiten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Abbrechen") { dismiss() }
                        .foregroundStyle(Theme.textSecondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Speichern") {
                        let trimmed = name.trimmingCharacters(in: .whitespaces)
                        guard !trimmed.isEmpty else { return }
                        onSave(shoe, trimmed, month, year, condition, isRetired, defaultForTypes)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(name.trimmingCharacters(in: .whitespaces).isEmpty
                                     ? Theme.textTertiary : Theme.accent)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .preferredColorScheme(.dark)
        .tint(Theme.accent)
    }
}

#Preview {
    let container = try! ModelContainer(
        for: ClimbSession.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    return NavigationStack { ShoesView() }.modelContainer(container)
}
