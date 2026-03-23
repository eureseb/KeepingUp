//
//  ChecklistViewModel.swift
//  KeepingUp
//
//  Created by EureseB on 3/20/26.
//

import Foundation
import Combine
import ServiceManagement
import UserNotifications

/// ObservableObject exposes state that SwiftUI watches for UI updates.
/// The same instance is shared by the menu bar UI for the lifetime of the app.
@MainActor
final class ChecklistViewModel: ObservableObject {
    @Published var tasks: [StartupTask] = []
    @Published var newTaskTitle: String = ""
    @Published var taskFocusFilter: TaskFocusFilter = .today
    @Published var taskPresentationMode: TaskPresentationMode = .browse
    @Published var launchAtLoginEnabled = false
    @Published var startupReminderEnabled = false {
        didSet { saveReminderPreference() }
    }
    @Published var dueAlertsEnabled = false {
        didSet { defaults.set(dueAlertsEnabled, forKey: dueAlertsEnabledKey) }
    }
    @Published var autoDeleteCompletedEnabled = false {
        didSet { defaults.set(autoDeleteCompletedEnabled, forKey: autoDeleteCompletedEnabledKey) }
    }
    @Published var notificationPermissionDenied = false
    @Published var developerModeEnabled = false {
        didSet { defaults.set(developerModeEnabled, forKey: developerModeKey) }
    }
    @Published var reminderCooldownMinutes = 240 {
        didSet { defaults.set(reminderCooldownMinutes, forKey: reminderCooldownMinutesKey) }
    }
    @Published var reminderCooldownDisabled = false {
        didSet { defaults.set(reminderCooldownDisabled, forKey: reminderCooldownDisabledKey) }
    }
    @Published var reminderStyle: ReminderPresentationStyle = .popupWindow {
        didSet { defaults.set(reminderStyle.rawValue, forKey: reminderStyleKey) }
    }
    @Published var notificationTextSize: NotificationTextSize = .medium {
        didSet { defaults.set(notificationTextSize.rawValue, forKey: notificationTextSizeKey) }
    }
    @Published var popupAutoDismissSeconds = 5 {
        didSet { defaults.set(popupAutoDismissSeconds, forKey: popupAutoDismissSecondsKey) }
    }
    @Published private(set) var currentDate: Date = .now

    private let reminderStorageKey = "startupReminderEnabled"
    private let dueAlertsEnabledKey = "dueAlertsEnabled"
    private let autoDeleteCompletedEnabledKey = "autoDeleteCompletedEnabled"
    private let lastCompletedCleanupDateKey = "lastCompletedCleanupDate"
    private let developerModeKey = "developerModeEnabled"
    private let reminderCooldownMinutesKey = "reminderCooldownMinutes"
    private let reminderCooldownDisabledKey = "reminderCooldownDisabled"
    private let reminderStyleKey = "reminderPresentationStyle"
    private let notificationTextSizeKey = "notificationTextSize"
    private let popupAutoDismissSecondsKey = "popupAutoDismissSeconds"
    private let completedTaskRetentionInterval: TimeInterval = 24 * 60 * 60
    private let defaults: UserDefaults
    private let reminderService: ReminderService
    private let dueAlertService: DueAlertService
    private let taskRepository: TaskRepository
    private let distributedNotificationCenter = DistributedNotificationCenter.default()
    private var tasksDidChangeObserver: NSObjectProtocol?
    private var currentDateTimer: Timer?

    init(
        defaults: UserDefaults = .standard,
        reminderService: ReminderService? = nil,
        dueAlertService: DueAlertService? = nil,
        taskRepository: TaskRepository? = nil
    ) {
        self.defaults = defaults
        self.reminderService = reminderService ?? ReminderService(defaults: defaults)
        self.dueAlertService = dueAlertService ?? DueAlertService()
        self.taskRepository = taskRepository ?? FileTaskRepository(defaults: defaults)

        loadTasks()
        loadPreferences()
        refreshLaunchAtLoginState()
        observeExternalTaskChanges()
        startCurrentDateRefreshTimer()

        Task {
            debugLog("App launch detected")
            performDailyCompletedCleanupIfNeeded()
            await syncDueAlerts()
            await refreshNotificationPermissionState()
            await handleReminderTrigger(reason: .appLaunch)
        }
    }

