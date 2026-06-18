//
//  ClimbReflectWatchApp.swift
//  ClimbReflectWatch Watch App
//
//  Created by Björn Dresel on 2026-06-16.
//

import SwiftUI

@main
struct ClimbReflectWatchApp: App {
    @StateObject private var workoutManager = WorkoutManager()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(workoutManager)
                .task {
                    await workoutManager.requestAuthorization()
                    await workoutManager.recoverIfNeeded()
                }
                .onChange(of: scenePhase) { _, newPhase in
                    DiagnosticLog.shared.log("scenePhase=\(newPhase)")
                    // Sofort auf Disk sichern – App kann kurz nach background gekillt werden
                    if newPhase == .background { DiagnosticLog.shared.flush() }
                }
        }
    }
}
