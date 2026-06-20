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
        }
        .onChange(of: scenePhase) { _, phase in
            let name: String
            switch phase {
            case .active:     name = "active"
            case .inactive:   name = "inactive"
            case .background: name = "background"
            @unknown default: name = "unknown"
            }
            DiagnosticLog.shared.log("scenePhase=\(name) mem=\(MemoryFootprint.residentMB())MB",
                                     flushImmediately: phase == .background)
        }
    }
}
