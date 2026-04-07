//
//  MenuBarView.swift
//  sprout-pomodoro
//

import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var viewModel: TimerViewModel
    @EnvironmentObject var updateChecker: UpdateChecker
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(spacing: 16) {
            if let update = updateChecker.availableUpdate {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.down.circle.fill")
                        .foregroundStyle(.blue)
                    Text("v\(update.version) available")
                        .font(.caption)
                        .foregroundStyle(.blue)
                    Spacer()
                    Button("Update") {
                        updateChecker.availableUpdate = nil
                        openURL(update.url)
                    }
                    .controlSize(.small)
                    .buttonStyle(.borderedProminent)
                    Button("Later") {
                        updateChecker.availableUpdate = nil
                    }
                    .controlSize(.small)
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                }
                Divider()
            }
            Text(viewModel.mode == .focus ? "Focus" : "Break")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(viewModel.mode == .focus ? Color.orange : Color.green)
                .textCase(.uppercase)
                .tracking(0.5)

            Text(viewModel.formattedTime)
                .font(.system(size: 48, weight: .thin, design: .monospaced))
                .monospacedDigit()

            ProgressView(
                value: Double(viewModel.durationSeconds - viewModel.remainingSeconds),
                total: Double(viewModel.durationSeconds)
            )
            .progressViewStyle(.linear)
            .tint(
                viewModel.isRunning
                    ? (viewModel.mode == .focus ? .orange : .green)
                    : .secondary
            )

            HStack(spacing: 16) {
                Button(action: viewModel.reset) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.title2)
                }
                .buttonStyle(.plain)
                .help("Reset")

                if viewModel.isRunning {
                    Button(action: viewModel.pause) {
                        Image(systemName: "pause.circle.fill")
                            .font(.system(size: 44))
                            .foregroundStyle(viewModel.mode == .focus ? Color.orange : Color.green)
                    }
                    .buttonStyle(.plain)
                    .help("Pause")
                } else {
                    Button(action: viewModel.start) {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 44))
                            .foregroundStyle(.green)
                    }
                    .buttonStyle(.plain)
                    .help("Start")
                }

                Color.clear
                    .frame(width: 24, height: 24)
            }

            if viewModel.mode == .focus && !viewModel.isRunning {
                Button("Skip to Break") {
                    viewModel.skipToBreak()
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .buttonStyle(.plain)
            }

            if viewModel.mode == .breakTime && !viewModel.isRunning {
                Button("Skip Break") {
                    viewModel.skipToFocus()
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .buttonStyle(.plain)
            }

            Divider()

            HStack {
                SettingsLink {
                    Label("Settings", systemImage: "gear")
                        .font(.callout)
                }
                .buttonStyle(.plain)

                Spacer()

                Button("Quit") {
                    NSApp.terminate(nil)
                }
                .font(.callout)
            }

            Divider()

            HStack {
                Text("🍅 \(viewModel.dailyFocusSessions) sessions")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(viewModel.formattedDailyTime)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(20)
        .frame(width: 260)
        .onAppear {
            viewModel.setupIfNeeded(context: modelContext) { completedMode in
                switch completedMode {
                case .focus:
                    NotificationManager.shared.sendFocusFinishedNotification()
                case .breakTime:
                    NotificationManager.shared.sendBreakFinishedNotification()
                }
            }
            viewModel.refreshTodaySessions()
            updateChecker.startPeriodicChecks()
        }
    }
}
