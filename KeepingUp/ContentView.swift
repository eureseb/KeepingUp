//
//  ContentView.swift
//  KeepingUp
//
//  Created by EureseB on 3/20/26.
//

import AppKit
import SwiftUI

struct ContentView: View {
    @ObservedObject var viewModel: ChecklistViewModel
    @Environment(\.openSettings) private var openSettings
    @State private var editingTaskID: UUID?
    @State private var interactionMode: TaskListInteractionMode = .normal
    @State private var selectedTaskIDs: Set<UUID> = []
    @State private var pendingDeleteScope: PendingDeleteScope?
    @State private var priorityPickerTaskID: UUID?
    @State private var renamingTaskID: UUID?
    @State private var renamingTitle = ""
    @State private var showAddFeedback = false
    @State private var addFeedbackWorkItem: DispatchWorkItem?
    @State private var showCompletionFeedback = false
    @State private var completionFeedbackWorkItem: DispatchWorkItem?
    @State private var showAllDoneFeedback = false
    @State private var allDoneFeedbackWorkItem: DispatchWorkItem?
    @State private var completionPulseTaskIDs: Set<UUID> = []
    @State private var completionFlashTaskIDs: Set<UUID> = []
    @FocusState private var focusedRenameTaskID: UUID?
    private let titleLengthWarningThreshold = 44

    private enum PopoverUI {
        static let controlHeight: CGFloat = 28
        static let controlCornerRadius: CGFloat = 10
        static let chipHorizontalPadding: CGFloat = 10
        static let controlSpacing: CGFloat = 6
        static let chipFont: Font = .caption.weight(.medium)
        static let chipIconSize: CGFloat = 12
        static let topControlSize: CGFloat = 28
        static let iconButtonSize: CGFloat = 24
        static let iconButtonCornerRadius: CGFloat = 8
        static let leadingControlSize: CGFloat = 24
        static let leadingControlIconSize: CGFloat = 22
    }

    private enum ChipVisualStyle {
        case standard
        case destructive
    }

    init(viewModel: ChecklistViewModel) {
        self.viewModel = viewModel
    }

    private var editingTask: StartupTask? {
        guard let editingTaskID else { return nil }
        return viewModel.tasks.first(where: { $0.id == editingTaskID })
    }

    private var pendingBulkDeletionCount: Int {
        guard case let .bulk(taskIDs) = pendingDeleteScope else { return 0 }
        return viewModel.tasks.filter { taskIDs.contains($0.id) }.count
    }

    private var trimmedNewTaskTitle: String {
        viewModel.newTaskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var shouldShowLongTitleWarning: Bool {
        trimmedNewTaskTitle.count >= titleLengthWarningThreshold
    }

    private var isSelecting: Bool {
        interactionMode == .selecting
    }

    private var isReorderingFallback: Bool {
        interactionMode == .reorderingFallback
    }

    private var activeSections: [TaskListSectionModel] {
        switch viewModel.taskPresentationMode {
        case .browse:
            return viewModel.browseSections
        case .focus:
            return viewModel.focusSections
        }
    }

    var body: some View {
        ZStack {
            VStack(alignment: .leading, spacing: 8) {
                header
                listModeControls

                Group {
                    if let task = editingTask {
                        editorPanel(task)
                    } else if viewModel.tasks.isEmpty {
                        emptyState
                    } else {
                        taskContent
                    }
                }

                Divider()

                if editingTask == nil {
                    addTaskRow
                    Divider()
                }
            }
            .padding(12)
            .frame(width: 420)

            if pendingDeleteScope != nil {
                deleteConfirmationOverlay
            }
        }
        .onAppear {
            viewModel.resetPopoverFilterToDefault()
        }
        .onChange(of: viewModel.incompleteTaskCount) { oldValue, newValue in
            guard oldValue > 0, newValue == 0 else { return }
            showAllDoneCelebration()
        }
    }

    private var deleteConfirmationOverlay: some View {
        ZStack {
            Color.black.opacity(0.12)
                .ignoresSafeArea()
                .onTapGesture {
                    pendingDeleteScope = nil
                }

            VStack(alignment: .leading, spacing: 12) {
                Text(deleteConfirmationText)
                    .font(.headline)
                    .lineLimit(2)

                Text("This action can’t be undone.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    Spacer(minLength: 0)
                    Button("Cancel") {
                        pendingDeleteScope = nil
                    }
                    .buttonStyle(.bordered)

                    Button("Delete", role: .destructive) {
                        confirmPendingDelete()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding(14)
            .frame(maxWidth: 320, alignment: .leading)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(Color.primary.opacity(0.12))
            )
            .shadow(radius: 16, y: 8)
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 0) {
                Text(viewModel.taskFocusFilter.title)
                    .font(.headline)
            }

            Spacer()

            focusModeSwitch

            Button {
                NSApp.activate(ignoringOtherApps: true)
                openSettings()
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: PopoverUI.chipIconSize, weight: .semibold))
                    .foregroundStyle(.primary.opacity(0.88))
                    .frame(width: PopoverUI.topControlSize, height: PopoverUI.topControlSize)
                    .background(Color.secondary.opacity(0.14), in: Circle())
            }
            .buttonStyle(.plain)
            .help("Open Settings")
        }
    }

