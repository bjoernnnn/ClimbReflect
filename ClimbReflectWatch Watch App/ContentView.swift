//
//  ContentView.swift
//  ClimbReflectWatch Watch App
//
//  Created by Björn Dresel on 2026-06-16.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var workoutManager: WorkoutManager

    var body: some View {
        if workoutManager.isRunning {
            LiveSessionView()
        } else {
            SportSelectionView()
        }
    }
}
