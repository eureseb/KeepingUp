//
//  DueAlertService.swift
//  KeepingUp
//
//  Created by Codex on 3/23/26.
//

import Foundation
import UserNotifications

protocol UserNotificationScheduling {
    func pendingRequests() async -> [UNNotificationRequest]
    func add(_ request: UNNotificationRequest) async
    func removePendingNotificationRequests(withIdentifiers identifiers: [String])
}

struct LiveUserNotificationScheduler: UserNotificationScheduling {
    let center: UNUserNotificationCenter

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    func pendingRequests() async -> [UNNotificationRequest] {
        await withCheckedContinuation { continuation in
            center.getPendingNotificationRequests { requests in
                continuation.resume(returning: requests)
            }
        }
    }

    func add(_ request: UNNotificationRequest) async {
        await withCheckedContinuation { continuation in
            center.add(request) { _ in
                continuation.resume()
            }
        }
    }

    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }
}

final class DueAlertService {
    private let scheduler: UserNotificationScheduling
    private let calendar: Calendar
    private let nowProvider: () -> Date

    init(
        scheduler: UserNotificationScheduling = LiveUserNotificationScheduler(),
        calendar: Calendar = .current,
        nowProvider: @escaping () -> Date = Date.init
    ) {
        self.scheduler = scheduler
        self.calendar = calendar
        self.nowProvider = nowProvider
    }

    func syncDueAlerts(for tasks: [StartupTask], enabled: Bool) async {
        let existingDueAlertIdentifiers = await scheduler.pendingRequests()
            .map(\.identifier)
            .filter { $0.hasPrefix(Self.identifierPrefix) }

        if !existingDueAlertIdentifiers.isEmpty {
            scheduler.removePendingNotificationRequests(withIdentifiers: existingDueAlertIdentifiers)
        }

        guard enabled else { return }

        let now = nowProvider()
        for task in tasks {
            guard let triggerDate = TaskScheduling.dueAlertTriggerDate(for: task, now: now, calendar: calendar) else {
                continue
            }

            let content = UNMutableNotificationContent()
            content.title = "KeepingUp"
            content.body = "\(task.title) is almost due."
            content.sound = .default

            let components = calendar.dateComponents(
                [.year, .month, .day, .hour, .minute, .second],
                from: triggerDate
            )
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let request = UNNotificationRequest(
                identifier: Self.identifier(for: task),
                content: content,
                trigger: trigger
            )
            await scheduler.add(request)
        }
    }

    static func identifier(for task: StartupTask) -> String {
        "\(identifierPrefix).\(task.id.uuidString)"
    }

    private static let identifierPrefix = "keepingup.dueAlert"
}
