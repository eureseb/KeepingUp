//
//  KeepingUpTests.swift
//  KeepingUpTests
//
//  Created by EureseB on 3/20/26.
//

import Foundation
import Testing
@testable import KeepingUp

@MainActor
struct KeepingUpTests {

    @Test func addTaskTrimsWhitespace() throws {
        let suiteName = "ChecklistViewModelTests"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            Issue.record("Unable to create UserDefaults suite")
            return
        }
        defaults.removePersistentDomain(forName: suiteName)

        let viewModel = ChecklistViewModel(defaults: defaults)
        viewModel.tasks = []
        viewModel.newTaskTitle = "  Brew coffee  "
        viewModel.addTask()

        #expect(viewModel.tasks.first?.title == "Brew coffee")
    }


    @Test func freshLaunchStartsWithNoTasks() throws {
        let suiteName = "ChecklistViewModelEmptyStateTests"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            Issue.record("Unable to create UserDefaults suite")
            return
        }
        defaults.removePersistentDomain(forName: suiteName)

        let viewModel = ChecklistViewModel(defaults: defaults)

        #expect(viewModel.tasks.isEmpty)
    }

    @Test func tasksPersistBetweenLaunches() throws {
        let suiteName = "ChecklistViewModelPersistenceTests"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            Issue.record("Unable to create UserDefaults suite")
            return
        }
        defaults.removePersistentDomain(forName: suiteName)

        let viewModel = ChecklistViewModel(defaults: defaults)
        viewModel.tasks = [StartupTask(title: "Open standup notes")]
        guard let storedTask = viewModel.tasks.first else {
            Issue.record("Failed to append task")
            return
        }
        viewModel.toggleCompletion(for: storedTask)

        let rehydratedViewModel = ChecklistViewModel(defaults: defaults)
        #expect(rehydratedViewModel.tasks.first?.isComplete == true)
    }

    @Test func reminderMessageUsesMorningGreetingForSingleOpenTask() {
        let message = ReminderMessageBuilder.build(
            for: [StartupTask(title: "Reply to Sir John")],
            now: fixedDate(hour: 9)
        )

        #expect(message.greeting == "Good morning")
        #expect(message.primaryMessage.contains("Reply to Sir John"))
        #expect(message.secondaryMessage == "That's the only open task waiting for you.")
    }

    @Test func reminderMessageSummarizesAdditionalTasks() {
        let message = ReminderMessageBuilder.build(
            for: [
                StartupTask(title: "First task"),
                StartupTask(title: "Second task"),
                StartupTask(title: "Third task")
            ],
            now: fixedDate(hour: 14)
        )

        #expect(message.greeting == "Good afternoon")
        #expect(message.primaryMessage == "Start with First task.")
        #expect(message.secondaryMessage == "2 more tasks are still waiting in the menu bar.")
    }

    @Test func reminderMessageAcknowledgesAllClearState() {
        let message = ReminderMessageBuilder.build(
            for: [StartupTask(title: "Wrapped up", isComplete: true)],
            now: fixedDate(hour: 20)
        )

        #expect(message.greeting == "Good evening")
        #expect(message.primaryMessage == "You're all caught up right now.")
    }

    private func fixedDate(hour: Int) -> Date {
        var components = DateComponents()
        components.year = 2026
        components.month = 3
        components.day = 23
        components.hour = hour
        components.minute = 0
        return Calendar(identifier: .gregorian).date(from: components) ?? .now
    }
}
