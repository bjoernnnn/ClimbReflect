import SwiftUI
import SwiftData

struct AddAscentView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let session: ClimbSession

    @State private var gradeSystem: GradeSystem = .fontainebleau
    @State private var selectedGrade: String = "6A"
    @State private var result: AscentResult = .top
    @State private var style: AscentStyle = .redpoint
    @State private var attempts: Int = 1
    @State private var note: String = ""
    @State private var wallAngle: WallAngle? = nil
    @State private var holdType: HoldType? = nil
    @State private var climbStyle: ClimbStyle? = nil
    @State private var projectName: String = ""
    @State private var showCelebration = false

    private var grades: [String] { gradeSystem.grades }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.bg.ignoresSafeArea()

                Form {
                    // MARK: Grad-System
                    Section {
                        Picker("Grad-System", selection: $gradeSystem) {
                            ForEach(GradeSystem.allCases) { s in
                                Text(s.label).tag(s)
                            }
                        }
                        .pickerStyle(.menu)
                        .foregroundStyle(Theme.textPrimary)
                        .onChange(of: gradeSystem) { _, new in
                            if !new.grades.contains(selectedGrade) {
                                selectedGrade = new.grades[min(8, new.grades.count - 1)]
                            }
                        }

                        Picker("Grad", selection: $selectedGrade) {
                            ForEach(grades, id: \.self) { g in
                                Text(g).tag(g)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(height: 120)
                    } header: {
                        Text("Schwierigkeit").foregroundStyle(Theme.textTertiary)
                    }
                    .listRowBackground(Theme.surface)

                    // MARK: Ergebnis
                    Section {
                        Picker("Ergebnis", selection: $result) {
                            ForEach(AscentResult.allCases) { r in
                                Label(r.label, systemImage: r.symbol)
                                    .foregroundStyle(r.color)
                                    .tag(r)
                            }
                        }
                        .pickerStyle(.segmented)

                        if result == .top {
                            Picker("Stil", selection: $style) {
                                ForEach(AscentStyle.allCases) { s in
                                    Label(s.label, systemImage: s.symbol).tag(s)
                                }
                            }
                            .foregroundStyle(Theme.textPrimary)
                        }

                        Stepper("Versuche: \(attempts)", value: $attempts, in: 1...999)
                            .foregroundStyle(Theme.textPrimary)
                    } header: {
                        Text("Ergebnis").foregroundStyle(Theme.textTertiary)
                    }
                    .listRowBackground(Theme.surface)

                    // MARK: Stil-Tags (P3.7)
                    Section {
                        tagRow("Wandwinkel", options: WallAngle.allCases,
                               label: { $0.label }, selection: $wallAngle)
                        tagRow("Grifftyp", options: HoldType.allCases,
                               label: { $0.label }, selection: $holdType)
                        tagRow("Kletterstil", options: ClimbStyle.allCases,
                               label: { $0.label }, selection: $climbStyle)
                    } header: {
                        Text("Stil-Tags (optional)").foregroundStyle(Theme.textTertiary)
                    }
                    .listRowBackground(Theme.surface)

                    // MARK: Projekt (P3.5)
                    Section {
                        HStack {
                            Image(systemName: "target")
                                .foregroundStyle(Theme.accent)
                                .frame(width: 20)
                            TextField("Projektname (optional)", text: $projectName)
                                .foregroundStyle(Theme.textPrimary)
                        }
                    } header: {
                        Text("Projekt").foregroundStyle(Theme.textTertiary)
                    } footer: {
                        Text("Gleicher Name über Sessions hinweg verbindet Versuche zu einem Projekt.")
                            .foregroundStyle(Theme.textTertiary)
                    }
                    .listRowBackground(Theme.surface)

                    // MARK: Notiz
                    Section {
                        ZStack(alignment: .topLeading) {
                            if note.isEmpty {
                                Text("Beta, Schlüsselzug, Notiz…")
                                    .font(.subheadline)
                                    .foregroundStyle(Theme.textTertiary)
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 8)
                                    .allowsHitTesting(false)
                            }
                            TextEditor(text: $note)
                                .font(.subheadline)
                                .foregroundStyle(Theme.textPrimary)
                                .scrollContentBackground(.hidden)
                                .frame(minHeight: 72)
                        }
                    } header: {
                        Text("Notiz (optional)").foregroundStyle(Theme.textTertiary)
                    }
                    .listRowBackground(Theme.surface)
                }
                .scrollContentBackground(.hidden)

                // P3.2 - Send-Feier Animation
                if showCelebration {
                    CelebrationOverlay()
                        .allowsHitTesting(false)
                }
            }
            .navigationTitle("Begehung erfassen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Abbrechen") { dismiss() }
                        .foregroundStyle(Theme.textSecondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Speichern") { save() }
                        .fontWeight(.semibold)
                        .foregroundStyle(Theme.accent)
                }
            }
        }
        .preferredColorScheme(.dark)
        .tint(Theme.accent)
        .onAppear {
            if !gradeSystem.grades.contains(selectedGrade) {
                selectedGrade = gradeSystem.grades[min(8, gradeSystem.grades.count - 1)]
            }
        }
    }

    @ViewBuilder
    private func tagRow<T: Identifiable & Hashable>(
        _ title: String,
        options: [T],
        label: @escaping (T) -> String,
        selection: Binding<T?>
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.textTertiary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(options, id: \.id) { opt in
                        let selected = selection.wrappedValue == opt
                        Button {
                            selection.wrappedValue = selected ? nil : opt
                        } label: {
                            Text(label(opt))
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Capsule().fill(selected ? Theme.accent : Theme.bgElevated))
                                .foregroundStyle(selected ? Theme.bg : Theme.textSecondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func save() {
        let ascent = Ascent(
            gradeSystem: gradeSystem,
            grade: selectedGrade,
            result: result,
            style: result == .top ? style : nil,
            attempts: attempts,
            note: note.isEmpty ? nil : note,
            date: session.date,
            wallAngle: wallAngle,
            holdType: holdType,
            climbStyle: climbStyle,
            projectName: projectName.isEmpty ? nil : projectName,
            session: session
        )
        context.insert(ascent)
        try? context.save()

        if result == .top {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                showCelebration = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
                dismiss()
            }
        } else {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            dismiss()
        }
    }
}

// MARK: - Send-Feier (P3.2)

struct CelebrationOverlay: View {
    @State private var scale: CGFloat = 0.3
    @State private var opacity: Double = 0

    var body: some View {
        ZStack {
            Color.black.opacity(0.45).ignoresSafeArea()

            VStack(spacing: 16) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(Theme.accent)
                    .scaleEffect(scale)
                Text("Top!")
                    .font(.system(size: 40, weight: .black, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)
                    .opacity(opacity)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.55)) {
                scale = 1.0
            }
            withAnimation(.easeIn(duration: 0.25).delay(0.15)) {
                opacity = 1.0
            }
        }
    }
}

#Preview {
    let container = try! ModelContainer(
        for: ClimbSession.self, Ascent.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    let session = MockData.makeSessions()[0]
    container.mainContext.insert(session)
    return AddAscentView(session: session).modelContainer(container)
}
