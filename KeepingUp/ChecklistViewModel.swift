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
    @Published var tasks: [StartupTask] = [] {
        didSet { saveTasks() }
    }
    @Published var newTaskTitle: String = ""
    @Published var launchAtLoginEnabled = false
    @Published var startupReminderEnabled = false {
        didSet { saveReminderPreference() }
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

    private let reminderStorageKey = "startupReminderEnabled"
    private let developerModeKey = "developerModeEnabled"
    private let reminderCooldownMinutesKey = "reminderCooldownMinutes"
    private let reminderCooldownDisabledKey = "reminderCooldownDisabled"
    private let reminderStyleKey = "reminderPresentationStyle"
    private let notificationTextSizeKey = "notificationTextSize"
    private let popupAutoDismissSecondsKey = "popupAutoDismissSeconds"
    private let defaults: UserDefaults
    private let reminderService: ReminderService
    private let distributedNotificationCenter = DistributedNotificationCenter.default()
    private var tasksDidChangeObserver: NSObjectProtocol?

    init(
        defaults: UserDefaults = .standard,
        reminderService: ReminderService? = nil
    ) {
        self.defaults = defaults
        self.reminderService = reminderService ?? ReminderService()

        loadTasks()
        loadPreferences()
        refreshLaunchAtLoginState()
        observeExternalTaskChanges()

        Task {
            debugLog("App launch detected")
            await refreshNotificationPermissionState()
            await handleReminderTrigger(reason: .appLaunch)
        }
    }

    var incompleteTaskCount: Int {
        tasks.filter { !$0.isComplete }.count
    }

    func addTask() {
        guard let newTask = try? TaskStore.appendTask(
            title: newTaskTitle,
            defaults: defaults,
            postChangeNotification: false
        ) else {
            return
        }

        tasks.append(newTask)
        newTaskTitle = ""
    }

    func removeTasks(at offsets: IndexSet) {
        for index in offsets.sorted(by: >) {
            tasks.remove(at: index)
        }
    }

    func remove(task: StartupTask) {
        tasks.removeAll { $0.id == task.id }
    }

    func moveTasks(fromOffsets offsets: IndexSet, toOffset destination: Int) {
        let sortedOffsets = offsets.sorted()
        let movingTasks = sortedOffsets.map { tasks[$0] }

        for index in sortedOffsets.reversed() {
            tasks.remove(at: index)
        }

        let insertionIndex = min(destination, tasks.count)
        tasks.insert(contentsOf: movingTasks, at: insertionIndex)
    }

    func moveTask(withID taskID: UUID, beforeTaskWithID targetTaskID: UUID) {
        guard
            taskID != targetTaskID,
            let sourceIndex = tasks.firstIndex(where: { $0.id == taskID }),
            let targetIndex = tasks.firstIndex(where: { $0.id == targetTaskID })
        else {
            return
        }

        let task = tasks.remove(at: sourceIndex)
        let adjustedTargetIndex = sourceIndex < targetIndex ? targetIndex - 1 : targetIndex
        tasks.insert(task, at: adjustedTargetIndex)
    }

    func toggleCompletion(for task: StartupTask) {
        guard let index = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        tasks[index].isComplete.toggle()
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

    func testCurrentReminderStyle() {
        Task {
            debugLog("Developer test requested for \(reminderStyle.rawValue)")
            await reminderService.deliverReminder(for: tasks, reason: .developerTest, bypassCooldown: true)
            await refreshNotificationPermissionState()
        }
    }

    // MARK: - Persistence

    private func loadTasks() {
        tasks = TaskStore.loadTasks(from: defaults)
    }

    private func saveTasks() {
        do {
            try TaskStore.saveTasks(tasks, to: defaults, postChangeNotification: false)
        } catch {
            // Nothing fancy for the MVP: failing to save just logs the issue.
            print("Failed to save tasks: \(error.localizedDescription)")
        }
    }

    private func observeExternalTaskChanges() {
        tasksDidChangeObserver = distributedNotificationCenter.addObserver(
            forName: TaskStore.tasksDidChangeNotificationName,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.loadTasks()
            }
        }
    }

    private func loadPreferences() {
        startupReminderEnabled = defaults.bool(forKey: reminderStorageKey)
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
        debugLog("Popup evaluation started for \(reason.debugName)")

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

    private func refreshNotificationPermissionState() async {
        guard reminderStyle == .macOSNotification else {
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

    private func debugLog(_ message: String) {
        print("[KeepingUp][Reminder] \(message)")
    }

    deinit {
        if let tasksDidChangeObserver {
            distributedNotificationCenter.removeObserver(tasksDidChangeObserver)
        }
    }
}
