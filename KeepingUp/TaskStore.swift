//
//  TaskStore.swift
//  KeepingUp
//
//  Created by Codex on 3/20/26.
//

import Foundation

enum TaskStoreError: LocalizedError {
    case blankTitle

    var errorDescription: String? {
        switch self {
        case .blankTitle:
            return "Task title cannot be blank."
        }
    }
}

enum TaskStore {
    static let tasksStorageKey = "startupTasks"
    static let tasksDidChangeNotificationName = Notification.Name("eureseb.KeepingUp.tasksDidChange")

    static func loadTasks(from defaults: UserDefaults = .standard) -> [StartupTask] {
        guard let data = defaults.data(forKey: tasksStorageKey) else {
            return StartupTask.sampleData
        }

        do {
            return try JSONDecoder().decode([StartupTask].self, from: data)
        } catch {
            return StartupTask.sampleData
        }
    }

    static func saveTasks(
        _ tasks: [StartupTask],
        to defaults: UserDefaults = .standard,
        postChangeNotification: Bool
    ) throws {
        let data = try JSONEncoder().encode(tasks)
        defaults.set(data, forKey: tasksStorageKey)

        guard postChangeNotification else { return }

        DistributedNotificationCenter.default().postNotificationName(
            tasksDidChangeNotificationName,
            object: nil,
            userInfo: nil,
            deliverImmediately: true
        )
    }

    static func validateTitle(_ rawTitle: String) throws -> String {
        let trimmedTitle = rawTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else {
            throw TaskStoreError.blankTitle
        }

        return trimmedTitle
    }

    @discardableResult
    static func appendTask(
        title rawTitle: String,
        defaults: UserDefaults = .standard,
        postChangeNotification: Bool = true
    ) throws -> StartupTask {
        let title = try validateTitle(rawTitle)
        let newTask = StartupTask(title: title)
        var tasks = loadTasks(from: defaults)
        tasks.append(newTask)
        try saveTasks(tasks, to: defaults, postChangeNotification: postChangeNotification)
        return newTask
    }
}
