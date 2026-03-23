//
//  ReminderMessageBuilder.swift
//  KeepingUp
//
//  Created by Codex on 3/23/26.
//

import Foundation

struct ReminderMessage {
    let greeting: String
    let primaryMessage: String
    let secondaryMessage: String?
    let notificationBody: String
}

enum ReminderMessageBuilder {
    static func build(for tasks: [StartupTask], now: Date = .now) -> ReminderMessage {
        let greeting = greetingText(for: now)
        let incompleteTasks = TaskScheduling.reminderOrderedIncompleteTasks(from: tasks, now: now)

        guard !tasks.isEmpty else {
            return ReminderMessage(
                greeting: greeting,
                primaryMessage: "You're clear for now.",
                secondaryMessage: "Open the menu bar whenever you want to add the next thing.",
                notificationBody: "\(greeting). You're clear for now."
            )
        }

        if incompleteTasks.isEmpty {
            return ReminderMessage(
                greeting: greeting,
                primaryMessage: "You're all caught up right now.",
                secondaryMessage: "Open the menu bar whenever you want to add the next thing.",
                notificationBody: "\(greeting). You're all caught up right now."
            )
        }

        if incompleteTasks.count == 1, let task = incompleteTasks.first {
            let previewTitle = previewTitle(for: task.title)
            return ReminderMessage(
                greeting: greeting,
                primaryMessage: "Start with \(previewTitle) when you're ready.",
                secondaryMessage: "That's the only open task waiting for you.",
                notificationBody: "\(greeting). Start with \(previewTitle) when you're ready."
            )
        }

        guard let firstTask = incompleteTasks.first else {
            return ReminderMessage(
                greeting: greeting,
                primaryMessage: "Open the menu bar when you're ready.",
                secondaryMessage: nil,
                notificationBody: "\(greeting). Open the menu bar when you're ready."
            )
        }

        let remainingCount = incompleteTasks.count - 1
        let secondaryMessage: String
        if remainingCount == 1 {
            secondaryMessage = "One more task is still waiting in the menu bar."
        } else {
            secondaryMessage = "\(remainingCount) more tasks are still waiting in the menu bar."
        }

        return ReminderMessage(
            greeting: greeting,
            primaryMessage: "Start with \(previewTitle(for: firstTask.title)).",
            secondaryMessage: secondaryMessage,
            notificationBody: "\(greeting). Start with \(previewTitle(for: firstTask.title)). \(secondaryMessage)"
        )
    }

    static func greetingText(for date: Date, calendar: Calendar = .current) -> String {
        let hour = calendar.component(.hour, from: date)

        switch hour {
        case 5..<12:
            return "Good morning"
        case 12..<18:
            return "Good afternoon"
        default:
            return "Good evening"
        }
    }

    private static func previewTitle(for title: String, limit: Int = 80) -> String {
        let collapsedWhitespaceTitle = title
            .components(separatedBy: .newlines)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard collapsedWhitespaceTitle.count > limit else {
            return collapsedWhitespaceTitle
        }

        return String(collapsedWhitespaceTitle.prefix(limit - 1)) + "…"
    }
}
