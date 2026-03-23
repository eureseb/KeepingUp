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
            let uiTestStoreURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("KeepingUpUITests", isDirectory: true)
                .appendingPathComponent("tasks.json", isDirectory: false)
            try? FileManager.default.removeItem(at: uiTestStoreURL.deletingLastPathComponent())

            resolvedViewModel = ChecklistViewModel(
                defaults: defaults,
                taskRepository: FileTaskRepository(defaults: defaults, storeURL: uiTestStoreURL)
            )
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
