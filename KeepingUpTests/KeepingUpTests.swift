//
//  KeepingUpTests.swift
//  KeepingUpTests
//
//  Created by EureseB on 3/20/26.
//

import Foundation
import Testing
@testable import KeepingUp

@MainActor
struct KeepingUpTests {

    @Test func addTaskTrimsWhitespace() throws {
        let suiteName = "ChecklistViewModelTests"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            Issue.record("Unable to create UserDefaults suite")
            return
        }
        defaults.removePersistentDomain(forName: suiteName)

        let viewModel = ChecklistViewModel(defaults: defaults)
        viewModel.tasks = []
        viewModel.newTaskTitle = "  Brew coffee  "
        viewModel.addTask()

        #expect(viewModel.tasks.first?.title == "Brew coffee")
    }


    @Test func freshLaunchStartsWithNoTasks() throws {
        let suiteName = "ChecklistViewModelEmptyStateTests"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            Issue.record("Unable to create UserDefaults suite")
            return
        }
        defaults.removePersistentDomain(forName: suiteName)

        let viewModel = ChecklistViewModel(defaults: defaults)

        #expect(viewModel.tasks.isEmpty)
    }

    @Test func tasksPersistBetweenLaunches() throws {
        let suiteName = "ChecklistViewModelPersistenceTests"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            Issue.record("Unable to create UserDefaults suite")
            return
        }
        defaults.removePersistentDomain(forName: suiteName)

        let viewModel = ChecklistViewModel(defaults: defaults)
        viewModel.tasks = [StartupTask(title: "Open standup notes")]
        guard let storedTask = viewModel.tasks.first else {
            Issue.record("Failed to append task")
            return
        }
        viewModel.toggleCompletion(for: storedTask)

        let rehydratedViewModel = ChecklistViewModel(defaults: defaults)
        #expect(rehydratedViewModel.tasks.first?.isComplete == true)
    }
}
