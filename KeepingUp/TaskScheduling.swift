//
//  TaskScheduling.swift
//  KeepingUp
//
//  Created by Codex on 3/23/26.
//

import Foundation

enum TaskPresentationMode: String, CaseIterable, Identifiable {
    case browse
    case focus

    var id: String { rawValue }

    nonisolated var title: String {
        switch self {
        case .browse:
            return "Browse"
        case .focus:
            return "Focus"
        }
    }
}

enum TaskFocusFilter: String, CaseIterable, Identifiable {
    case today
    case upcoming

    var id: String { rawValue }

    nonisolated var title: String {
        switch self {
        case .today:
            return "Today"
        case .upcoming:
            return "Upcoming"
        }
    }
}

enum TaskDueState: Int, Equatable {
    case overdue = 0
    case nearDue = 1
    case future = 2
    case noDeadline = 3

    nonisolated var title: String {
        switch self {
        case .overdue:
            return "Overdue"
        case .nearDue:
            return "Today"
        case .future:
            return "Upcoming"
        case .noDeadline:
            return "Unplanned"
        }
    }
}

enum TaskSectionKind: String, Identifiable {
    case pinned
    case overdue
    case today
    case upcoming
    case unplanned
    case completed

    var id: String { rawValue }

    nonisolated var title: String {
        switch self {
        case .pinned:
            return "Pinned"
        case .overdue:
            return "Overdue"
        case .today:
            return "Today"
        case .upcoming:
            return "Upcoming"
        case .unplanned:
            return "Unplanned"
        case .completed:
            return "Completed"
        }
    }

    nonisolated var allowsManualReorder: Bool {
        switch self {
        case .pinned, .overdue, .today, .upcoming, .unplanned:
            return true
        case .completed:
            return false
        }
    }
}

enum MenuBarIconState: Equatable {
    case normal
    case nearDue
    case overdue

    nonisolated var systemImageName: String {
        switch self {
        case .normal:
            return "checklist"
        case .nearDue:
            return "clock.badge.exclamationmark"
        case .overdue:
            return "exclamationmark.circle"
        }
    }

    nonisolated var accessibilityLabel: String {
        switch self {
        case .normal:
            return "KeepingUp"
        case .nearDue:
            return "KeepingUp, task due soon"
        case .overdue:
            return "KeepingUp, overdue task"
        }
    }
}

struct TaskListSectionModel: Identifiable, Equatable {
    let id: TaskSectionKind
    let title: String
    let tasks: [StartupTask]
    let allowsManualReorder: Bool
}

enum TaskScheduling {
    nonisolated static let nearDueWindow: TimeInterval = 60 * 60

