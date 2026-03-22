//
//  ReminderPopupController.swift
//  KeepingUp
//
//  Created by Codex on 3/20/26.
//

import AppKit
import SwiftUI

@MainActor
final class ReminderPopupController: NSObject, NSWindowDelegate {
    private let collapsedHeights: [NotificationTextSize: CGFloat] = [
        .small: 116,
        .medium: 132,
        .large: 152
    ]
    private let expandedHeights: [NotificationTextSize: CGFloat] = [
        .small: 208,
        .medium: 228,
        .large: 248
    ]
    private var panel: NSPanel?
    private var autoDismissTimer: Timer?
    private var lastShowDate: Date?
    private var isHovering = false
    private var isExpanded = false
    private var pendingAutoDismissSeconds: Int?
    private var currentTextSize: NotificationTextSize = .medium
    private var pendingPanelSizeWorkItem: DispatchWorkItem?
    private var lastAppliedPanelSize: NSSize?

    func show(tasks: [StartupTask], autoDismissSeconds: Int, textSize: NotificationTextSize) {
        debugLog("popup show requested")
        let visibleTasks = tasks.filter { !$0.isComplete }
        let tasksToShow = visibleTasks.isEmpty ? tasks : visibleTasks

        guard !tasksToShow.isEmpty else {
            debugLog("popup skipped: no tasks to show")
            return
        }

        invalidateDismissTimer()
        pendingAutoDismissSeconds = nil
        isExpanded = false
        currentTextSize = textSize

        let message = popupMessage(for: tasksToShow)
        let reminderView = ReminderPopupView(
            tasks: tasksToShow,
            primaryMessage: message.primary,
            secondaryMessage: message.secondary,
            textSize: textSize,
            onDismiss: { [weak self] in
                self?.dismiss(reason: "tap")
            },
            onHoverChanged: { [weak self] isHovering in
                self?.handleHoverChanged(isHovering, autoDismissSeconds: autoDismissSeconds)
            },
            onExpansionChanged: { [weak self] isExpanded in
                self?.handleExpansionChanged(isExpanded, autoDismissSeconds: autoDismissSeconds)
            }
        )

        let isVisible = panel?.isVisible ?? false
        let isDuplicateTrigger = isVisible && isDuplicateShowRequest()

        if let panel {
            debugLog("popup reused")
            let hostingView = NSHostingView(rootView: reminderView)
            hostingView.wantsLayer = true
            panel.contentView = hostingView
            show(panel: panel)
        } else {
            let panel = makePanel(with: reminderView)
            self.panel = panel
            debugLog("popup created")
            show(panel: panel)
        }

        schedulePanelResize(recenter: !isDuplicateTrigger)
        if isDuplicateTrigger {
            debugLog("popup duplicate trigger coalesced")
        }
        isHovering = false
        lastShowDate = Date()
        scheduleAutoDismiss(after: autoDismissSeconds)
    }

    func dismiss(reason: String) {
        invalidateDismissTimer()

        guard let panel else { return }
        debugLog("popup closed: \(reason)")
        animateOut(panel: panel) {
            panel.orderOut(nil)
        }
    }

