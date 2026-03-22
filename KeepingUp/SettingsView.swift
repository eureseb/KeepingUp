//
//  SettingsView.swift
//  KeepingUp
//
//  Created by Codex on 3/20/26.
//

import AppKit
import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: ChecklistViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Settings")
                    .font(.title2)
                    .fontWeight(.semibold)

                VStack(alignment: .leading, spacing: 10) {
                    Toggle("Launch at login", isOn: Binding(
                        get: { viewModel.launchAtLoginEnabled },
                        set: { viewModel.setLaunchAtLogin($0) }
                    ))

                    Toggle("Remind me on login/unlock", isOn: Binding(
                        get: { viewModel.startupReminderEnabled },
                        set: { viewModel.setStartupReminderEnabled($0) }
                    ))
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Reminder Style")
                        .font(.headline)

                    Picker("Reminder Style", selection: Binding(
                        get: { viewModel.reminderStyle },
                        set: { viewModel.setReminderStyle($0) }
                    )) {
                        ForEach(ReminderPresentationStyle.allCases) { style in
                            Text(style.title).tag(style)
                        }
                    }
                    .pickerStyle(.radioGroup)

                    Text("Popup Window = centered in-app reminder window")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("macOS Notification = standard system notification banner/alert behavior")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Picker("Notification Text Size", selection: $viewModel.notificationTextSize) {
                        ForEach(NotificationTextSize.allCases) { textSize in
                            Text(textSize.title).tag(textSize)
                        }
                    }
                    .pickerStyle(.segmented)

                    Text("This changes the custom popup only.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if viewModel.reminderStyle == .macOSNotification {
                        Button("Open macOS Notification Settings") {
                            openNotificationSettings()
                        }

                        Text("Banner vs alert behavior is controlled by macOS Notification Settings.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if viewModel.notificationPermissionDenied {
                    Text("Notifications are currently denied in System Settings.")
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                Divider()

                VStack(alignment: .leading, spacing: 10) {
                    Toggle("Developer Mode", isOn: $viewModel.developerModeEnabled)

                    if viewModel.developerModeEnabled {
                        Toggle("Disable reminder cooldown", isOn: $viewModel.reminderCooldownDisabled)

                        Stepper(
                            "Reminder cooldown: \(viewModel.reminderCooldownMinutes) min",
                            value: $viewModel.reminderCooldownMinutes,
                            in: 1...1440,
                            step: 5
                        )
                        .disabled(viewModel.reminderCooldownDisabled)

                        Stepper(
                            "Popup auto-dismiss: \(viewModel.popupAutoDismissSeconds) sec",
                            value: $viewModel.popupAutoDismissSeconds,
                            in: 0...300,
                            step: 1
                        )

                        Text("0 means the popup stays visible until you dismiss it.")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text("Developer settings change how often login/unlock reminders can appear.")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Button("Test Current Reminder Style") {
                            viewModel.testCurrentReminderStyle()
                        }
                    }
                }

                Divider()

                HStack {
                    Spacer()

                    Button("Quit KeepingUp") {
                        // Closing a secondary window is not the same as quitting the app.
                        // Terminate exits the whole menu bar app from the Settings window.
                        NSApplication.shared.terminate(nil)
                    }
                    .keyboardShortcut("q")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
        }
        .background(SettingsWindowConfigurator())
    }

    private func openNotificationSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.notifications") else {
            return
        }
        NSWorkspace.shared.open(url)
    }
}

private struct SettingsWindowConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()

        DispatchQueue.main.async {
            guard let window = view.window else { return }
            window.styleMask.insert(.resizable)
            window.minSize = NSSize(width: 320, height: 320)
        }

        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            guard let window = nsView.window else { return }
            window.styleMask.insert(.resizable)
            window.minSize = NSSize(width: 320, height: 320)
        }
    }
}
