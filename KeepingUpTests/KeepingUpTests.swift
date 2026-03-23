//
//  KeepingUpTests.swift
//  KeepingUpTests
//
//  Created by EureseB on 3/20/26.
//

import Foundation
import Testing
import UserNotifications
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

    @Test func renameTaskPersistsValidatedTitle() throws {
        let context = makeRepositoryContext(name: #function)
        let viewModel = ChecklistViewModel(
            defaults: context.defaults,
            taskRepository: context.repository
        )
        viewModel.newTaskTitle = "Original title"
        viewModel.addTask()

        guard let task = viewModel.tasks.first else {
            Issue.record("Failed to create task for rename test")
            return
        }

        #expect(viewModel.renameTask(taskID: task.id, to: "  Updated title  ") == true)
        #expect(viewModel.tasks.first?.title == "Updated title")
        #expect(try context.repository.loadTasks().first?.title == "Updated title")
    }

    @Test func bulkRemoveDeletesSelectedTasksAndPersists() throws {
        let context = makeRepositoryContext(name: #function)
        let viewModel = ChecklistViewModel(
            defaults: context.defaults,
            taskRepository: context.repository
        )

        viewModel.newTaskTitle = "Alpha"
        viewModel.addTask()
        viewModel.newTaskTitle = "Bravo"
        viewModel.addTask()
        viewModel.newTaskTitle = "Charlie"
        viewModel.addTask()

        let removableIDs = Set(viewModel.tasks.prefix(2).map(\.id))
        viewModel.removeTasks(withIDs: removableIDs)

        #expect(viewModel.tasks.map(\.title) == ["Charlie"])
        #expect(try context.repository.loadTasks().map(\.title) == ["Charlie"])
    }

    @Test func dailyCleanupRemovesOnlyCompletedTasksOlderThan24Hours() throws {
        let context = makeRepositoryContext(name: #function)
        let now = fixedDate(day: 23, hour: 12)

        let tasks = [
            StartupTask(
                title: "Old completed",
                isComplete: true,
                createdAt: fixedDate(day: 21, hour: 9),
                updatedAt: fixedDate(day: 22, hour: 10)
            ),
            StartupTask(
                title: "Recent completed",
                isComplete: true,
                createdAt: fixedDate(day: 23, hour: 10),
                updatedAt: fixedDate(day: 23, hour: 11)
            ),
            StartupTask(
                title: "Still open",
                isComplete: false,
                createdAt: fixedDate(day: 22, hour: 8),
                updatedAt: fixedDate(day: 22, hour: 8)
            )
        ]
        try context.repository.saveTasks(tasks, postChangeNotification: false)

        let viewModel = ChecklistViewModel(
            defaults: context.defaults,
            taskRepository: FileTaskRepository(defaults: context.defaults, storeURL: context.storeURL)
        )
        viewModel.autoDeleteCompletedEnabled = true
        viewModel.performDailyCompletedCleanupIfNeeded(now: now)

        #expect(viewModel.tasks.map(\.title).sorted() == ["Recent completed", "Still open"])
        #expect(try context.repository.loadTasks().map(\.title).sorted() == ["Recent completed", "Still open"])
    }

    @Test func dailyCleanupDoesNothingWhenAutoDeleteIsDisabled() throws {
        let context = makeRepositoryContext(name: #function)
        let tasks = [
            StartupTask(
                title: "Old completed",
                isComplete: true,
                createdAt: fixedDate(day: 21, hour: 9),
                updatedAt: fixedDate(day: 22, hour: 8)
            )
        ]
        try context.repository.saveTasks(tasks, postChangeNotification: false)

        let viewModel = ChecklistViewModel(
            defaults: context.defaults,
            taskRepository: FileTaskRepository(defaults: context.defaults, storeURL: context.storeURL)
        )
        viewModel.autoDeleteCompletedEnabled = false
        viewModel.performDailyCompletedCleanupIfNeeded(now: fixedDate(day: 23, hour: 12))

        #expect(viewModel.tasks.map(\.title) == ["Old completed"])
    }

    @Test func dailyCleanupRunsAtMostOncePerDay() throws {
        let context = makeRepositoryContext(name: #function)
        let initialTasks = [
            StartupTask(
                title: "First old done",
                isComplete: true,
                createdAt: fixedDate(day: 20, hour: 9),
                updatedAt: fixedDate(day: 21, hour: 8)
            ),
            StartupTask(
                title: "Open task",
                isComplete: false,
                createdAt: fixedDate(day: 23, hour: 9),
                updatedAt: fixedDate(day: 23, hour: 9)
            )
        ]
        try context.repository.saveTasks(initialTasks, postChangeNotification: false)

        let viewModel = ChecklistViewModel(
            defaults: context.defaults,
            taskRepository: FileTaskRepository(defaults: context.defaults, storeURL: context.storeURL)
        )
        viewModel.autoDeleteCompletedEnabled = true
        viewModel.performDailyCompletedCleanupIfNeeded(now: fixedDate(day: 23, hour: 10))

        viewModel.tasks.append(
            StartupTask(
                title: "Second old done",
                isComplete: true,
                createdAt: fixedDate(day: 20, hour: 10),
                updatedAt: fixedDate(day: 21, hour: 9)
            )
        )

        viewModel.performDailyCompletedCleanupIfNeeded(now: fixedDate(day: 23, hour: 18))
        #expect(viewModel.tasks.map(\.title).contains("Second old done"))

        viewModel.performDailyCompletedCleanupIfNeeded(now: fixedDate(day: 24, hour: 9))
        #expect(!viewModel.tasks.map(\.title).contains("Second old done"))
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
        #expect(loadedTasks.first?.priority == .medium)
        #expect(loadedTasks.first?.updatedAt == loadedTasks.first?.createdAt)
        #expect(loadedTasks.first?.isPinned == false)
        #expect(loadedTasks.first?.pinnedOrder == nil)
        #expect(loadedTasks.first?.manualOrderGroupID == nil)
        #expect(loadedTasks.first?.manualOrder == nil)
        #expect(loadedTasks.first?.hasExplicitDueTime == false)
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
        tasks[firstIndex].dueDate = fixedDate(day: 24, hour: 15)
        tasks[firstIndex].priority = .high
        tasks[firstIndex].isPinned = true
        tasks[firstIndex].pinnedOrder = 0
        tasks[firstIndex].hasExplicitDueTime = true
        tasks.swapAt(0, 1)
        tasks.removeAll { $0.id == secondTask.id }

        try context.repository.saveTasks(tasks, postChangeNotification: false)

        let reloadedTasks = try context.repository.loadTasks()
        #expect(reloadedTasks.count == 1)
        #expect(reloadedTasks.first?.id == firstTask.id)
        #expect(reloadedTasks.first?.isComplete == true)
        #expect(reloadedTasks.first?.updatedAt == fixedDate(hour: 10))
        #expect(reloadedTasks.first?.priority == .high)
        #expect(reloadedTasks.first?.isPinned == true)
        #expect(reloadedTasks.first?.pinnedOrder == 0)
        #expect(reloadedTasks.first?.manualOrderGroupID == nil)
        #expect(reloadedTasks.first?.manualOrder == nil)
        #expect(reloadedTasks.first?.hasExplicitDueTime == true)
    }

    @Test func legacyPayloadDecodingAppliesNewFieldDefaults() throws {
        let legacyTaskID = UUID()
        let createdAt = fixedDate(hour: 7)
        let payload = """
        [{
          "id":"\(legacyTaskID.uuidString)",
          "title":"Legacy decoded task",
          "isComplete":false,
          "createdAt":\(createdAt.timeIntervalSinceReferenceDate)
        }]
        """

        let decodedTasks = try JSONDecoder().decode([StartupTask].self, from: Data(payload.utf8))

        #expect(decodedTasks.count == 1)
        #expect(decodedTasks.first?.priority == .medium)
        #expect(decodedTasks.first?.dueDate == nil)
        #expect(decodedTasks.first?.parserMetadata == nil)
        #expect(decodedTasks.first?.updatedAt == createdAt)
        #expect(decodedTasks.first?.isPinned == false)
        #expect(decodedTasks.first?.pinnedOrder == nil)
        #expect(decodedTasks.first?.manualOrderGroupID == nil)
        #expect(decodedTasks.first?.manualOrder == nil)
        #expect(decodedTasks.first?.hasExplicitDueTime == false)
    }

    @Test func legacyNormalPriorityDecodesAsMedium() throws {
        let payload = """
        [{
          "id":"\(UUID().uuidString)",
          "title":"Priority migration",
          "isComplete":false,
          "createdAt":\(fixedDate(hour: 8).timeIntervalSinceReferenceDate),
          "priority":"normal"
        }]
        """

        let decodedTasks = try JSONDecoder().decode([StartupTask].self, from: Data(payload.utf8))

        #expect(decodedTasks.first?.priority == .medium)
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

    @Test func reminderMessageUsesHighestRankedTaskInsteadOfStoredOrder() {
        let message = ReminderMessageBuilder.build(
            for: [
                StartupTask(
                    title: "Backlog cleanup",
                    manualOrderGroupID: TaskSectionKind.unplanned.rawValue,
                    manualOrder: 2
                ),
                StartupTask(
                    title: "Send launch update",
                    manualOrderGroupID: TaskSectionKind.unplanned.rawValue,
                    manualOrder: 0
                ),
                StartupTask(
                    title: "Medium task",
                    manualOrderGroupID: TaskSectionKind.unplanned.rawValue,
                    manualOrder: 1
                )
            ],
            now: fixedDate(hour: 9, minute: 30)
        )

        #expect(message.primaryMessage == "Start with Send launch update.")
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

    @Test func taskSchedulingRanksOverdueBeforeNearDueBeforeFutureBeforeUnplanned() {
        let now = fixedDate(hour: 9)
        let rankedTitles = TaskScheduling.rankedIncompleteTasks(
            from: [
                StartupTask(title: "Unplanned"),
                StartupTask(
                    title: "Future",
                    dueDate: fixedDate(hour: 14),
                    priority: .high,
                    hasExplicitDueTime: true
                ),
                StartupTask(
                    title: "Near due",
                    dueDate: fixedDate(hour: 9, minute: 45),
                    priority: .low,
                    hasExplicitDueTime: true
                ),
                StartupTask(
                    title: "Overdue",
                    dueDate: fixedDate(hour: 8, minute: 30),
                    priority: .low,
                    hasExplicitDueTime: true
                )
            ],
            now: now
        )
        .map(\.title)

        #expect(rankedTitles == ["Overdue", "Near due", "Future", "Unplanned"])
    }

    @Test func taskSchedulingDoesNotUsePriorityAsTieBreakerInsideSameUrgencyBucket() {
        let rankedTitles = TaskScheduling.rankedIncompleteTasks(
            from: [
                StartupTask(title: "First", createdAt: fixedDate(hour: 9, minute: 1), priority: .low),
                StartupTask(title: "Second", createdAt: fixedDate(hour: 9, minute: 2), priority: .high),
                StartupTask(title: "Third", createdAt: fixedDate(hour: 9, minute: 3), priority: .medium)
            ],
            now: fixedDate(hour: 9)
        )
        .map(\.title)

        #expect(rankedTitles == ["First", "Second", "Third"])
    }

    @Test func todayAndUpcomingFiltersSplitDeadlineBucketsWhileKeepingUnplannedAccessible() {
        let tasks = [
            StartupTask(title: "Pinned future", dueDate: fixedDate(hour: 14), priority: .high, isPinned: true, pinnedOrder: 0, hasExplicitDueTime: true),
            StartupTask(title: "Today task", dueDate: fixedDate(hour: 11), hasExplicitDueTime: true),
            StartupTask(title: "Tomorrow task", dueDate: fixedDate(day: 24, hour: 11), hasExplicitDueTime: true),
            StartupTask(title: "Unplanned"),
            StartupTask(title: "Done", isComplete: true)
        ]

        let todaySections = TaskScheduling.browseSections(
            for: tasks,
            filter: .today,
            now: fixedDate(hour: 10)
        )
        let upcomingSections = TaskScheduling.browseSections(
            for: tasks,
            filter: .upcoming,
            now: fixedDate(hour: 10)
        )

        #expect(todaySections.first?.tasks.map(\.title) == ["Pinned future"])
        #expect(todaySections.first(where: { $0.id == .today })?.tasks.map(\.title) == ["Today task"])
        #expect(todaySections.first(where: { $0.id == .unplanned })?.tasks.map(\.title) == ["Unplanned"])
        #expect(upcomingSections.first(where: { $0.id == .upcoming })?.tasks.map(\.title) == ["Tomorrow task"])
    }

    @Test func focusSectionsShowOnlyTodayRelevantTasks() {
        let sections = TaskScheduling.focusSections(
            for: [
                StartupTask(title: "Overdue", dueDate: fixedDate(hour: 8), hasExplicitDueTime: true),
                StartupTask(title: "Today", dueDate: fixedDate(hour: 11), hasExplicitDueTime: true),
                StartupTask(title: "Tomorrow", dueDate: fixedDate(day: 24, hour: 11), hasExplicitDueTime: true),
                StartupTask(title: "Unplanned"),
                StartupTask(title: "Done", isComplete: true)
            ],
            now: fixedDate(hour: 10)
        )

        #expect(sections.map(\.id) == [.overdue, .today])
        #expect(sections.flatMap(\.tasks).map(\.title) == ["Overdue", "Today"])
        #expect(sections.allSatisfy { $0.allowsManualReorder == false })
    }

    @Test func appDidBecomeActiveDoesNotTriggerReminderDelivery() {
        #expect(ReminderReason.appDidBecomeActive.shouldTriggerStartupReminder == false)
        #expect(ReminderReason.appLaunch.shouldTriggerStartupReminder == true)
    }

    @Test func switchingToUpcomingFallsBackToBrowseMode() {
        let context = makeRepositoryContext(name: #function)
        let viewModel = ChecklistViewModel(
            defaults: context.defaults,
            taskRepository: context.repository
        )

        viewModel.setTaskPresentationMode(.focus)
        #expect(viewModel.taskPresentationMode == .focus)

        viewModel.setTaskFocusFilter(.upcoming)

        #expect(viewModel.taskFocusFilter == .upcoming)
        #expect(viewModel.taskPresentationMode == .browse)
        #expect(viewModel.isFocusModeAvailable == false)
    }

    @Test func resetPopoverFilterToDefaultSetsToday() {
        let context = makeRepositoryContext(name: #function)
        let viewModel = ChecklistViewModel(
            defaults: context.defaults,
            taskRepository: context.repository
        )

        viewModel.setTaskFocusFilter(.upcoming)
        #expect(viewModel.taskFocusFilter == .upcoming)

        viewModel.resetPopoverFilterToDefault()

        #expect(viewModel.taskFocusFilter == .today)
    }

    @Test func upcomingQuickFilterTogglesBetweenTodayAndUpcoming() {
        let context = makeRepositoryContext(name: #function)
        let viewModel = ChecklistViewModel(
            defaults: context.defaults,
            taskRepository: context.repository
        )

        #expect(viewModel.taskFocusFilter == .today)

        viewModel.toggleUpcomingQuickFilter()
        #expect(viewModel.taskFocusFilter == .upcoming)

        viewModel.toggleUpcomingQuickFilter()
        #expect(viewModel.taskFocusFilter == .today)
    }

    @Test func upcomingQuickFilterExitsFocusModeWhenSwitchingAwayFromToday() {
        let context = makeRepositoryContext(name: #function)
        let viewModel = ChecklistViewModel(
            defaults: context.defaults,
            taskRepository: context.repository
        )

        viewModel.setTaskPresentationMode(.focus)
        #expect(viewModel.taskPresentationMode == .focus)

        viewModel.toggleUpcomingQuickFilter()

        #expect(viewModel.taskFocusFilter == .upcoming)
        #expect(viewModel.taskPresentationMode == .browse)
        #expect(viewModel.isFocusModeAvailable == false)
    }

    @Test func movingUnplannedTasksPersistsSectionLocalManualOrder() {
        let context = makeRepositoryContext(name: #function)
        let tasks = [
            StartupTask(title: "Alpha"),
            StartupTask(title: "Bravo"),
            StartupTask(title: "Charlie")
        ]
        try? context.repository.saveTasks(tasks, postChangeNotification: false)

        let reloadedViewModel = ChecklistViewModel(
            defaults: context.defaults,
            taskRepository: FileTaskRepository(defaults: context.defaults, storeURL: context.storeURL)
        )

        guard
            let alpha = reloadedViewModel.tasks.first(where: { $0.title == "Alpha" }),
            let charlie = reloadedViewModel.tasks.first(where: { $0.title == "Charlie" })
        else {
            Issue.record("Unable to locate expected tasks")
            return
        }

        reloadedViewModel.moveTask(withID: charlie.id, beforeTaskWithID: alpha.id, in: .unplanned)

        let unplannedTasks = reloadedViewModel.browseSections
            .first(where: { $0.id == .unplanned })?
            .tasks
            .map(\.title)
        #expect(unplannedTasks == ["Charlie", "Alpha", "Bravo"])

        let manualOrders = Dictionary(
            uniqueKeysWithValues: reloadedViewModel.tasks.map { ($0.title, ($0.manualOrderGroupID, $0.manualOrder)) }
        )
        #expect(manualOrders["Charlie"]?.0 == TaskSectionKind.unplanned.rawValue)
        #expect(manualOrders["Charlie"]?.1 == 0)
        #expect(manualOrders["Alpha"]?.1 == 1)
        #expect(manualOrders["Bravo"]?.1 == 2)
    }

    @Test func addTaskAppendsToBottomOfUnplannedManualOrder() {
        let context = makeRepositoryContext(name: #function)
        let tasks = [
            StartupTask(
                title: "Alpha",
                manualOrderGroupID: TaskSectionKind.unplanned.rawValue,
                manualOrder: 0
            ),
            StartupTask(
                title: "Bravo",
                manualOrderGroupID: TaskSectionKind.unplanned.rawValue,
                manualOrder: 1
            )
        ]
        try? context.repository.saveTasks(tasks, postChangeNotification: false)

        let viewModel = ChecklistViewModel(
            defaults: context.defaults,
            taskRepository: FileTaskRepository(defaults: context.defaults, storeURL: context.storeURL)
        )
        viewModel.newTaskTitle = "Charlie"
        viewModel.addTask()

        let unplannedTitles = viewModel.browseSections
            .first(where: { $0.id == .unplanned })?
            .tasks
            .map(\.title)
        #expect(unplannedTitles == ["Alpha", "Bravo", "Charlie"])
    }

    @Test func focusTasksFlattenTodayBrowseScope() {
        let tasks = [
            StartupTask(title: "Pinned", isPinned: true, pinnedOrder: 0),
            StartupTask(title: "Overdue", dueDate: fixedDate(hour: 8), hasExplicitDueTime: true),
            StartupTask(title: "Today", dueDate: fixedDate(hour: 11), hasExplicitDueTime: true),
            StartupTask(title: "Unplanned")
        ]

        let focusTitles = TaskScheduling.focusTasks(
            for: tasks,
            now: fixedDate(hour: 10)
        ).map(\.title)

        #expect(focusTitles == ["Pinned", "Overdue", "Today", "Unplanned"])
    }

    @Test func movingPinnedTaskToEndUpdatesPinnedOrder() {
        let context = makeRepositoryContext(name: #function)
        let pinnedTasks = [
            StartupTask(title: "First", isPinned: true, pinnedOrder: 0),
            StartupTask(title: "Second", isPinned: true, pinnedOrder: 1),
            StartupTask(title: "Third", isPinned: true, pinnedOrder: 2)
        ]
        try? context.repository.saveTasks(pinnedTasks, postChangeNotification: false)

        let viewModel = ChecklistViewModel(
            defaults: context.defaults,
            taskRepository: FileTaskRepository(defaults: context.defaults, storeURL: context.storeURL)
        )

        guard let first = viewModel.tasks.first(where: { $0.title == "First" }) else {
            Issue.record("Unable to locate pinned task")
            return
        }

        viewModel.moveTaskToEnd(withID: first.id, in: .pinned)

        let pinnedTitles = viewModel.browseSections
            .first(where: { $0.id == .pinned })?
            .tasks
            .map(\.title)
        #expect(pinnedTitles == ["Second", "Third", "First"])
    }

    @Test func menuBarIconStatePrefersOverdueOverNearDue() {
        let tasks = [
            StartupTask(title: "Near due", dueDate: fixedDate(hour: 10), hasExplicitDueTime: true),
            StartupTask(title: "Overdue", dueDate: fixedDate(hour: 8), hasExplicitDueTime: true)
        ]

        #expect(TaskScheduling.menuBarIconState(for: tasks, now: fixedDate(hour: 9)) == .overdue)
        #expect(TaskScheduling.menuBarIconState(for: [tasks[0]], now: fixedDate(hour: 9, minute: 15)) == .nearDue)
        #expect(TaskScheduling.menuBarIconState(for: [StartupTask(title: "Someday")], now: fixedDate(hour: 9)) == .normal)
    }

    @Test func dueAlertServiceSchedulesOnlyFutureEligibleAlerts() async {
        let scheduler = FakeNotificationScheduler()
        let service = DueAlertService(
            scheduler: scheduler,
            calendar: Calendar(identifier: .gregorian),
            nowProvider: { self.fixedDate(hour: 9) }
        )

        let futureTimedTask = StartupTask(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001") ?? UUID(),
            title: "Timed task",
            dueDate: fixedDate(hour: 11),
            hasExplicitDueTime: true
        )
        let futureDayTask = StartupTask(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000002") ?? UUID(),
            title: "Day task",
            dueDate: fixedDate(day: 24, hour: 12)
        )
        let overdueTask = StartupTask(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000003") ?? UUID(),
            title: "Overdue",
            dueDate: fixedDate(hour: 8),
            hasExplicitDueTime: true
        )

        await service.syncDueAlerts(for: [futureTimedTask, futureDayTask, overdueTask], enabled: true)

        let requests = await scheduler.pendingRequests()
        #expect(requests.count == 2)
        #expect(requests.map(\.identifier).sorted() == [
            DueAlertService.identifier(for: futureTimedTask),
            DueAlertService.identifier(for: futureDayTask)
        ])
    }

    @Test func dueAlertServiceRemovesExistingAlertsWhenDisabled() async {
        let scheduler = FakeNotificationScheduler(
            initialRequests: [
                UNNotificationRequest(
                    identifier: "keepingup.dueAlert.old",
                    content: UNMutableNotificationContent(),
                    trigger: nil
                ),
                UNNotificationRequest(
                    identifier: "other.notification",
                    content: UNMutableNotificationContent(),
                    trigger: nil
                )
            ]
        )
        let service = DueAlertService(scheduler: scheduler)

        await service.syncDueAlerts(for: [], enabled: false)

        let requests = await scheduler.pendingRequests()
        #expect(requests.map(\.identifier) == ["other.notification"])
    }

    private func fixedDate(day: Int = 23, hour: Int, minute: Int = 0) -> Date {
        var components = DateComponents()
        components.year = 2026
        components.month = 3
        components.day = day
        components.hour = hour
        components.minute = minute
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

private final class FakeNotificationScheduler: UserNotificationScheduling {
    private var requests: [UNNotificationRequest]

    init(initialRequests: [UNNotificationRequest] = []) {
        requests = initialRequests
    }

    func pendingRequests() async -> [UNNotificationRequest] {
        requests
    }

    func add(_ request: UNNotificationRequest) async {
        requests.removeAll { $0.identifier == request.identifier }
        requests.append(request)
    }

    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {
        requests.removeAll { identifiers.contains($0.identifier) }
    }
}
