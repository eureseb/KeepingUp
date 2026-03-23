//
//  ReminderService.swift
//  KeepingUp
//
//  Created by Codex on 3/20/26.
//

import AppKit
import Foundation
import UserNotifications

enum ReminderPresentationStyle: String, CaseIterable, Identifiable {
    case popupWindow
    case macOSNotification

    var id: String { rawValue }

    var title: String {
        switch self {
        case .popupWindow:
            return "Popup Window"
        case .macOSNotification:
            return "macOS Notification"
        }
    }

    var description: String {
        switch self {
        case .popupWindow:
            return "Centered in-app reminder window"
        case .macOSNotification:
            return "Standard system notification banner/alert behavior"
        }
    }
}

enum NotificationTextSize: String, CaseIterable, Identifiable {
    case small
    case medium
    case large

    var id: String { rawValue }

    var title: String {
        switch self {
        case .small:
            return "Small"
        case .medium:
            return "Medium"
        case .large:
            return "Large"
        }
    }
}

enum ReminderReason {
    case appLaunch
    case sessionBecameActive
    case wokeFromSleep
    case appDidBecomeActive
    case screenUnlocked
    case developerTest

    var shouldTriggerStartupReminder: Bool {
        switch self {
        case .appDidBecomeActive:
            return false
        case .appLaunch, .sessionBecameActive, .wokeFromSleep, .screenUnlocked, .developerTest:
            return true
        }
    }

    var identifier: String {
        switch self {
        case .appLaunch:
            return "keepingup.appLaunchReminder"
        case .sessionBecameActive:
            return "keepingup.sessionReminder"
        case .wokeFromSleep:
            return "keepingup.wakeReminder"
        case .appDidBecomeActive:
            return "keepingup.appDidBecomeActiveReminder"
        case .screenUnlocked:
            return "keepingup.screenUnlockedReminder"
        case .developerTest:
            return "keepingup.developerTestReminder"
        }
    }

    var debugName: String {
        switch self {
        case .appLaunch:
            return "appLaunch"
        case .sessionBecameActive:
            return "sessionBecameActive"
        case .wokeFromSleep:
            return "wokeFromSleep"
        case .appDidBecomeActive:
            return "appDidBecomeActive"
        case .screenUnlocked:
            return "screenUnlocked"
        case .developerTest:
            return "developerTest"
        }
    }
}

final class ReminderService {
    private let notificationCenter: UNUserNotificationCenter
    private let defaults: UserDefaults
    private let lastReminderKey = "lastStartupReminderDate"
    private let developerModeKey = "developerModeEnabled"
    private let reminderCooldownMinutesKey = "reminderCooldownMinutes"
    private let reminderCooldownDisabledKey = "reminderCooldownDisabled"
    private let popupAutoDismissSecondsKey = "popupAutoDismissSeconds"
    private let reminderStyleKey = "reminderPresentationStyle"
    private let notificationTextSizeKey = "notificationTextSize"
    @MainActor private lazy var popupController = ReminderPopupController()

    init(
        defaults: UserDefaults = .standard,
        notificationCenter: UNUserNotificationCenter = .current()
    ) {
        self.defaults = defaults
        self.notificationCenter = notificationCenter
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        await withCheckedContinuation { continuation in
            notificationCenter.getNotificationSettings { settings in
                continuation.resume(returning: settings.authorizationStatus)
            }
        }
    }

    func requestAuthorizationIfNeeded() async -> Bool {
        let status = await authorizationStatus()

        switch status {
        case .authorized, .provisional:
            return true
        case .denied:
            return false
        case .notDetermined:
            return await withCheckedContinuation { continuation in
                notificationCenter.requestAuthorization(options: [.alert, .sound]) { granted, _ in
                    continuation.resume(returning: granted)
                }
            }
        @unknown default:
            return false
        }
    }

    func deliverReminder(for tasks: [StartupTask], reason: ReminderReason, bypassCooldown: Bool = false) async {
        debugLog("Popup evaluation started for \(reason.debugName)")

        guard reason.shouldTriggerStartupReminder else {
            debugLog("Popup skipped: reason \(reason.debugName) is not an active reminder trigger")
            return
        }

        guard !tasks.isEmpty else {
            debugLog("Popup skipped: task list is empty")
            return
        }

        let reminderStyle = selectedReminderStyle()
        debugLog("Reminder style selected: \(reminderStyle.rawValue)")

        guard bypassCooldown || shouldDeliverReminder(for: reason) else { return }

        switch reminderStyle {
        case .popupWindow:
            let autoDismissSeconds = configuredPopupAutoDismissSeconds(for: reason)
            let textSize = configuredNotificationTextSize()
            debugLog("Showing popup reminder only for \(reason.debugName)")
            await MainActor.run {
                popupController.show(
                    tasks: tasks,
                    autoDismissSeconds: autoDismissSeconds,
                    textSize: textSize
                )
            }
        case .macOSNotification:
            await scheduleNotification(for: tasks, reason: reason)
        }

        defaults.set(Date(), forKey: lastReminderKey)
    }

