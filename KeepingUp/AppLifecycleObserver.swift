//
//  AppLifecycleObserver.swift
//  KeepingUp
//
//  Created by Codex on 3/20/26.
//

import AppKit
import Foundation

@MainActor
final class AppLifecycleObserver {
    private let workspaceNotificationCenter = NSWorkspace.shared.notificationCenter
    private let distributedNotificationCenter = DistributedNotificationCenter.default()
    private let onReminderEvent: (ReminderReason) -> Void

    private var workspaceObservers: [NSObjectProtocol] = []
    private var distributedObservers: [NSObjectProtocol] = []
    private var hasRegisteredObservers = false

    init(onReminderEvent: @escaping (ReminderReason) -> Void) {
        self.onReminderEvent = onReminderEvent
    }

    func start() {
        guard !hasRegisteredObservers else {
            debugLog("Observers already registered")
            return
        }

        hasRegisteredObservers = true
        debugLog("Observers registered")

        workspaceObservers = [
            workspaceNotificationCenter.addObserver(
                forName: NSWorkspace.sessionDidBecomeActiveNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated {
                    guard let self else { return }
                    self.debugLog("sessionDidBecomeActive fired")
                    self.onReminderEvent(.sessionBecameActive)
                }
            },
            workspaceNotificationCenter.addObserver(
                forName: NSWorkspace.didWakeNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated {
                    guard let self else { return }
                    self.debugLog("didWake fired")
                    self.onReminderEvent(.wokeFromSleep)
                }
            }
        ]

        distributedObservers = [
            distributedNotificationCenter.addObserver(
                forName: Notification.Name("com.apple.screenIsUnlocked"),
                object: nil,
                queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated {
                    guard let self else { return }
                    self.debugLog("distributed screen unlock fired")
                    self.onReminderEvent(.screenUnlocked)
                }
            }
        ]
    }

    private func debugLog(_ message: String) {
        print("[KeepingUp][Lifecycle] \(message)")
    }

    deinit {
        for observer in workspaceObservers {
            workspaceNotificationCenter.removeObserver(observer)
        }
        for observer in distributedObservers {
            distributedNotificationCenter.removeObserver(observer)
        }
    }
}
