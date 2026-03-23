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
    static let legacyTasksStorageKey = "startupTasks"
    static let tasksDidChangeNotificationName = Notification.Name("eureseb.KeepingUp.tasksDidChange")
    static let changeSourceIdentifierUserInfoKey = "sourceIdentifier"

    static func validateTitle(_ rawTitle: String) throws -> String {
        let trimmedTitle = rawTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else {
            throw TaskStoreError.blankTitle
        }

        return trimmedTitle
    }
}