    private var focusModeSwitch: some View {
        Button {
            guard viewModel.isFocusModeAvailable else { return }
            let nextMode: TaskPresentationMode = viewModel.taskPresentationMode == .focus ? .browse : .focus
            withAnimation(.easeInOut(duration: 0.2)) {
                viewModel.setTaskPresentationMode(nextMode)
            }
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: PopoverUI.controlCornerRadius)
                    .fill(viewModel.taskPresentationMode == .focus ? Color.accentColor.opacity(0.7) : Color.secondary.opacity(0.2))
                    .frame(width: 50, height: PopoverUI.topControlSize)

                HStack {
                    if viewModel.taskPresentationMode == .focus {
                        Spacer()
                    }

                    Circle()
                        .fill(Color.white)
                        .frame(width: 24, height: 24)
                        .overlay {
                            if viewModel.taskPresentationMode == .focus {
                                Image(systemName: "moon.fill")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(Color.accentColor)
                            }
                        }

                    if viewModel.taskPresentationMode != .focus {
                        Spacer()
                    }
                }
                .padding(.horizontal, 2)
                .frame(width: 50, height: PopoverUI.topControlSize)
            }
        }
        .buttonStyle(.plain)
        .opacity(viewModel.isFocusModeAvailable ? 1 : 0.45)
        .help(viewModel.isFocusModeAvailable ? "Toggle Focus mode" : "Focus is available for Today tasks only")
    }

    private var listModeControls: some View {
        HStack(alignment: .center, spacing: PopoverUI.controlSpacing) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: PopoverUI.controlSpacing) {
                    modeChip(
                        title: "Upcoming",
                        systemImage: "clock",
                        isActive: viewModel.taskFocusFilter == .upcoming
                    ) {
                        viewModel.toggleUpcomingQuickFilter()
                    }

                    modeChip(
                        title: isSelecting ? "Done" : "Select",
                        systemImage: isSelecting ? "checkmark.circle.fill" : "checklist",
                        isActive: isSelecting
                    ) {
                        if isSelecting {
                            exitSelectionMode()
                        } else {
                            enterSelectionMode()
                        }
                    }

                    if viewModel.taskPresentationMode == .browse {
                        modeChip(
                            title: isReorderingFallback ? "Done" : "Reorder",
                            systemImage: "arrow.up.arrow.down.circle",
                            isActive: isReorderingFallback
                        ) {
                            if isReorderingFallback {
                                interactionMode = .normal
                            } else {
                                beginReorderFallbackMode()
                            }
                        }
                    }

                    if isSelecting, !selectedTaskIDs.isEmpty {
                        modeChip(
                            title: "Delete (\(selectedTaskIDs.count))",
                            systemImage: "trash",
                            isActive: true,
                            visualStyle: .destructive
                        ) {
                            requestBulkDelete()
                        }
                    }
                }
            }

            if isSelecting {
                Text("\(selectedTaskIDs.count) selected")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }
        }
        .padding(.top, 2)
    }

    private var emptyState: some View {
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
    }

    private var taskContent: some View {
        Group {
            if viewModel.taskPresentationMode == .focus && viewModel.focusTasks.isEmpty {
                focusEmptyState
            } else {
                ScrollView {
                    if viewModel.taskPresentationMode == .browse {
                        LazyVStack(alignment: .leading, spacing: 14) {
                            ForEach(activeSections) { section in
                                taskSection(section)
                            }
                        }
                        .padding(.vertical, 2)
                    } else {
                        focusTaskList
                            .padding(.vertical, 2)
                    }
                }
                .frame(maxHeight: 340)
            }
        }
    }

    private var focusTaskList: some View {
        LazyVStack(alignment: .leading, spacing: 8) {
            ForEach(viewModel.focusTasks) { task in
                focusTaskRow(task)
            }
        }
    }

    private func taskSection(_ section: TaskListSectionModel) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(section.title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            ForEach(section.tasks) { task in
                browseTaskRow(task, in: section)
            }
        }
    }

    private func browseTaskRow(_ task: StartupTask, in section: TaskListSectionModel) -> some View {
        HStack(spacing: 10) {
            leadingControl(for: task)

            browseRowBody(task, sectionID: section.id)

            if isReorderingFallback, section.allowsManualReorder {
                reorderButtons(task: task, in: section)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .scaleEffect(completionPulseTaskIDs.contains(task.id) ? 1.01 : 1)
        .background(taskBackground(for: task, emphasis: 0.7), in: RoundedRectangle(cornerRadius: 10))
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(taskAccentColor(for: task).opacity(0.12))
        }
        .overlay {
            if completionFlashTaskIDs.contains(task.id) {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.green.opacity(0.22))
                    .transition(.opacity)
            }
        }
        .overlay {
            if isSelecting, selectedTaskIDs.contains(task.id) {
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(Color.accentColor, lineWidth: 2)
            }
        }
        .contextMenu {
            Button("Edit Task") {
                beginEditing(task)
            }
            Button("Rename") {
                beginRenaming(task)
            }
            Divider()
            Button("Delete Task", role: .destructive) {
                requestDelete(task)
            }
        }
    }

    private func focusTaskRow(_ task: StartupTask) -> some View {
        HStack(spacing: 10) {
            leadingControl(for: task)

            focusRowBody(task)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .scaleEffect(completionPulseTaskIDs.contains(task.id) ? 1.01 : 1)
        .background(taskBackground(for: task, emphasis: 0.55), in: RoundedRectangle(cornerRadius: 10))
        .overlay {
            if completionFlashTaskIDs.contains(task.id) {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.green.opacity(0.2))
                    .transition(.opacity)
            }
        }
        .contextMenu {
            Button("Edit Task") {
                beginEditing(task)
            }
            Button("Rename") {
                beginRenaming(task)
            }
            Divider()
            Button("Delete Task", role: .destructive) {
                requestDelete(task)
            }
        }
        .overlay {
            if isSelecting, selectedTaskIDs.contains(task.id) {
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(Color.accentColor, lineWidth: 2)
            }
        }
    }

    private var focusEmptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Nothing urgent for today")
                .font(.headline)
            Text("Switch back to standard view when you want to manage upcoming or unplanned tasks.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 12)
    }

    private func editorPanel(_ task: StartupTask) -> some View {
        TaskEditorPanel(
            task: task,
            viewModel: viewModel,
            onCancel: { editingTaskID = nil },
            onSave: { editingTaskID = nil }
        )
    }

    private var addTaskRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: PopoverUI.controlSpacing) {
                TextField("Add a task", text: $viewModel.newTaskTitle)
                    .onSubmit(submitNewTask)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityLabel("New task title")
                    .accessibilityIdentifier("newTaskField")

                Button {
                    submitNewTask()
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: PopoverUI.leadingControlIconSize))
                        .frame(width: PopoverUI.controlHeight, height: PopoverUI.controlHeight)
                        .background(Color.secondary.opacity(0.14), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("addTaskButton")
                .disabled(viewModel.newTaskTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            if shouldShowLongTitleWarning {
                Label("Long titles may be truncated in the task list.", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .transition(.opacity)
            }

            if showAddFeedback {
                Label("Added", systemImage: "checkmark.circle.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.green)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            if showCompletionFeedback {
                Label("Completed", systemImage: "checkmark.circle.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.green)
                    .transition(.opacity.combined(with: .scale))
            }

            if showAllDoneFeedback {
                Label("All tasks done", systemImage: "sparkles")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.mint)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Color.mint.opacity(0.14), in: Capsule())
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }
        }
        .animation(.easeOut(duration: 0.2), value: showAddFeedback)
        .animation(.easeOut(duration: 0.2), value: showCompletionFeedback)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: showAllDoneFeedback)
        .animation(.easeOut(duration: 0.2), value: shouldShowLongTitleWarning)
    }

    private func completionButton(for task: StartupTask) -> some View {
        Button {
            handleCompletionToggle(for: task)
        } label: {
            Image(systemName: task.isComplete ? "checkmark.circle.fill" : "circle")
                .font(.system(size: PopoverUI.leadingControlIconSize))
                .foregroundStyle(taskAccentColor(for: task))
                .frame(width: PopoverUI.leadingControlSize, height: PopoverUI.leadingControlSize)
        }
        .buttonStyle(.plain)
    }

    private func leadingControl(for task: StartupTask) -> some View {
        Group {
            if isSelecting {
                Button {
                    toggleTaskSelection(task.id)
                } label: {
                    Image(systemName: selectedTaskIDs.contains(task.id) ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: PopoverUI.leadingControlIconSize))
                        .foregroundStyle(selectedTaskIDs.contains(task.id) ? Color.accentColor : .secondary)
                        .frame(width: PopoverUI.leadingControlSize, height: PopoverUI.leadingControlSize)
                }
                .buttonStyle(.plain)
            } else {
                completionButton(for: task)
            }
        }
    }

    private func browseRowBody(_ task: StartupTask, sectionID: TaskSectionKind) -> some View {
        HStack(spacing: 8) {
            taskTitleView(task)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .onTapGesture {
                    if isSelecting {
                        toggleTaskSelection(task.id)
                    }
                }
            trailingMetadataContainer(for: task)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func focusRowBody(_ task: StartupTask) -> some View {
        Group {
            if renamingTaskID == task.id {
                renameField(for: task)
            } else {
                HoverMarqueeText(
                    text: task.title,
                    textColor: taskTextColor(for: task),
                    isStrikethrough: task.isComplete
                )
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .onTapGesture(count: 2) {
                        guard interactionMode == .normal else { return }
                        beginRenaming(task)
                    }
                    .onTapGesture {
                        if isSelecting {
                            toggleTaskSelection(task.id)
                        }
                    }
            }
        }
    }

    private func taskTitleView(_ task: StartupTask) -> some View {
        Group {
            if renamingTaskID == task.id {
                renameField(for: task)
            } else {
                HoverMarqueeText(
                    text: task.title,
                    textColor: taskTextColor(for: task),
                    isStrikethrough: task.isComplete
                )
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .onTapGesture(count: 2) {
                        guard interactionMode == .normal else { return }
                        beginRenaming(task)
                    }
                    .onTapGesture {
                        if isSelecting {
                            toggleTaskSelection(task.id)
                        }
                    }
            }
        }
    }

    private func renameField(for task: StartupTask) -> some View {
        TextField("Task title", text: $renamingTitle)
            .textFieldStyle(.roundedBorder)
            .focused($focusedRenameTaskID, equals: task.id)
            .onSubmit {
                commitRename(for: task)
            }
            .onExitCommand {
                cancelRename()
            }
            .onChange(of: focusedRenameTaskID) { _, focusedTaskID in
                guard renamingTaskID == task.id, focusedTaskID != task.id else { return }
                commitRename(for: task)
            }
    }

    private func trailingMetadata(for task: StartupTask) -> some View {
        HStack(spacing: 6) {
            deadlineButton(for: task)
            priorityButton(for: task)
            pinButton(for: task)
        }
    }

    private func trailingMetadataContainer(for task: StartupTask) -> some View {
        Group {
            if !task.isComplete {
                trailingMetadata(for: task)
            } else {
                trailingMetadata(for: task).opacity(0)
            }
        }
        .allowsHitTesting(!isSelecting)
        .opacity(isSelecting ? 0.75 : 1)
        .frame(width: 84, alignment: .trailing)
    }

    private func deadlineButton(for task: StartupTask) -> some View {
        Button {
            beginEditing(task)
        } label: {
            Image(systemName: task.dueDate == nil ? "calendar.badge.plus" : "calendar")
                .font(.system(size: PopoverUI.chipIconSize, weight: .semibold))
                .foregroundStyle(taskAccentColor(for: task))
                .frame(width: PopoverUI.iconButtonSize, height: PopoverUI.iconButtonSize)
                .background(taskAccentColor(for: task).opacity(0.12), in: RoundedRectangle(cornerRadius: PopoverUI.iconButtonCornerRadius))
        }
        .buttonStyle(.plain)
        .help(task.dueDate == nil ? "Add deadline" : viewModel.dueDateSummary(for: task))
    }

    private func priorityButton(for task: StartupTask) -> some View {
        Button {
            if priorityPickerTaskID == task.id {
                priorityPickerTaskID = nil
            } else {
                pendingDeleteScope = nil
                priorityPickerTaskID = task.id
            }
        } label: {
            Image(systemName: "flag.fill")
                .font(.system(size: PopoverUI.chipIconSize, weight: .semibold))
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(priorityTint(for: task.priority))
                .frame(width: PopoverUI.iconButtonSize, height: PopoverUI.iconButtonSize)
                .background(priorityTint(for: task.priority).opacity(0.18), in: RoundedRectangle(cornerRadius: PopoverUI.iconButtonCornerRadius))
        }
        .buttonStyle(.plain)
        .fixedSize()
        .help("Priority: \(task.priority.title)")
        .popover(
            isPresented: priorityPickerBinding(for: task.id),
            attachmentAnchor: .rect(.bounds),
            arrowEdge: .top
        ) {
            PriorityPickerCard(
                taskTitle: task.title,
                selectedPriority: task.priority,
                onSelect: { priority in
                    viewModel.setPriority(priority, for: task)
                    priorityPickerTaskID = nil
                },
                onDismiss: {
                    priorityPickerTaskID = nil
                }
            )
            .frame(width: 220)
            .padding(12)
        }
    }

    private func pinButton(for task: StartupTask) -> some View {
        Button {
            viewModel.togglePinned(for: task)
        } label: {
            Image(systemName: task.isPinned ? "pin.fill" : "pin")
                .font(.system(size: PopoverUI.chipIconSize, weight: .semibold))
                .foregroundStyle(task.isPinned ? Color.yellow : .secondary)
                .frame(width: PopoverUI.iconButtonSize, height: PopoverUI.iconButtonSize)
                .background((task.isPinned ? Color.yellow : Color.secondary).opacity(0.12), in: RoundedRectangle(cornerRadius: PopoverUI.iconButtonCornerRadius))
        }
        .buttonStyle(.plain)
        .help(task.isPinned ? "Pinned" : "Pin task")
    }

    private func modeChip(
        title: String,
        systemImage: String,
        isActive: Bool,
        visualStyle: ChipVisualStyle = .standard,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Image(systemName: systemImage)
                    .font(.system(size: PopoverUI.chipIconSize, weight: .semibold))
                Text(title)
                    .font(PopoverUI.chipFont)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .fixedSize(horizontal: true, vertical: false)
            }
                .frame(height: PopoverUI.controlHeight)
                .padding(.horizontal, PopoverUI.chipHorizontalPadding)
                .contentShape(RoundedRectangle(cornerRadius: PopoverUI.controlCornerRadius))
        }
        .buttonStyle(.plain)
        .foregroundStyle(chipForegroundColor(isActive: isActive, visualStyle: visualStyle))
        .background(
            RoundedRectangle(cornerRadius: PopoverUI.controlCornerRadius)
                .fill(chipBackgroundColor(isActive: isActive, visualStyle: visualStyle))
        )
        .overlay(
            RoundedRectangle(cornerRadius: PopoverUI.controlCornerRadius)
                .strokeBorder(Color.white.opacity(0.06))
        )
    }

    private func taskAccentColor(for task: StartupTask) -> Color {
        if task.isComplete {
            return .green
        }

        switch viewModel.dueState(for: task) {
        case .overdue:
            return .red
        case .nearDue:
            return .orange
        case .future:
            return .blue
        case .noDeadline:
            return .secondary
        }
    }

    private func taskTextColor(for task: StartupTask) -> Color {
        task.isComplete ? .green : .primary
    }

    private func taskBackground(for task: StartupTask, emphasis: Double = 1) -> Color {
        taskAccentColor(for: task).opacity(task.isComplete ? 0.12 : 0.09 * emphasis)
    }

    private func priorityTint(for priority: TaskPriority) -> Color {
        switch priority {
        case .high:
            return .red
        case .medium:
            return .orange
        case .low:
            return .green
        }
    }

    private func chipBackgroundColor(isActive: Bool, visualStyle: ChipVisualStyle) -> Color {
        switch visualStyle {
        case .standard:
            return isActive ? Color.accentColor.opacity(0.72) : Color.secondary.opacity(0.1)
        case .destructive:
            return isActive ? Color.red.opacity(0.7) : Color.red.opacity(0.16)
        }
    }

    private func chipForegroundColor(isActive: Bool, visualStyle: ChipVisualStyle) -> Color {
        switch visualStyle {
        case .standard:
            return isActive ? .white : .primary
        case .destructive:
            return isActive ? .white : .red
        }
    }

    private func priorityPickerBinding(for taskID: UUID) -> Binding<Bool> {
        Binding(
            get: { priorityPickerTaskID == taskID },
            set: { isPresented in
                priorityPickerTaskID = isPresented ? taskID : nil
            }
        )
    }

    private func beginEditing(_ task: StartupTask) {
        cancelRename()
        pendingDeleteScope = nil
        priorityPickerTaskID = nil
        selectedTaskIDs = []
        if isSelecting {
            interactionMode = .normal
        }
        editingTaskID = task.id
    }

    private func beginRenaming(_ task: StartupTask) {
        guard interactionMode == .normal else { return }
        editingTaskID = nil
        pendingDeleteScope = nil
        priorityPickerTaskID = nil
        renamingTaskID = task.id
        renamingTitle = task.title
        DispatchQueue.main.async {
            focusedRenameTaskID = task.id
        }
    }

    private func commitRename(for task: StartupTask) {
        let didRename = viewModel.renameTask(taskID: task.id, to: renamingTitle)
        if didRename {
            renamingTaskID = nil
            renamingTitle = ""
            focusedRenameTaskID = nil
        } else {
            DispatchQueue.main.async {
                focusedRenameTaskID = task.id
            }
        }
    }

    private func cancelRename() {
        renamingTaskID = nil
        renamingTitle = ""
        focusedRenameTaskID = nil
    }

    private func requestDelete(_ task: StartupTask) {
        if editingTaskID == task.id {
            editingTaskID = nil
        }
        if renamingTaskID == task.id {
            cancelRename()
        }
        priorityPickerTaskID = nil
        pendingDeleteScope = .single(task.id)
    }

    private func requestBulkDelete() {
        guard !selectedTaskIDs.isEmpty else { return }
        priorityPickerTaskID = nil
        pendingDeleteScope = .bulk(selectedTaskIDs)
    }

    private func confirmPendingDelete() {
        guard let deleteScope = pendingDeleteScope else { return }

        switch deleteScope {
        case let .single(taskID):
            viewModel.removeTasks(withIDs: [taskID])
        case let .bulk(taskIDs):
            viewModel.removeTasks(withIDs: taskIDs)
            selectedTaskIDs = []
        }

        editingTaskID = nil
        cancelRename()
        pendingDeleteScope = nil
        priorityPickerTaskID = nil
    }

    private var deleteConfirmationText: String {
        switch pendingDeleteScope {
        case let .single(taskID):
            let taskTitle = viewModel.tasks.first(where: { $0.id == taskID })?.title ?? "this task"
            return "Delete \"\(taskTitle)\"?"
        case .bulk:
            return "Delete \(pendingBulkDeletionCount) tasks?"
        case .none:
            return ""
        }
    }

    private func enterSelectionMode() {
        interactionMode = .selecting
        pendingDeleteScope = nil
        priorityPickerTaskID = nil
        cancelRename()
        editingTaskID = nil
    }

    private func exitSelectionMode() {
        interactionMode = .normal
        selectedTaskIDs = []
        pendingDeleteScope = nil
        priorityPickerTaskID = nil
    }

    private func beginReorderFallbackMode() {
        interactionMode = .reorderingFallback
        selectedTaskIDs = []
        pendingDeleteScope = nil
        priorityPickerTaskID = nil
        cancelRename()
    }

    private func submitNewTask() {
        let previousCount = viewModel.tasks.count
        viewModel.addTask()
        guard viewModel.tasks.count > previousCount else { return }
        showAddConfirmation()
    }

    private func showAddConfirmation() {
        addFeedbackWorkItem?.cancel()
        withAnimation {
            showAddFeedback = true
        }

        let workItem = DispatchWorkItem {
            withAnimation {
                showAddFeedback = false
            }
        }
        addFeedbackWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: workItem)
    }

    private func handleCompletionToggle(for task: StartupTask) {
        let wasComplete = task.isComplete
        viewModel.toggleCompletion(for: task)

        guard !wasComplete else { return }
        triggerTaskCompletionFeedback(taskID: task.id)
    }

    private func triggerTaskCompletionFeedback(taskID: UUID) {
        completionPulseTaskIDs.insert(taskID)
        completionFlashTaskIDs.insert(taskID)

        withAnimation(.easeOut(duration: 0.15)) {
            showCompletionFeedback = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                _ = completionPulseTaskIDs.remove(taskID)
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            withAnimation(.easeOut(duration: 0.2)) {
                _ = completionFlashTaskIDs.remove(taskID)
            }
        }

        completionFeedbackWorkItem?.cancel()
        let completionWorkItem = DispatchWorkItem {
            withAnimation(.easeIn(duration: 0.15)) {
                showCompletionFeedback = false
            }
        }
        completionFeedbackWorkItem = completionWorkItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.95, execute: completionWorkItem)
    }

    private func showAllDoneCelebration() {
        allDoneFeedbackWorkItem?.cancel()
        withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) {
            showAllDoneFeedback = true
        }

        let workItem = DispatchWorkItem {
            withAnimation(.easeInOut(duration: 0.2)) {
                showAllDoneFeedback = false
            }
        }
        allDoneFeedbackWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4, execute: workItem)
    }

    private func toggleTaskSelection(_ taskID: UUID) {
        if selectedTaskIDs.contains(taskID) {
            selectedTaskIDs.remove(taskID)
        } else {
            selectedTaskIDs.insert(taskID)
        }
    }

    private func reorderButtons(task: StartupTask, in section: TaskListSectionModel) -> some View {
        let tasks = section.tasks
        let currentIndex = tasks.firstIndex(where: { $0.id == task.id })

        return HStack(spacing: 4) {
            Button {
                moveTask(task, in: section.id, direction: .up)
            } label: {
                Image(systemName: "chevron.up")
            }
            .buttonStyle(.plain)
            .disabled(currentIndex == nil || currentIndex == 0)

            Button {
                moveTask(task, in: section.id, direction: .down)
            } label: {
                Image(systemName: "chevron.down")
            }
            .buttonStyle(.plain)
            .disabled(currentIndex == nil || currentIndex == tasks.count - 1)
        }
        .foregroundStyle(.secondary)
    }

    private func moveTask(_ task: StartupTask, in sectionID: TaskSectionKind, direction: ReorderDirection) {
        guard let section = activeSections.first(where: { $0.id == sectionID }) else { return }
        let tasks = section.tasks
        guard let currentIndex = tasks.firstIndex(where: { $0.id == task.id }) else { return }

        withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
            switch direction {
            case .up:
                guard currentIndex > 0 else { return }
                let targetID = tasks[currentIndex - 1].id
                viewModel.moveTask(withID: task.id, beforeTaskWithID: targetID, in: sectionID)
            case .down:
                guard currentIndex < tasks.count - 1 else { return }
                if currentIndex == tasks.count - 2 {
                    viewModel.moveTaskToEnd(withID: task.id, in: sectionID)
                } else {
                    let targetID = tasks[currentIndex + 2].id
                    viewModel.moveTask(withID: task.id, beforeTaskWithID: targetID, in: sectionID)
                }
            }
        }
    }

}