    var incompleteTaskCount: Int {
        tasks.filter { !$0.isComplete }.count
    }

    var browseSections: [TaskListSectionModel] {
        TaskScheduling.browseSections(
            for: tasks,
            filter: taskFocusFilter,
            now: currentDate
        )
    }

    var focusSections: [TaskListSectionModel] {
        guard taskFocusFilter == .today else { return [] }
        return TaskScheduling.focusSections(for: tasks, now: currentDate)
    }

    var focusTasks: [StartupTask] {
        guard taskFocusFilter == .today else { return [] }
        return TaskScheduling.focusTasks(for: tasks, now: currentDate)
    }

    var isFocusModeAvailable: Bool {
        taskFocusFilter == .today
    }

    var menuBarIconState: MenuBarIconState {
        TaskScheduling.menuBarIconState(for: tasks, now: currentDate)
    }

    var menuBarIconName: String {
        menuBarIconState.systemImageName
    }

    var menuBarAccessibilityLabel: String {
        menuBarIconState.accessibilityLabel
    }

    func addTask() {
        guard let title = try? TaskStore.validateTitle(newTaskTitle) else {
            return
        }

        tasks.append(
            StartupTask(
                title: title,
                manualOrderGroupID: TaskSectionKind.unplanned.rawValue,
                manualOrder: nextManualOrder(in: .unplanned)
            )
        )
        saveTasks()
        newTaskTitle = ""
    }

    func setTaskFocusFilter(_ filter: TaskFocusFilter) {
        taskFocusFilter = filter
        if filter != .today, taskPresentationMode == .focus {
            taskPresentationMode = .browse
        }
    }

    func resetPopoverFilterToDefault() {
        setTaskFocusFilter(.today)
    }

    func toggleUpcomingQuickFilter() {
        let nextFilter: TaskFocusFilter = taskFocusFilter == .upcoming ? .today : .upcoming
        setTaskFocusFilter(nextFilter)
    }

    func setTaskPresentationMode(_ mode: TaskPresentationMode) {
        guard mode != .focus || isFocusModeAvailable else {
            taskPresentationMode = .browse
            return
        }

        taskPresentationMode = mode
    }

    func removeTasks(at offsets: IndexSet) {
        for index in offsets.sorted(by: >) {
            tasks.remove(at: index)
        }
        saveTasks()
    }

    func remove(task: StartupTask) {
        tasks.removeAll { $0.id == task.id }
        normalizePinnedOrders()
        saveTasks()
    }

    func removeTasks(withIDs taskIDs: Set<UUID>) {
        guard !taskIDs.isEmpty else { return }
        tasks.removeAll { taskIDs.contains($0.id) }
        normalizePinnedOrders()
        saveTasks()
    }

    func moveTask(withID taskID: UUID, beforeTaskWithID targetTaskID: UUID, in section: TaskSectionKind) {
        guard taskID != targetTaskID else { return }

        switch section {
        case .pinned:
            reorderPinnedTask(taskID: taskID, beforeTaskID: targetTaskID)
        case .completed:
            return
        case .overdue, .today, .upcoming, .unplanned:
            reorderSectionTask(taskID: taskID, beforeTaskID: targetTaskID, in: section)
        }
    }

    func moveTaskToEnd(withID taskID: UUID, in section: TaskSectionKind) {
        switch section {
        case .pinned:
            reorderPinnedTaskToEnd(taskID: taskID)
        case .completed:
            return
        case .overdue, .today, .upcoming, .unplanned:
            reorderSectionTaskToEnd(taskID: taskID, in: section)
        }
    }

    func toggleCompletion(for task: StartupTask) {
        guard let index = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        tasks[index].isComplete.toggle()
        tasks[index].updatedAt = .now
        saveTasks()
    }

