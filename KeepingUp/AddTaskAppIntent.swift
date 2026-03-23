//
//  AddTaskAppIntent.swift
//  KeepingUp
//
//  Created by Codex on 3/20/26.
//

import AppIntents
import Foundation

struct AddTaskAppIntent: AppIntent {
    static let title: LocalizedStringResource = "Add Task"
    static let description = IntentDescription("Create a new KeepingUp task without opening the app UI.")
    static let openAppWhenRun = false

    @Parameter(
        title: "Task Title",
        description: "The text for the new task."
    )
    var taskTitle: String

    static var parameterSummary: some ParameterSummary {
        Summary("Add \(\.$taskTitle) in KeepingUp")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let newTask = try await MainActor.run {
            let repository = FileTaskRepository()
            return try repository.appendTask(title: taskTitle, postChangeNotification: true)
        }

        return .result(dialog: IntentDialog("Added '\(newTask.title)'"))
    }
}

struct KeepingUpAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AddTaskAppIntent(),
            phrases: [
                "Add task in \(.applicationName)",
                "Create task with \(.applicationName)",
                "New task in \(.applicationName)"
            ],
            shortTitle: "Add Task",
            systemImageName: "plus.circle"
        )
    }
}
