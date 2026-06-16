import SwiftUI

struct GradePyramidView: View {
    let sessions: [ClimbSession]

    @State private var selectedSystem: GradeSystem = .fontainebleau

    private var entries: [StatsEngine.PyramidEntry] {
        StatsEngine.gradePyramid(sessions, system: selectedSystem)
    }

    private var maxTops: Int { entries.map(\.tops).max() ?? 1 }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Grad-Pyramide")
                        .font(.headline)
                        .foregroundStyle(Theme.textPrimary)
                    Text("Tops nach Schwierigkeit")
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                }
                Spacer()
                Picker("System", selection: $selectedSystem) {
                    ForEach(GradeSystem.allCases) { s in
                        Text(s.label).tag(s)
                    }
                }
                .pickerStyle(.menu)
                .tint(Theme.accent)
                .font(.caption)
            }

            if entries.isEmpty {
                Text("Erfasse Begehungen in deinen Sessions, um die Pyramide zu sehen.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 16)
            } else {
                VStack(spacing: 6) {
                    ForEach(entries) { entry in
                        HStack(spacing: 8) {
                            Text(entry.grade)
                                .font(.caption.weight(.bold))
                                .foregroundStyle(Theme.textPrimary)
                                .frame(width: 36, alignment: .leading)

                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Capsule().fill(Theme.bgElevated)
                                    if entry.tops > 0 {
                                        Capsule()
                                            .fill(Theme.accentGradient)
                                            .frame(width: max(4, geo.size.width * CGFloat(entry.tops) / CGFloat(maxTops)))
                                    }
                                }
                            }
                            .frame(height: 10)

                            HStack(spacing: 4) {
                                if entry.tops > 0 {
                                    Text("×\(entry.tops)")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(Theme.accent)
                                }
                                if entry.attempts > 0 {
                                    Text("+\(entry.attempts)")
                                        .font(.caption)
                                        .foregroundStyle(Theme.gold)
                                }
                            }
                            .frame(width: 52, alignment: .trailing)
                        }
                    }
                }
            }
        }
        .card()
    }
}

#Preview {
    GradePyramidView(sessions: MockData.makeSessions())
        .padding()
        .background(Theme.bg)
}
