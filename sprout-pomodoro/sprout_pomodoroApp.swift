//
//  sprout_pomodoroApp.swift
//  sprout-pomodoro
//
//  Created by Youngho Chaa on 06/03/2026.
//

import SwiftUI

@main
struct SproutPomodoroApp: App {
    @StateObject private var timerViewModel = TimerViewModel()

    init() {
        DispatchQueue.main.async {
            NSApp?.applicationIconImage = NSImage(named: "AppIcon")
        }
        NotificationManager.shared.requestPermission()
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
                .environmentObject(timerViewModel)
                .onAppear {
                    timerViewModel.onFinish = { completedMode in
                        switch completedMode {
                        case .focus:
                            NotificationManager.shared.sendFocusFinishedNotification()
                        case .breakTime:
                            NotificationManager.shared.sendBreakFinishedNotification()
                        }
                    }
                }
        } label: {
            RenderedMenuBarLabel(viewModel: timerViewModel)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environmentObject(timerViewModel)
        }
    }
}