private enum TaskListInteractionMode {
    case normal
    case selecting
    case reorderingFallback
}

private enum PendingDeleteScope {
    case single(UUID)
    case bulk(Set<UUID>)
}

private enum ReorderDirection {
    case up
    case down
}

private struct PriorityPickerCard: View {
    let taskTitle: String
    let selectedPriority: TaskPriority
    let onSelect: (TaskPriority) -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Set Priority")
                .font(.headline)
            Text("for \"\(taskTitle)\"")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.tail)

            ForEach(TaskPriority.allCases) { priority in
                Button {
                    onSelect(priority)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "flag.fill")
                            .foregroundStyle(priorityColor(for: priority))
                            .frame(width: 14)
                        Text(priority.title)
                            .foregroundStyle(.primary)
                        Spacer(minLength: 0)
                        if priority == selectedPriority {
                            Image(systemName: "checkmark")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .contentShape(RoundedRectangle(cornerRadius: 9))
                }
                .buttonStyle(.plain)
                .background(
                    RoundedRectangle(cornerRadius: 9)
                        .fill(priority == selectedPriority ? Color.accentColor.opacity(0.16) : Color.secondary.opacity(0.12))
                )
            }

            Button("Cancel", role: .cancel) {
                onDismiss()
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.top, 2)
        }
    }

    private func priorityColor(for priority: TaskPriority) -> Color {
        switch priority {
        case .low:
            return .green
        case .medium:
            return .orange
        case .high:
            return .red
        }
    }
}

