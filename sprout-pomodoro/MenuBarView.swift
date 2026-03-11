//
//  MenuBarView.swift
//  sprout-pomodoro
//

import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var viewModel: TimerViewModel
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        VStack(spacing: 16) {
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

            Divider()

            HStack {
                Button {
                    openSettings()
                } label: {
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
        }
        .padding(20)
        .frame(width: 260)
    }
}
