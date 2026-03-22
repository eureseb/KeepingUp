//
//  KeepingUpApp.swift
//  KeepingUp
//
//  Created by EureseB on 3/20/26.
//

import SwiftUI
import Foundation
import AppIntents

@main
struct KeepingUpApp: App {
    private let viewModel: ChecklistViewModel
    private let lifecycleObserver: AppLifecycleObserver
    private let isUITesting: Bool

    init() {
        isUITesting = CommandLine.arguments.contains("--uitesting")
        let resolvedViewModel: ChecklistViewModel

        if isUITesting,
           let defaults = UserDefaults(suiteName: "KeepingUpUITests") {
            defaults.removePersistentDomain(forName: "KeepingUpUITests")
            if let emptyData = try? JSONEncoder().encode([StartupTask]()) {
                defaults.set(emptyData, forKey: "startupTasks")
            }
            resolvedViewModel = ChecklistViewModel(defaults: defaults)
        } else {
            resolvedViewModel = ChecklistViewModel()
        }

        viewModel = resolvedViewModel
        KeepingUpAppShortcuts.updateAppShortcutParameters()
        lifecycleObserver = AppLifecycleObserver { reason in
            Task { @MainActor in
                await resolvedViewModel.handleReminderTrigger(reason: reason)
            }
        }
        lifecycleObserver.start()
    }

    var body: some Scene {
        MenuBarExtra("KeepingUp", systemImage: "checklist") {
            ContentView(viewModel: viewModel)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(viewModel: viewModel)
        }
    }
}