    private func makePanel(with rootView: ReminderPopupView) -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 388, height: 128),
            styleMask: [.nonactivatingPanel, .borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.becomesKeyOnlyIfNeeded = true
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isMovableByWindowBackground = true
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.delegate = self
        let hostingView = NSHostingView(rootView: rootView)
        hostingView.wantsLayer = true
        panel.contentView = hostingView
        panel.setContentSize(targetPanelSize())
        lastAppliedPanelSize = targetPanelSize()
        center(panel: panel)
        return panel
    }

    private func show(panel: NSPanel) {
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        animateIn(panel: panel)
        debugLog("popup shown")
    }

    private func center(panel: NSPanel) {
        let screenFrame = NSScreen.main?.visibleFrame ?? NSScreen.screens.first?.visibleFrame
        guard let screenFrame else { return }

        let originX = screenFrame.midX - (panel.frame.width / 2)
        let originY = screenFrame.midY - (panel.frame.height / 2)
        panel.setFrameOrigin(NSPoint(x: originX, y: originY))
    }

    private func scheduleAutoDismiss(after seconds: Int) {
        invalidateDismissTimer()
        debugLog("auto-dismiss duration used: \(seconds)")

        guard seconds > 0 else {
            debugLog("popup auto-dismiss disabled")
            return
        }

        let timer = Timer.scheduledTimer(withTimeInterval: TimeInterval(seconds), repeats: false) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.debugLog("timer fired")
                self.dismiss(reason: "auto-dismiss")
            }
        }
        autoDismissTimer = timer
        RunLoop.main.add(timer, forMode: .common)
        debugLog("timer created for \(seconds) seconds")
    }

    func windowWillClose(_ notification: Notification) {
        debugLog("popup closed: windowWillClose")
        invalidateDismissTimer()
        pendingPanelSizeWorkItem?.cancel()
        pendingPanelSizeWorkItem = nil
        panel = nil
        lastAppliedPanelSize = nil
    }

    private func invalidateDismissTimer() {
        autoDismissTimer?.invalidate()
        autoDismissTimer = nil
    }

    private func handleHoverChanged(_ isHovering: Bool, autoDismissSeconds: Int) {
        self.isHovering = isHovering

        guard autoDismissSeconds > 0 else { return }

        if isHovering {
            pendingAutoDismissSeconds = autoDismissSeconds
            invalidateDismissTimer()
            debugLog("timer paused while hovered")
        } else if !isExpanded, let pendingAutoDismissSeconds {
            self.pendingAutoDismissSeconds = nil
            scheduleAutoDismiss(after: pendingAutoDismissSeconds)
            debugLog("timer resumed after hover")
        }
    }

    private func handleExpansionChanged(_ isExpanded: Bool, autoDismissSeconds: Int) {
        self.isExpanded = isExpanded

        schedulePanelResize(recenter: false)

        guard autoDismissSeconds > 0 else { return }

        if isExpanded {
            pendingAutoDismissSeconds = max(autoDismissSeconds, 10)
            invalidateDismissTimer()
            debugLog("timer paused while expanded")
        } else if !isHovering, let pendingAutoDismissSeconds {
            self.pendingAutoDismissSeconds = nil
            scheduleAutoDismiss(after: pendingAutoDismissSeconds)
            debugLog("timer resumed after collapse")
        }
    }

    private func popupMessage(for tasks: [StartupTask]) -> (primary: String, secondary: String?) {
        if tasks.count == 1, let task = tasks.first {
            return ("Good morning. Start with: \(task.title)", nil)
        }

        if let firstTask = tasks.first {
            return ("Good morning. Start with: \(firstTask.title)", "You have \(tasks.count) tasks today.")
        }

        return ("Good morning", "Open the menu bar when you're ready.")
    }

    private func isDuplicateShowRequest() -> Bool {
        guard let lastShowDate else { return false }
        return Date().timeIntervalSince(lastShowDate) < 0.75
    }

    private func schedulePanelResize(recenter: Bool) {
        pendingPanelSizeWorkItem?.cancel()

        let targetSize = targetPanelSize()
        let workItem = DispatchWorkItem { [weak self] in
            guard let self, let panel = self.panel else { return }

            let sizeChanged: Bool
            if let lastAppliedPanelSize = self.lastAppliedPanelSize,
               abs(lastAppliedPanelSize.width - targetSize.width) < 1,
               abs(lastAppliedPanelSize.height - targetSize.height) < 1 {
                return
            } else {
                sizeChanged = true
            }

            panel.setContentSize(targetSize)
            self.lastAppliedPanelSize = targetSize
            if recenter && sizeChanged {
                self.center(panel: panel)
            }
        }

        pendingPanelSizeWorkItem = workItem
        DispatchQueue.main.async(execute: workItem)
    }

    private func targetPanelSize() -> NSSize {
        let width: CGFloat = switch currentTextSize {
        case .small: 372
        case .medium: 392
        case .large: 408
        }

        let height = isExpanded
            ? (expandedHeights[currentTextSize] ?? 228)
            : (collapsedHeights[currentTextSize] ?? 132)

        return NSSize(width: width, height: height)
    }

    private func animateIn(panel: NSPanel) {
        panel.contentView?.wantsLayer = true
        panel.contentView?.layer?.transform = CATransform3DMakeScale(0.97, 0.97, 1)
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.18
            panel.animator().alphaValue = 1
            panel.contentView?.animator().layer?.transform = CATransform3DIdentity
        }
    }

    private func animateOut(panel: NSPanel, completion: @escaping () -> Void) {
        NSAnimationContext.runAnimationGroup(
            { context in
                context.duration = 0.16
                panel.animator().alphaValue = 0
                panel.contentView?.animator().layer?.transform = CATransform3DMakeScale(0.98, 0.98, 1)
            },
            completionHandler: completion
        )
    }

    private func debugLog(_ message: String) {
        print("[KeepingUp][Popup] \(message)")
    }
}
