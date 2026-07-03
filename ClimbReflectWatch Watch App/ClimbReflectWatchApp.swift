//
//  ClimbReflectWatchApp.swift
//  ClimbReflectWatch Watch App
//
//  Created by Björn Dresel on 2026-06-16.
//

import SwiftUI
import AppIntents

@main
struct ClimbReflectWatchApp: App {
    @StateObject private var workoutManager = WorkoutManager.shared
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(workoutManager)
                .task {
                    // AB-H: Workout-Registry des Systems auffrischen – ein veralteter
                    // LinkServices-Cache kann Action-Button-Drücke ins Leere laufen lassen.
                    StartClimbWorkoutIntent.invalidateSuggestedWorkouts()
                    await workoutManager.requestAuthorization()
                    // AB-G: Idle-Start läuft jetzt direkt im Intent (startFromActionButton);
                    // recoverIfNeeded ist single-flight, doppelter Aufruf ist harmlos.
                    await workoutManager.recoverIfNeeded()
                }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { DiagnosticLog.shared.flush() }
            let name: String
            switch phase {
            case .active:     name = "active"
            case .inactive:   name = "inactive"
            case .background: name = "background"
            @unknown default: name = "unknown"
            }
            DiagnosticLog.shared.logVerbose("scenePhase=\(name) mem=\(MemoryFootprint.residentMB())MB")
        }
    }
}