    nonisolated static func dueState(
        for task: StartupTask,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> TaskDueState {
        guard !task.isComplete, let dueDate = task.dueDate else {
            return .noDeadline
        }

        if task.hasExplicitDueTime {
            if dueDate <= now {
                return .overdue
            }

            if dueDate.timeIntervalSince(now) <= nearDueWindow {
                return .nearDue
            }

            return .future
        }

        let dueDay = calendar.startOfDay(for: dueDate)
        let currentDay = calendar.startOfDay(for: now)

        if currentDay > dueDay {
            return .overdue
        }

        if currentDay == dueDay {
            return .nearDue
        }

        return .future
    }

    nonisolated static func rankedIncompleteTasks(
        from tasks: [StartupTask],
        now: Date = .now,
        calendar: Calendar = .current
    ) -> [StartupTask] {
        tasks
            .enumerated()
            .filter { !$0.element.isComplete }
            .sorted { left, right in
                if compareIncompleteTasks(left.element, right.element, now: now, calendar: calendar) {
                    return true
                }

                if compareIncompleteTasks(right.element, left.element, now: now, calendar: calendar) {
                    return false
                }

                return left.offset < right.offset
            }
            .map(\.element)
    }

    nonisolated static func reminderCandidate(
        from tasks: [StartupTask],
        now: Date = .now,
        calendar: Calendar = .current
    ) -> StartupTask? {
        reminderOrderedIncompleteTasks(from: tasks, now: now, calendar: calendar).first
    }

    nonisolated static func reminderOrderedIncompleteTasks(
        from tasks: [StartupTask],
        now: Date = .now,
        calendar: Calendar = .current
    ) -> [StartupTask] {
        browseSections(for: tasks, filter: .today, now: now, calendar: calendar)
            .filter { $0.id != .completed }
            .flatMap(\.tasks)
            .filter { !$0.isComplete }
    }

    nonisolated static func menuBarIconState(
        for tasks: [StartupTask],
        now: Date = .now,
        calendar: Calendar = .current
    ) -> MenuBarIconState {
        let dueStates = tasks
            .filter { !$0.isComplete }
            .map { dueState(for: $0, now: now, calendar: calendar) }

        if dueStates.contains(.overdue) {
            return .overdue
        }

        if dueStates.contains(.nearDue) {
            return .nearDue
        }

        return .normal
    }

    nonisolated static func browseSections(
        for tasks: [StartupTask],
        filter: TaskFocusFilter,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> [TaskListSectionModel] {
        let incompleteTasks = tasks.filter { !$0.isComplete }
        let pinnedTasks = orderedTasksForDisplay(
            in: .pinned,
            from: incompleteTasks.filter(\.isPinned),
            defaultTasks: incompleteTasks.filter(\.isPinned).sorted(by: comparePinnedTasks)
        )

        let baseUnpinnedTasks = incompleteTasks
            .filter { !$0.isPinned }
            .sorted(by: compareBaseOrder)
        let overdueTasks = orderedTasksForDisplay(
            in: .overdue,
            from: baseUnpinnedTasks.filter { dueState(for: $0, now: now, calendar: calendar) == .overdue },
            defaultTasks: baseUnpinnedTasks.filter { dueState(for: $0, now: now, calendar: calendar) == .overdue }
        )
        let todayTasks = orderedTasksForDisplay(
            in: .today,
            from: baseUnpinnedTasks.filter { dueState(for: $0, now: now, calendar: calendar) == .nearDue },
            defaultTasks: baseUnpinnedTasks.filter { dueState(for: $0, now: now, calendar: calendar) == .nearDue }
        )
        let upcomingTasks = orderedTasksForDisplay(
            in: .upcoming,
            from: baseUnpinnedTasks.filter { dueState(for: $0, now: now, calendar: calendar) == .future },
            defaultTasks: baseUnpinnedTasks.filter { dueState(for: $0, now: now, calendar: calendar) == .future }
        )
        let unplannedTasks = orderedTasksForDisplay(
            in: .unplanned,
            from: baseUnpinnedTasks.filter { dueState(for: $0, now: now, calendar: calendar) == .noDeadline },
            defaultTasks: baseUnpinnedTasks.filter { dueState(for: $0, now: now, calendar: calendar) == .noDeadline }
        )
        let completedTasks = tasks.filter(\.isComplete)

        let visibleTimedSections: [TaskListSectionModel] = switch filter {
        case .today:
            [
                makeSection(.overdue, tasks: overdueTasks),
                makeSection(.today, tasks: todayTasks)
            ]
        case .upcoming:
            [
                makeSection(.upcoming, tasks: upcomingTasks)
            ]
        }

        return [
            makeSection(.pinned, tasks: pinnedTasks),
            visibleTimedSections[0],
            visibleTimedSections.count > 1 ? visibleTimedSections[1] : nil,
            makeSection(.unplanned, tasks: unplannedTasks),
            makeSection(.completed, tasks: completedTasks)
        ]
        .compactMap { $0 }
        .filter { !$0.tasks.isEmpty }
    }

    nonisolated static func focusSections(
        for tasks: [StartupTask],
        now: Date = .now,
        calendar: Calendar = .current
    ) -> [TaskListSectionModel] {
        let rankedTasks = rankedIncompleteTasks(from: tasks, now: now, calendar: calendar)
        let overdueTasks = orderedTasksForDisplay(
            in: .overdue,
            from: rankedTasks.filter { dueState(for: $0, now: now, calendar: calendar) == .overdue },
            defaultTasks: rankedTasks.filter { dueState(for: $0, now: now, calendar: calendar) == .overdue }
        )
        let todayTasks = orderedTasksForDisplay(
            in: .today,
            from: rankedTasks.filter { dueState(for: $0, now: now, calendar: calendar) == .nearDue },
            defaultTasks: rankedTasks.filter { dueState(for: $0, now: now, calendar: calendar) == .nearDue }
        )

        return [
            makeSection(.overdue, tasks: overdueTasks, allowsManualReorder: false),
            makeSection(.today, tasks: todayTasks, allowsManualReorder: false)
        ]
        .filter { !$0.tasks.isEmpty }
    }

    nonisolated static func focusTasks(
        for tasks: [StartupTask],
        now: Date = .now,
        calendar: Calendar = .current
    ) -> [StartupTask] {
        browseSections(for: tasks, filter: .today, now: now, calendar: calendar)
            .filter { $0.id != .completed }
            .flatMap(\.tasks)
            .filter { !$0.isComplete }
    }

    nonisolated static func displaySections(
        for tasks: [StartupTask],
        filter: TaskFocusFilter,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> [TaskListSectionModel] {
        browseSections(for: tasks, filter: filter, now: now, calendar: calendar)
    }

    nonisolated static func dueAlertTriggerDate(
        for task: StartupTask,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> Date? {
        guard !task.isComplete, let dueDate = task.dueDate else {
            return nil
        }

        let triggerDate: Date
        if task.hasExplicitDueTime {
            triggerDate = dueDate.addingTimeInterval(-nearDueWindow)
        } else {
            triggerDate = calendar.startOfDay(for: dueDate)
        }

        guard triggerDate > now else {
            return nil
        }

        return triggerDate
    }

    private nonisolated static func makeSection(
        _ kind: TaskSectionKind,
        tasks: [StartupTask],
        allowsManualReorder: Bool? = nil
    ) -> TaskListSectionModel {
        TaskListSectionModel(
            id: kind,
            title: kind.title,
            tasks: tasks,
            allowsManualReorder: allowsManualReorder ?? kind.allowsManualReorder
        )
    }

    private nonisolated static func orderedTasksForDisplay(
        in section: TaskSectionKind,
        from tasks: [StartupTask],
        defaultTasks: [StartupTask]
    ) -> [StartupTask] {
        let defaultIndices = Dictionary(
            uniqueKeysWithValues: defaultTasks.enumerated().map { ($1.id, $0) }
        )

        return tasks.sorted { left, right in
            let leftManualOrder = left.manualOrderGroupID == section.rawValue ? left.manualOrder : nil
            let rightManualOrder = right.manualOrderGroupID == section.rawValue ? right.manualOrder : nil

            switch (leftManualOrder, rightManualOrder) {
            case let (.some(leftOrder), .some(rightOrder)) where leftOrder != rightOrder:
                return leftOrder < rightOrder
            case (.some, nil):
                return true
            case (nil, .some):
                return false
            default:
                return (defaultIndices[left.id] ?? .max) < (defaultIndices[right.id] ?? .max)
            }
        }
    }

    private nonisolated static func compareIncompleteTasks(
        _ left: StartupTask,
        _ right: StartupTask,
        now: Date,
        calendar: Calendar
    ) -> Bool {
        let leftState = dueState(for: left, now: now, calendar: calendar)
        let rightState = dueState(for: right, now: now, calendar: calendar)

        if leftState.rawValue != rightState.rawValue {
            return leftState.rawValue < rightState.rawValue
        }

        switch (left.dueDate, right.dueDate) {
        case let (.some(leftDate), .some(rightDate)) where leftDate != rightDate:
            return leftDate < rightDate
        default:
            break
        }

        if left.createdAt != right.createdAt {
            return left.createdAt < right.createdAt
        }

        return left.id.uuidString < right.id.uuidString
    }

    private nonisolated static func comparePinnedTasks(_ left: StartupTask, _ right: StartupTask) -> Bool {
        let leftOrder = left.pinnedOrder ?? .max
        let rightOrder = right.pinnedOrder ?? .max

        if leftOrder != rightOrder {
            return leftOrder < rightOrder
        }

        if left.updatedAt != right.updatedAt {
            return left.updatedAt > right.updatedAt
        }

        return left.createdAt < right.createdAt
    }

    private nonisolated static func compareBaseOrder(_ left: StartupTask, _ right: StartupTask) -> Bool {
        if left.createdAt != right.createdAt {
            return left.createdAt < right.createdAt
        }

        return left.id.uuidString < right.id.uuidString
    }
}