    private func scheduleNotification(for tasks: [StartupTask], reason: ReminderReason) async {
        let status = await authorizationStatus()
        debugLog("Notification authorization status: \(status.rawValue)")
        guard status == .authorized || status == .provisional else {
            debugLog("Notification skipped: authorization is \(status.rawValue)")
            return
        }

        let incompleteTasks = tasks.filter { !$0.isComplete }
        let tasksToMention = incompleteTasks.isEmpty ? tasks : incompleteTasks
        let reminderMessage = ReminderMessageBuilder.build(for: tasksToMention)

        let content = UNMutableNotificationContent()
        content.title = "KeepingUp"
        content.body = reminderMessage.notificationBody
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: notificationIdentifier(for: reason),
            content: content,
            trigger: nil
        )

        debugLog("Scheduling notification only for \(reason.debugName)")
        await withCheckedContinuation { continuation in
            notificationCenter.add(request) { error in
                if let error {
                    self.debugLog("Notification skipped: delivery failed with \(error.localizedDescription)")
                } else {
                    self.debugLog("Notification scheduled")
                }
                continuation.resume()
            }
        }
    }

    private func shouldDeliverReminder(for reason: ReminderReason) -> Bool {
        let cooldownDisabled = defaults.bool(forKey: developerModeKey)
            && defaults.bool(forKey: reminderCooldownDisabledKey)
        debugLog("Cooldown disabled flag value: \(cooldownDisabled)")

        if cooldownDisabled {
            debugLog("Popup shown path allowed: cooldown suppression fully bypassed")
            return true
        }

        guard let lastReminderDate = defaults.object(forKey: lastReminderKey) as? Date else {
            debugLog("Popup shown path allowed: no previous reminder timestamp")
            return true
        }

        let savedCooldownMinutes = defaults.integer(forKey: reminderCooldownMinutesKey)
        let cooldownMinutes = savedCooldownMinutes > 0 ? savedCooldownMinutes : 240
        let reminderCooldown = TimeInterval(cooldownMinutes * 60)
        let elapsed = Date().timeIntervalSince(lastReminderDate)
        debugLog("Suppression flags: developerMode=\(defaults.bool(forKey: developerModeKey)) cooldownMinutes=\(cooldownMinutes) elapsed=\(elapsed)")

        guard elapsed >= reminderCooldown else {
            debugLog("Popup skipped: cooldown active for reason \(reason.debugName)")
            return false
        }

        debugLog("Popup shown path allowed: cooldown elapsed for reason \(reason.debugName)")
        return true
    }

    private func notificationIdentifier(for reason: ReminderReason) -> String {
        // Use a fresh identifier so repeated unlock reminders are delivered again
        // instead of being treated as a replacement for an older notification.
        "\(reason.identifier).\(UUID().uuidString)"
    }

    private func selectedReminderStyle() -> ReminderPresentationStyle {
        guard
            let rawValue = defaults.string(forKey: reminderStyleKey),
            let style = ReminderPresentationStyle(rawValue: rawValue)
        else {
            return .popupWindow
        }

        return style
    }

    private func configuredPopupAutoDismissSeconds(for reason: ReminderReason) -> Int {
        let savedValue = defaults.integer(forKey: popupAutoDismissSecondsKey)
        let baseValue = max(0, savedValue)

        switch reason {
        case .appLaunch, .sessionBecameActive, .wokeFromSleep, .screenUnlocked:
            guard baseValue > 0 else { return 0 }
            return max(baseValue, 7)
        case .appDidBecomeActive, .developerTest:
            return baseValue
        }
    }

    private func configuredNotificationTextSize() -> NotificationTextSize {
        guard
            let rawValue = defaults.string(forKey: notificationTextSizeKey),
            let textSize = NotificationTextSize(rawValue: rawValue)
        else {
            return .medium
        }

        return textSize
    }

    private func debugLog(_ message: String) {
        print("[KeepingUp][Reminder] \(message)")
    }
}