    func setLaunchAtLogin(_ isEnabled: Bool) {
        do {
            if isEnabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }

            launchAtLoginEnabled = isEnabled
        } catch {
            launchAtLoginEnabled = isLaunchAtLoginCurrentlyEnabled()
            print("Failed to update launch at login: \(error.localizedDescription)")
        }
    }

    func setStartupReminderEnabled(_ isEnabled: Bool) {
        Task {
            if isEnabled {
                if reminderStyle == .macOSNotification {
                    let granted = await reminderService.requestAuthorizationIfNeeded()
                    notificationPermissionDenied = !granted
                    startupReminderEnabled = granted
                } else {
                    startupReminderEnabled = true
                    notificationPermissionDenied = false
                }
            } else {
                startupReminderEnabled = false
                notificationPermissionDenied = false
            }
        }
    }

    func setDueAlertsEnabled(_ isEnabled: Bool) {
        Task {
            if isEnabled {
                let granted = await reminderService.requestAuthorizationIfNeeded()
                notificationPermissionDenied = !granted
                dueAlertsEnabled = granted
            } else {
                dueAlertsEnabled = false
            }

            await syncDueAlerts()
            await refreshNotificationPermissionState()
        }
    }

    func performDailyCompletedCleanupIfNeeded(now: Date = .now) {
        guard autoDeleteCompletedEnabled else { return }

        let calendar = Calendar.current
        if
            let lastCleanupDate = defaults.object(forKey: lastCompletedCleanupDateKey) as? Date,
            calendar.isDate(lastCleanupDate, inSameDayAs: now)
        {
            return
        }

        let retainedCutoff = now.addingTimeInterval(-completedTaskRetentionInterval)
        let previousCount = tasks.count
        tasks.removeAll {
            $0.isComplete && $0.updatedAt < retainedCutoff
        }

        defaults.set(now, forKey: lastCompletedCleanupDateKey)

        guard tasks.count != previousCount else { return }
        normalizePinnedOrders()
        saveTasks()
    }

    func setReminderStyle(_ style: ReminderPresentationStyle) {
        reminderStyle = style

        Task {
            if startupReminderEnabled && style == .macOSNotification {
                let granted = await reminderService.requestAuthorizationIfNeeded()
                notificationPermissionDenied = !granted
                if !granted {
                    startupReminderEnabled = false
                }
            } else {
                await refreshNotificationPermissionState()
            }
        }
    }

    func setPriority(_ priority: TaskPriority, for task: StartupTask) {
        guard let index = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        tasks[index].priority = priority
        tasks[index].updatedAt = .now
        saveTasks()
    }

    func renameTask(taskID: UUID, to rawTitle: String) -> Bool {
        guard
            let index = tasks.firstIndex(where: { $0.id == taskID }),
            let title = try? TaskStore.validateTitle(rawTitle)
        else {
            return false
        }

        tasks[index].title = title
        tasks[index].updatedAt = .now
        saveTasks()
        return true
    }

    func saveTaskEdits(
        taskID: UUID,
        title rawTitle: String,
        dueDate: Date?,
        hasExplicitDueTime: Bool,
        priority: TaskPriority,
        isPinned: Bool
    ) -> Bool {
        guard
            let index = tasks.firstIndex(where: { $0.id == taskID }),
            let title = try? TaskStore.validateTitle(rawTitle)
        else {
            return false
        }

        let wasPinned = tasks[index].isPinned
        let previousDueDate = tasks[index].dueDate
        let previousHasExplicitDueTime = tasks[index].hasExplicitDueTime
        tasks[index].title = title
        tasks[index].priority = priority
        tasks[index].dueDate = dueDate
        tasks[index].hasExplicitDueTime = dueDate != nil ? hasExplicitDueTime : false
        tasks[index].isPinned = isPinned
        tasks[index].updatedAt = .now

        if isPinned && !wasPinned {
            tasks[index].pinnedOrder = nextPinnedOrder()
        } else if !isPinned {
            tasks[index].pinnedOrder = nil
        }

        if wasPinned != isPinned || previousDueDate != dueDate || previousHasExplicitDueTime != hasExplicitDueTime {
            tasks[index].manualOrderGroupID = nil
            tasks[index].manualOrder = nil
        }

        normalizePinnedOrders()
        saveTasks()
        return true
    }

    func clearDueDate(for task: StartupTask) {
        guard let index = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        tasks[index].dueDate = nil
        tasks[index].hasExplicitDueTime = false
        tasks[index].manualOrderGroupID = nil
        tasks[index].manualOrder = nil
        tasks[index].updatedAt = .now
        saveTasks()
    }

    func togglePinned(for task: StartupTask) {
        guard let index = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        tasks[index].isPinned.toggle()
        tasks[index].updatedAt = .now
        if tasks[index].isPinned {
            tasks[index].pinnedOrder = nextPinnedOrder()
            tasks[index].manualOrderGroupID = nil
            tasks[index].manualOrder = nil
        } else {
            tasks[index].pinnedOrder = nil
        }

        normalizePinnedOrders()
        saveTasks()
    }

    func movePinnedTask(_ task: StartupTask, direction: PinMoveDirection) {
        let pinnedTasks = tasks
            .filter(\.isPinned)
            .sorted { ($0.pinnedOrder ?? .max) < ($1.pinnedOrder ?? .max) }
        guard let currentPinnedIndex = pinnedTasks.firstIndex(where: { $0.id == task.id }) else {
            return
        }

        let targetPinnedIndex: Int
        switch direction {
        case .up:
            targetPinnedIndex = currentPinnedIndex - 1
        case .down:
            targetPinnedIndex = currentPinnedIndex + 1
        }

        guard pinnedTasks.indices.contains(targetPinnedIndex) else { return }

        var reorderedPinnedTasks = pinnedTasks
        reorderedPinnedTasks.swapAt(currentPinnedIndex, targetPinnedIndex)
        for (order, pinnedTask) in reorderedPinnedTasks.enumerated() {
            guard let index = tasks.firstIndex(where: { $0.id == pinnedTask.id }) else { continue }
            tasks[index].pinnedOrder = order
            tasks[index].updatedAt = .now
        }

        saveTasks()
    }

    func dueState(for task: StartupTask) -> TaskDueState {
        TaskScheduling.dueState(for: task, now: currentDate)
    }

    func dueDateSummary(for task: StartupTask) -> String {
        guard let dueDate = task.dueDate else { return "No deadline" }

        let formatter = DateFormatter()
        formatter.locale = .current

        if task.hasExplicitDueTime {
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
        } else {
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
        }

        return formatter.string(from: dueDate)
    }

    func testCurrentReminderStyle() {
        Task {
            debugLog("Developer test requested for \(reminderStyle.rawValue)")
            await reminderService.deliverReminder(for: tasks, reason: .developerTest, bypassCooldown: true)
            await refreshNotificationPermissionState()
        }
    }

    // MARK: - Persistence

    private func loadTasks() {
        do {
            tasks = try taskRepository.loadTasks()
            normalizePinnedOrders()
        } catch {
            tasks = []
            print("Failed to load tasks: \(error.localizedDescription)")
        }
    }

    private func saveTasks() {
        do {
            try taskRepository.saveTasks(tasks, postChangeNotification: true)
            Task {
                await self.syncDueAlerts()
            }
        } catch {
            print("Failed to save tasks: \(error.localizedDescription)")
        }
    }

    private func observeExternalTaskChanges() {
        let changeSourceIdentifier = taskRepository.changeSourceIdentifier
        tasksDidChangeObserver = distributedNotificationCenter.addObserver(
            forName: TaskStore.tasksDidChangeNotificationName,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self else { return }
            if
                let sourceIdentifier = notification.userInfo?[TaskStore.changeSourceIdentifierUserInfoKey] as? String,
                sourceIdentifier == changeSourceIdentifier
            {
                return
            }

            Task { @MainActor in
                self.loadTasks()
                await self.syncDueAlerts()
            }
        }
    }

    private func loadPreferences() {
        startupReminderEnabled = defaults.bool(forKey: reminderStorageKey)
        dueAlertsEnabled = defaults.bool(forKey: dueAlertsEnabledKey)
        autoDeleteCompletedEnabled = defaults.bool(forKey: autoDeleteCompletedEnabledKey)
        developerModeEnabled = defaults.bool(forKey: developerModeKey)

        let savedCooldownMinutes = defaults.integer(forKey: reminderCooldownMinutesKey)
        reminderCooldownMinutes = savedCooldownMinutes > 0 ? savedCooldownMinutes : 240

        reminderCooldownDisabled = defaults.bool(forKey: reminderCooldownDisabledKey)

        if
            let savedReminderStyle = defaults.string(forKey: reminderStyleKey),
            let parsedReminderStyle = ReminderPresentationStyle(rawValue: savedReminderStyle)
        {
            reminderStyle = parsedReminderStyle
        } else {
            reminderStyle = .popupWindow
        }

        if
            let savedNotificationTextSize = defaults.string(forKey: notificationTextSizeKey),
            let parsedNotificationTextSize = NotificationTextSize(rawValue: savedNotificationTextSize)
        {
            notificationTextSize = parsedNotificationTextSize
        } else {
            notificationTextSize = .medium
        }

        if defaults.object(forKey: popupAutoDismissSecondsKey) != nil {
            let savedPopupAutoDismissSeconds = defaults.integer(forKey: popupAutoDismissSecondsKey)
            popupAutoDismissSeconds = max(0, savedPopupAutoDismissSeconds)
        } else {
            popupAutoDismissSeconds = 5
        }
    }

    private func saveReminderPreference() {
        defaults.set(startupReminderEnabled, forKey: reminderStorageKey)
    }

    private func startCurrentDateRefreshTimer() {
        currentDateTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.currentDate = .now
            }
        }
        currentDateTimer?.tolerance = 10
    }

    // MARK: - Launch At Login

    private func refreshLaunchAtLoginState() {
        launchAtLoginEnabled = isLaunchAtLoginCurrentlyEnabled()
    }

    private func isLaunchAtLoginCurrentlyEnabled() -> Bool {
        let status = SMAppService.mainApp.status
        return status == .enabled
    }

    // MARK: - Reminders

    func handleReminderTrigger(reason: ReminderReason) async {
        performDailyCompletedCleanupIfNeeded()
        debugLog("Popup evaluation started for \(reason.debugName)")

        guard reason.shouldTriggerStartupReminder else {
            debugLog("Popup skipped: app activation no longer triggers reminders")
            return
        }

        guard startupReminderEnabled else {
            debugLog("Popup skipped: reminders are disabled")
            return
        }

        guard !tasks.isEmpty else {
            debugLog("Popup skipped: no tasks available")
            return
        }

        await reminderService.deliverReminder(for: tasks, reason: reason)
        await refreshNotificationPermissionState()
    }

    private func syncDueAlerts() async {
        await dueAlertService.syncDueAlerts(for: tasks, enabled: dueAlertsEnabled)
    }

    private func refreshNotificationPermissionState() async {
        let requiresNotificationAccess = dueAlertsEnabled || reminderStyle == .macOSNotification
        guard requiresNotificationAccess else {
            notificationPermissionDenied = false
            return
        }

        let status = await reminderService.authorizationStatus()

        switch status {
        case .authorized, .provisional:
            notificationPermissionDenied = false
        case .denied:
            notificationPermissionDenied = true
        case .notDetermined:
            notificationPermissionDenied = false
        @unknown default:
            notificationPermissionDenied = false
        }
    }

    private func nextPinnedOrder() -> Int {
        let highestPinnedOrder = tasks
            .compactMap(\.pinnedOrder)
            .max() ?? -1
        return highestPinnedOrder + 1
    }

    private func nextManualOrder(in section: TaskSectionKind) -> Int {
        let highestOrder = tasks
            .filter { $0.manualOrderGroupID == section.rawValue }
            .compactMap(\.manualOrder)
            .max() ?? -1
        return highestOrder + 1
    }

    private func reorderSectionTask(taskID: UUID, beforeTaskID targetTaskID: UUID, in section: TaskSectionKind) {
        let sectionTasks = browseSections.first(where: { $0.id == section })?.tasks ?? []
        let sectionTaskIDs = sectionTasks.map(\.id)
        guard sectionTaskIDs.contains(taskID), sectionTaskIDs.contains(targetTaskID) else {
            return
        }

        var reorderedIDs = sectionTaskIDs
        reorderedIDs.removeAll { $0 == taskID }

        guard let insertionIndex = reorderedIDs.firstIndex(of: targetTaskID) else { return }
        reorderedIDs.insert(taskID, at: insertionIndex)
        applyManualOrder(reorderedIDs, in: section)
        saveTasks()
    }

    private func reorderPinnedTask(taskID: UUID, beforeTaskID targetTaskID: UUID) {
        let pinnedTasks = browseSections.first(where: { $0.id == .pinned })?.tasks ?? []
        var reorderedIDs = pinnedTasks.map(\.id)
        guard reorderedIDs.contains(taskID), reorderedIDs.contains(targetTaskID) else { return }

        reorderedIDs.removeAll { $0 == taskID }
        guard let insertionIndex = reorderedIDs.firstIndex(of: targetTaskID) else { return }
        reorderedIDs.insert(taskID, at: insertionIndex)
        applyPinnedOrder(reorderedIDs)
        saveTasks()
    }

    private func reorderSectionTaskToEnd(taskID: UUID, in section: TaskSectionKind) {
        let sectionTasks = browseSections.first(where: { $0.id == section })?.tasks ?? []
        var reorderedIDs = sectionTasks.map(\.id)
        guard reorderedIDs.contains(taskID) else { return }

        reorderedIDs.removeAll { $0 == taskID }
        reorderedIDs.append(taskID)
        applyManualOrder(reorderedIDs, in: section)
        saveTasks()
    }

    private func reorderPinnedTaskToEnd(taskID: UUID) {
        let pinnedTasks = browseSections.first(where: { $0.id == .pinned })?.tasks ?? []
        var reorderedIDs = pinnedTasks.map(\.id)
        guard reorderedIDs.contains(taskID) else { return }

        reorderedIDs.removeAll { $0 == taskID }
        reorderedIDs.append(taskID)
        applyPinnedOrder(reorderedIDs)
        saveTasks()
    }

    private func applyManualOrder(_ taskIDs: [UUID], in section: TaskSectionKind) {
        for (order, id) in taskIDs.enumerated() {
            guard let index = tasks.firstIndex(where: { $0.id == id }) else { continue }
            tasks[index].manualOrderGroupID = section.rawValue
            tasks[index].manualOrder = order
            tasks[index].updatedAt = .now
        }
    }

    private func applyPinnedOrder(_ taskIDs: [UUID]) {
        for (order, id) in taskIDs.enumerated() {
            guard let index = tasks.firstIndex(where: { $0.id == id }) else { continue }
            tasks[index].pinnedOrder = order
            tasks[index].updatedAt = .now
        }
    }

    private func normalizePinnedOrders() {
        let sortedPinnedTaskIDs = tasks
            .filter(\.isPinned)
            .sorted {
                ($0.pinnedOrder ?? .max, $0.createdAt) < ($1.pinnedOrder ?? .max, $1.createdAt)
            }
            .map(\.id)

        for (order, taskID) in sortedPinnedTaskIDs.enumerated() {
            guard let index = tasks.firstIndex(where: { $0.id == taskID }) else { continue }
            tasks[index].pinnedOrder = order
        }

        for index in tasks.indices where !tasks[index].isPinned {
            tasks[index].pinnedOrder = nil
        }
    }

    private func debugLog(_ message: String) {
        print("[KeepingUp][Reminder] \(message)")
    }

    deinit {
        currentDateTimer?.invalidate()

        if let tasksDidChangeObserver {
            distributedNotificationCenter.removeObserver(tasksDidChangeObserver)
        }
    }
}

enum PinMoveDirection {
    case up
    case down
}
