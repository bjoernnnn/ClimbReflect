import SwiftUI
import SwiftData

struct ShoesView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Shoe.startYear, order: .reverse) private var shoes: [Shoe]

    @State private var showAddShoe = false
    @State private var newName = ""
    @State private var newMonth = Calendar.current.component(.month, from: .now)
    @State private var newYear = Calendar.current.component(.year, from: .now)
    @State private var editingShoe: Shoe? = nil

    private let months = (1...12).map { $0 }
    private var years: [Int] {
        let y = Calendar.current.component(.year, from: .now)
        return Array(stride(from: y, through: y - 10, by: -1))
    }

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            List {
                ForEach(shoes) { shoe in
                    Button { editingShoe = shoe } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(shoe.name)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(shoe.isRetired ? Theme.textTertiary : Theme.textPrimary)
                                Text("seit \(monthName(shoe.startMonth)) \(shoe.startYear)")
                                    .font(.caption)
                                    .foregroundStyle(Theme.textSecondary)
                            }
                            Spacer()
                            if shoe.isRetired {
                                Text("Inaktiv")
                                    .font(.caption2)
                                    .foregroundStyle(Theme.textTertiary)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Capsule().fill(Theme.bgElevated))
                            }
                        }
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
                    Image(systemName: "plus")
                        .foregroundStyle(Theme.accent)
                }
            }
        }
        .sheet(isPresented: $showAddShoe) {
            shoeFormSheet(shoe: nil)
        }
        .sheet(item: $editingShoe) { shoe in
            shoeFormSheet(shoe: shoe)
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Formular (anlegen + bearbeiten)

    private func shoeFormSheet(shoe: Shoe?) -> some View {
        ShoeFormView(shoe: shoe) { name, month, year, retired in
            if let shoe {
                shoe.name = name
                shoe.startMonth = month
                shoe.startYear = year
                shoe.isRetired = retired
            } else {
                let newShoe = Shoe(name: name, startMonth: month, startYear: year)
                context.insert(newShoe)
            }
            try? context.save()
            WatchSessionReceiver.shared.pushProjectsToWatch()
        }
    }

    private func deleteShoes(at offsets: IndexSet) {
        for idx in offsets {
            context.delete(shoes[idx])
        }
        try? context.save()
        WatchSessionReceiver.shared.pushProjectsToWatch()
    }

    private func monthName(_ m: Int) -> String {
        let df = DateFormatter()
        df.locale = Locale(identifier: "de_DE")
        df.dateFormat = "MM"
        return df.string(from: Calendar.current.date(from: DateComponents(month: m)) ?? .now)
    }
}

// MARK: - Schuh-Formular

struct ShoeFormView: View {
    var shoe: Shoe?
    var onSave: (String, Int, Int, Bool) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var month: Int
    @State private var year: Int
    @State private var isRetired: Bool

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

    init(shoe: Shoe?, onSave: @escaping (String, Int, Int, Bool) -> Void) {
        self.shoe = shoe
        self.onSave = onSave
        let now = Date()
        _name      = State(initialValue: shoe?.name ?? "")
        _month     = State(initialValue: shoe?.startMonth ?? Calendar.current.component(.month, from: now))
        _year      = State(initialValue: shoe?.startYear ?? Calendar.current.component(.year, from: now))
        _isRetired = State(initialValue: shoe?.isRetired ?? false)
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
                        .foregroundStyle(Theme.textPrimary)
                        .tint(Theme.accent)

                        Picker("Jahr", selection: $year) {
                            ForEach(years, id: \.self) { y in
                                Text(String(y)).tag(y)
                            }
                        }
                        .foregroundStyle(Theme.textPrimary)
                        .tint(Theme.accent)
                    } header: {
                        Text("Getragen seit").foregroundStyle(Theme.textTertiary)
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
                        onSave(trimmed, month, year, isRetired)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(name.trimmingCharacters(in: .whitespaces).isEmpty ? Theme.textTertiary : Theme.accent)
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
