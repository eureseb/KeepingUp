//
//  ContentView.swift
//  KeepingUp
//
//  Created by EureseB on 3/20/26.
//

import SwiftUI
import UniformTypeIdentifiers
import AppKit

struct ContentView: View {
    /// The shared view model is created once in the app entry point and reused here.
    @ObservedObject var viewModel: ChecklistViewModel
    @State private var draggedTaskID: UUID?
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Today")
                        .font(.headline)
                    Text(summaryText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    NSApp.activate(ignoringOtherApps: true)
                    openSettings()
                } label: {
                    Image(systemName: "gearshape")
                        .font(.body)
                }
                .buttonStyle(.plain)
                .help("Open Settings")
            }

            Group {
                if viewModel.tasks.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "checklist")
                            .font(.system(size: 28))
                            .foregroundStyle(.secondary)
                        Text("No tasks yet")
                            .font(.headline)
                        Text("Add your first task below.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 8) {
                            ForEach(viewModel.tasks) { task in
                                taskRow(task)
                                    .onDrag {
                                        draggedTaskID = task.id
                                        return NSItemProvider(object: task.id.uuidString as NSString)
                                    }
                                    .onDrop(
                                        of: [UTType.text],
                                        delegate: TaskDropDelegate(
                                            targetTask: task,
                                            draggedTaskID: $draggedTaskID,
                                            viewModel: viewModel
                                        )
                                    )
                            }
                        }
                    }
                    .frame(maxHeight: 220)
                }
            }

            Divider()

            HStack(spacing: 8) {
                TextField("Add a task", text: $viewModel.newTaskTitle)
                    .onSubmit(viewModel.addTask)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityLabel("New task title")
                    .accessibilityIdentifier("newTaskField")

                Button {
                    viewModel.addTask()
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("addTaskButton")
                .disabled(viewModel.newTaskTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            Divider()
        }
        .padding(14)
        .frame(width: 360)
    }

    private var summaryText: String {
        let remaining = viewModel.incompleteTaskCount
        if remaining == 0 {
            return "Everything is checked off."
        }

        return remaining == 1 ? "1 task left" : "\(remaining) tasks left"
    }

    private func taskRow(_ task: StartupTask) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "line.3.horizontal")
                .font(.caption)
                .foregroundStyle(.tertiary)

            Button {
                viewModel.toggleCompletion(for: task)
            } label: {
                Image(systemName: task.isComplete ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(taskTintColor(for: task))
            }
            .buttonStyle(.plain)

            Text(task.title)
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineLimit(2)
                .strikethrough(task.isComplete)
                .foregroundStyle(taskTextColor(for: task))

            Button(role: .destructive) {
                viewModel.remove(task: task)
            } label: {
                Image(systemName: "trash")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Delete task")
        }
        .padding(.vertical, 2)
    }

    private func taskTintColor(for task: StartupTask) -> Color {
        if task.isComplete {
            return .green
        }

        return taskIsOneDayOld(task) ? .red : .secondary
    }

    private func taskTextColor(for task: StartupTask) -> Color {
        if task.isComplete {
            return .green
        }

        return taskIsOneDayOld(task) ? .red : .primary
    }

    private func taskIsOneDayOld(_ task: StartupTask) -> Bool {
        guard !task.isComplete else { return false }

        let calendar = Calendar.current
        let createdDay = calendar.startOfDay(for: task.createdAt)
        let today = calendar.startOfDay(for: .now)
        let ageInDays = calendar.dateComponents([.day], from: createdDay, to: today).day ?? 0

        return ageInDays >= 1
    }
}

private struct TaskDropDelegate: DropDelegate {
    let targetTask: StartupTask
    @Binding var draggedTaskID: UUID?
    let viewModel: ChecklistViewModel

    func dropEntered(info: DropInfo) {
        guard let draggedTaskID else { return }
        viewModel.moveTask(withID: draggedTaskID, beforeTaskWithID: targetTask.id)
    }

    func performDrop(info: DropInfo) -> Bool {
        draggedTaskID = nil
        return true
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func validateDrop(info: DropInfo) -> Bool {
        draggedTaskID != nil
    }
}
