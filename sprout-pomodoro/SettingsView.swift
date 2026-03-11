//
//  SettingsView.swift
//  sprout-pomodoro
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var viewModel: TimerViewModel

    private let durationOptions = [5, 10, 15, 20, 25, 30, 45, 60]

    var body: some View {
        Form {
            Section {
                Picker("Focus Duration", selection: $viewModel.timerDurationMinutes) {
                    ForEach(durationOptions, id: \.self) { minutes in
                        Text("\(minutes) minutes").tag(minutes)
                    }
                }
                .pickerStyle(.menu)

                Picker("Break Duration", selection: $viewModel.breakDurationMinutes) {
                    ForEach(durationOptions, id: \.self) { minutes in
                        Text("\(minutes) minutes").tag(minutes)
                    }
                }
                .pickerStyle(.menu)
            } header: {
                Text("Pomodoro Settings")
            } footer: {
                Text("Changing focus duration resets the focus timer. Changing break duration resets the break timer.")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }
        }
        .formStyle(.grouped)
        .frame(width: 320, height: 220)
        .navigationTitle("Settings")
    }
}

#Preview {
    SettingsView()
        .environmentObject(TimerViewModel())
}
