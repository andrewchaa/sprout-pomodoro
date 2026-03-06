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
                Picker("Timer Duration", selection: $viewModel.timerDurationMinutes) {
                    ForEach(durationOptions, id: \.self) { minutes in
                        Text("\(minutes) minutes").tag(minutes)
                    }
                }
                .pickerStyle(.menu)
            } header: {
                Text("Pomodoro Settings")
            } footer: {
                Text("Changing the duration resets the current timer.")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }
        }
        .formStyle(.grouped)
        .frame(width: 320, height: 150)
        .navigationTitle("Settings")
    }
}

#Preview {
    SettingsView()
        .environmentObject(TimerViewModel())
}
