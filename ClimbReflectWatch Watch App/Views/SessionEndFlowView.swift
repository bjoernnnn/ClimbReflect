import SwiftUI

// Eigener NavigationStack für Fragebogen + Zusammenfassung nach dem Training.
// Läuft in ContentView unabhängig von LiveSessionView, sodass finishSession()
// (isRunning = false) den Flow nicht zerstört (Blackscreen-Fix).

struct SessionEndFlowView: View {
    @EnvironmentObject var workoutManager: WorkoutManager
    let dto: WatchSessionDTO
    @State private var enrichedDTO: WatchSessionDTO?

    private var skipFocus: Bool {
        dto.sessionTypeRaw == WatchSessionType.training.rawValue
    }

    var body: some View {
        NavigationStack {
            if let enriched = enrichedDTO {
                SessionSummaryView(dto: enriched, onDone: {
                    workoutManager.pendingSummaryDTO = nil
                })
            } else {
                SessionEndQuestionnaireView(dto: dto, skipFocus: skipFocus) { enriched in
                    SyncService.shared.send(dto: enriched)
                    enrichedDTO = enriched
                }
            }
        }
    }
}
