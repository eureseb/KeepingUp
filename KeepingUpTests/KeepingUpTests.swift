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
        let context = makeRepositoryContext(name: #function)

        let viewModel = ChecklistViewModel(
            defaults: context.defaults,
            taskRepository: context.repository
        )
        viewModel.newTaskTitle = "  Brew coffee  "
        viewModel.addTask()

        #expect(viewModel.tasks.first?.title == "Brew coffee")
        #expect(try context.repository.loadTasks().first?.title == "Brew coffee")
    }


    @Test func freshLaunchStartsWithNoTasks() throws {
        let context = makeRepositoryContext(name: #function)

        let viewModel = ChecklistViewModel(
            defaults: context.defaults,
            taskRepository: context.repository
        )

        #expect(viewModel.tasks.isEmpty)
    }

    @Test func tasksPersistBetweenLaunches() throws {
        let context = makeRepositoryContext(name: #function)

        let viewModel = ChecklistViewModel(
            defaults: context.defaults,
            taskRepository: context.repository
        )
        viewModel.newTaskTitle = "Open standup notes"
        viewModel.addTask()

        guard let storedTask = viewModel.tasks.first else {
            Issue.record("Failed to append task")
            return
        }
        viewModel.toggleCompletion(for: storedTask)

        let rehydratedViewModel = ChecklistViewModel(
            defaults: context.defaults,
            taskRepository: FileTaskRepository(defaults: context.defaults, storeURL: context.storeURL)
        )
        #expect(rehydratedViewModel.tasks.first?.isComplete == true)
    }

    @Test func repositoryMigratesLegacyDefaultsPayload() throws {
        let context = makeRepositoryContext(name: #function)
        let legacyTasks = [
            StartupTask(
                title: "Legacy task",
                isComplete: true,
                createdAt: fixedDate(hour: 8)
            )
        ]
        let legacyData = try JSONEncoder().encode(legacyTasks)
        context.defaults.set(legacyData, forKey: TaskStore.legacyTasksStorageKey)

        let loadedTasks = try context.repository.loadTasks()

        #expect(loadedTasks.count == 1)
        #expect(loadedTasks.first?.title == "Legacy task")
        #expect(loadedTasks.first?.priority == .normal)
        #expect(loadedTasks.first?.updatedAt == loadedTasks.first?.createdAt)
        #expect(context.defaults.data(forKey: TaskStore.legacyTasksStorageKey) == nil)
        #expect(FileManager.default.fileExists(atPath: context.storeURL.path))
    }

    @Test func repositoryCRUDPersistsTaskChanges() throws {
        let context = makeRepositoryContext(name: #function)

        let firstTask = try context.repository.appendTask(title: "First task", postChangeNotification: false)
        let secondTask = try context.repository.appendTask(title: "Second task", postChangeNotification: false)

        var tasks = try context.repository.loadTasks()
        #expect(tasks.map(\.title) == ["First task", "Second task"])

        guard let firstIndex = tasks.firstIndex(where: { $0.id == firstTask.id }) else {
            Issue.record("Failed to find the first task")
            return
        }

        tasks[firstIndex].isComplete = true
        tasks[firstIndex].updatedAt = fixedDate(hour: 10)
        tasks.swapAt(0, 1)
        tasks.removeAll { $0.id == secondTask.id }

        try context.repository.saveTasks(tasks, postChangeNotification: false)

        let reloadedTasks = try context.repository.loadTasks()
        #expect(reloadedTasks.count == 1)
        #expect(reloadedTasks.first?.id == firstTask.id)
        #expect(reloadedTasks.first?.isComplete == true)
        #expect(reloadedTasks.first?.updatedAt == fixedDate(hour: 10))
    }

    @Test func legacyPayloadDecodingAppliesNewFieldDefaults() throws {
        let legacyTaskID = UUID()
        let createdAt = fixedDate(hour: 7)
        let payload = """
        [{
          "id":"\(legacyTaskID.uuidString)",
          "title":"Legacy decoded task",
          "isComplete":false,
          "createdAt":\(createdAt.timeIntervalSince1970)
        }]
        """

        let decodedTasks = try JSONDecoder().decode([StartupTask].self, from: Data(payload.utf8))

        #expect(decodedTasks.count == 1)
        #expect(decodedTasks.first?.priority == .normal)
        #expect(decodedTasks.first?.dueDate == nil)
        #expect(decodedTasks.first?.parserMetadata == nil)
        #expect(decodedTasks.first?.updatedAt == createdAt)
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

    @Test func reminderMessageHandlesEmptyTaskList() {
        let message = ReminderMessageBuilder.build(
            for: [],
            now: fixedDate(hour: 10)
        )

        #expect(message.greeting == "Good morning")
        #expect(message.primaryMessage == "You're clear for now.")
        #expect(message.secondaryMessage == "Open the menu bar whenever you want to add the next thing.")
    }

    @Test func reminderGreetingTransitionsAtExpectedHours() {
        #expect(ReminderMessageBuilder.greetingText(for: fixedDate(hour: 4)) == "Good evening")
        #expect(ReminderMessageBuilder.greetingText(for: fixedDate(hour: 5)) == "Good morning")
        #expect(ReminderMessageBuilder.greetingText(for: fixedDate(hour: 11)) == "Good morning")
        #expect(ReminderMessageBuilder.greetingText(for: fixedDate(hour: 12)) == "Good afternoon")
        #expect(ReminderMessageBuilder.greetingText(for: fixedDate(hour: 17)) == "Good afternoon")
        #expect(ReminderMessageBuilder.greetingText(for: fixedDate(hour: 18)) == "Good evening")
    }

    @Test func reminderMessageNormalizesLongMultilineTitlesForPreviewSurfaces() {
        let longTitle = "Reply to Sir John\nwith the updated draft and follow-up notes for tomorrow's planning sync before lunch"
        let message = ReminderMessageBuilder.build(
            for: [StartupTask(title: longTitle)],
            now: fixedDate(hour: 9)
        )

        #expect(!message.primaryMessage.contains("\n"))
        #expect(!message.notificationBody.contains("\n"))
        #expect(message.primaryMessage.contains("…"))
        #expect(message.notificationBody.contains("…"))
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

    private func makeRepositoryContext(name: String) -> RepositoryContext {
        let suiteName = "KeepingUpTests.\(name)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            Issue.record("Unable to create UserDefaults suite")
            fatalError("Unable to create UserDefaults suite")
        }

        defaults.removePersistentDomain(forName: suiteName)

        let sanitizedName = name.replacingOccurrences(of: "[^A-Za-z0-9_-]", with: "-", options: .regularExpression)
        let rootDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("KeepingUpTests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString + "-" + sanitizedName, isDirectory: true)
        let storeURL = rootDirectory.appendingPathComponent("tasks.json", isDirectory: false)
        try? FileManager.default.removeItem(at: rootDirectory)

        let repository = FileTaskRepository(defaults: defaults, storeURL: storeURL)
        return RepositoryContext(defaults: defaults, repository: repository, storeURL: storeURL)
    }
}

private struct RepositoryContext {
    let defaults: UserDefaults
    let repository: FileTaskRepository
    let storeURL: URL
}
