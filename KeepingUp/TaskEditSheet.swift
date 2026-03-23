//
//  TaskEditSheet.swift
//  KeepingUp
//
//  Created by Codex on 3/23/26.
//

import SwiftUI

struct TaskEditorPanel: View {
    let task: StartupTask
    @ObservedObject var viewModel: ChecklistViewModel
    let onCancel: () -> Void
    let onSave: () -> Void
    @State private var draft: TaskEditorDraft

    init(
        task: StartupTask,
        viewModel: ChecklistViewModel,
        onCancel: @escaping () -> Void,
        onSave: @escaping () -> Void
    ) {
        self.task = task
        self.viewModel = viewModel
        self.onCancel = onCancel
        self.onSave = onSave
        _draft = State(initialValue: TaskEditorDraft(task: task))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Edit Task")
                        .font(.title3.weight(.semibold))
                    Text("Adjust the details without leaving the menu bar.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button("Cancel", action: onCancel)
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
            }

            TextField("Task title", text: $draft.title)
                .textFieldStyle(.roundedBorder)

            VStack(alignment: .leading, spacing: 12) {
                Toggle("Set a deadline", isOn: $draft.hasDueDate.animation())

                if draft.hasDueDate {
                    DatePicker(
                        "Deadline",
                        selection: $draft.dueDate,
                        displayedComponents: draft.hasExplicitDueTime ? [.date, .hourAndMinute] : [.date]
                    )

                    Toggle("Include a specific time", isOn: $draft.hasExplicitDueTime)

                    Button("Remove deadline") {
                        draft.hasDueDate = false
                        draft.hasExplicitDueTime = false
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Priority")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Picker("Priority", selection: $draft.priority) {
                    ForEach(TaskPriority.allCases) { priority in
                        Text(priority.title).tag(priority)
                    }
                }
                .pickerStyle(.segmented)
            }

            Toggle("Pin this task", isOn: $draft.isPinned)

            HStack {
                Spacer()

                Button("Save") {
                    let saved = viewModel.saveTaskEdits(
                        taskID: task.id,
                        title: draft.title,
                        dueDate: draft.preparedDueDate,
                        hasExplicitDueTime: draft.hasExplicitDueTime,
                        priority: draft.priority,
                        isPinned: draft.isPinned
                    )

                    if saved {
                        onSave()
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(16)
        .background(Color(NSColor.windowBackgroundColor), in: RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Color.secondary.opacity(0.15))
        }
    }
}

private struct TaskEditorDraft {
    var title: String
    var hasDueDate: Bool
    var dueDate: Date
    var hasExplicitDueTime: Bool
    var priority: TaskPriority
    var isPinned: Bool

    init(task: StartupTask) {
        title = task.title
        hasDueDate = task.dueDate != nil
        dueDate = task.dueDate ?? .now
        hasExplicitDueTime = task.hasExplicitDueTime
        priority = task.priority
        isPinned = task.isPinned
    }

    var preparedDueDate: Date? {
        guard hasDueDate else { return nil }

        if hasExplicitDueTime {
            return dueDate
        }

        return Calendar.current.startOfDay(for: dueDate)
    }
}
