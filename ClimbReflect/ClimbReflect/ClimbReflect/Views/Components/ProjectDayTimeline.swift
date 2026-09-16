import SwiftUI

/// FS-6: erzählt Hartnäckigkeit ehrlich über distinctDays statt eines
/// attempts-basierten Charts (S32, PJ-Block-Ziel).
struct ProjectDayTimeline: View {
    let project: Project

    private var days: [Date] {
        Array(Set(project.ascents.map { Calendar.current.startOfDay(for: $0.date) })).sorted()
    }

    private var topDayIndex: Int? {
        let topDates = project.ascents.filter { $0.result == .top }
            .map { Calendar.current.startOfDay(for: $0.date) }
        guard let topDate = topDates.min() else { return nil }
        return days.firstIndex(of: topDate)
    }

    var body: some View {
        if !days.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                header
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 0) {
                        ForEach(Array(days.enumerated()), id: \.offset) { index, day in
                            dayPoint(index: index, day: day)
                            if index < days.count - 1 {
                                Rectangle()
                                    .fill(Theme.separator)
                                    .frame(width: 20, height: 2)
                            }
                        }
                    }
                }
                .defaultScrollAnchor(.trailing)
            }
            .card()
        }
    }

    private var header: some View {
        Group {
            if let topDayIndex {
                Text("Geschafft an Tag \(topDayIndex + 1)")
                    .foregroundStyle(Theme.gold)
            } else {
                Text("Tag \(days.count) am Projekt")
                    .foregroundStyle(Theme.textPrimary)
            }
        }
        .font(.headline)
    }

    @ViewBuilder
    private func dayPoint(index: Int, day: Date) -> some View {
        let isTop = index == topDayIndex
        VStack(spacing: 4) {
            ZStack {
                if isTop {
                    Circle()
                        .fill(Theme.gold)
                        .frame(width: 22, height: 22)
                    Image(systemName: "checkmark")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(Theme.bg)
                } else {
                    Circle()
                        .fill(Theme.surfaceRaised)
                        .frame(width: 14, height: 14)
                        .overlay(Circle().stroke(Theme.accent, lineWidth: 1.5))
                }
            }
            .frame(height: 22)
            Text("Tag \(index + 1)")
                .font(.caption2)
                .foregroundStyle(Theme.textTertiary)
            if index == 0 || index == days.count - 1 {
                Text(day.formatted(.dateTime.day().month(.twoDigits)))
                    .font(.caption2)
                    .foregroundStyle(Theme.textTertiary)
            }
        }
        .frame(width: 44)
    }
}

#Preview {
    let project = Project(name: "Blauer Riss")
    let session = ClimbSession(date: .now, durationSeconds: 3600, sessionType: .boulder, source: .manual)
    for offset in [0, -3, -7] {
        let date = Calendar.current.date(byAdding: .day, value: offset, to: .now) ?? .now
        let ascent = Ascent(gradeSystem: .fontainebleau, grade: "7A",
                            result: offset == -7 ? .top : .attempt, date: date, session: session)
        ascent.project = project
    }
    return ProjectDayTimeline(project: project)
        .padding()
        .background(Theme.bg)
}
