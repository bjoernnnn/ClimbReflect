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

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(workoutManager)
                .task { await workoutManager.requestAuthorization() }
        }
    }
}