private struct HoverMarqueeText: View {
    let text: String
    let textColor: Color
    var isStrikethrough: Bool

    @State private var isHovered = false
    @State private var marqueeStartDate: Date?
    @State private var startWorkItem: DispatchWorkItem?
    @State private var containerWidth: CGFloat = 0
    @State private var textWidth: CGFloat = 0

    private let hoverDelay: TimeInterval = 0.45
    private let pauseDuration: TimeInterval = 0.55
    private let pointsPerSecond: Double = 34

    private var overflowWidth: CGFloat {
        max(0, textWidth - containerWidth)
    }

    private var canMarquee: Bool {
        overflowWidth > 6
    }

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width

            ZStack(alignment: .leading) {
                Text(text)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .strikethrough(isStrikethrough)
                    .foregroundStyle(textColor)
                    .opacity(shouldAnimate ? 0 : 1)

                if shouldAnimate {
                    TimelineView(.animation(paused: !shouldAnimate)) { context in
                        Text(text)
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                            .strikethrough(isStrikethrough)
                            .foregroundStyle(textColor)
                            .offset(x: marqueeOffset(at: context.date))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .clipped()
            .onAppear {
                if containerWidth != width {
                    containerWidth = width
                }
                recalculateTextWidth()
            }
            .onChange(of: width) { _, newWidth in
                containerWidth = newWidth
                stopMarquee(resetPosition: false)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 18)
        .overlay(alignment: .leading) {
            Text(text)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .hidden()
                .readWidth { width in
                    textWidth = width
                }
        }
        .onChange(of: text) { _, _ in
            stopMarquee(resetPosition: true)
            recalculateTextWidth()
        }
        .onHover { hovering in
            if hovering {
                beginMarquee()
            } else {
                stopMarquee(resetPosition: true)
            }
        }
        .help(text)
    }

    private var shouldAnimate: Bool {
        isHovered && marqueeStartDate != nil && canMarquee
    }

    private func beginMarquee() {
        isHovered = true
        guard canMarquee else { return }

        startWorkItem?.cancel()
        let workItem = DispatchWorkItem {
            guard isHovered else { return }
            marqueeStartDate = Date()
        }
        startWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + hoverDelay, execute: workItem)
    }

    private func stopMarquee(resetPosition: Bool) {
        isHovered = false
        startWorkItem?.cancel()
        startWorkItem = nil
        if resetPosition {
            marqueeStartDate = nil
        }
    }

    private func marqueeOffset(at date: Date) -> CGFloat {
        guard
            let marqueeStartDate,
            canMarquee
        else {
            return 0
        }

        let distance = Double(overflowWidth)
        guard distance > 0 else { return 0 }

        let travelDuration = max(distance / pointsPerSecond, 0.15)
        let cycleDuration = pauseDuration + travelDuration + pauseDuration + travelDuration
        let elapsed = date.timeIntervalSince(marqueeStartDate)
        let cycleTime = elapsed.truncatingRemainder(dividingBy: cycleDuration)

        if cycleTime < pauseDuration {
            return 0
        }
        if cycleTime < pauseDuration + travelDuration {
            let progress = (cycleTime - pauseDuration) / travelDuration
            return -CGFloat(progress * distance)
        }
        if cycleTime < pauseDuration + travelDuration + pauseDuration {
            return -CGFloat(distance)
        }

        let returnTime = cycleTime - (pauseDuration + travelDuration + pauseDuration)
        let returnProgress = returnTime / travelDuration
        return -CGFloat(distance * (1 - returnProgress))
    }

    private func recalculateTextWidth() {
        let measuredWidth = (text as NSString).size(withAttributes: [
            .font: NSFont.systemFont(ofSize: NSFont.systemFontSize)
        ]).width
        textWidth = measuredWidth
    }
}

private struct WidthPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private extension View {
    func readWidth(_ onChange: @escaping (CGFloat) -> Void) -> some View {
        background(
            GeometryReader { proxy in
                Color.clear
                    .preference(key: WidthPreferenceKey.self, value: proxy.size.width)
            }
        )
        .onPreferenceChange(WidthPreferenceKey.self, perform: onChange)
    }
}
