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
        if let dto = workoutManager.pendingSummaryDTO {
            // End-Flow hat Vorrang – unabhängig von isRunning (Blackscreen-Fix)
            SessionEndFlowView(dto: dto)
        } else if workoutManager.isRunning {
            LiveSessionView()
        } else {
            SportSelectionView()
        }
    }
}
