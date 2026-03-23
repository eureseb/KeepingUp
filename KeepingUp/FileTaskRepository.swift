//
//  FileTaskRepository.swift
//  KeepingUp
//
//  Created by Codex on 3/23/26.
//

import Foundation

final class FileTaskRepository: TaskRepository {
    let changeSourceIdentifier: String

    private let defaults: UserDefaults
    private let fileManager: FileManager
    private let storeURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(
        defaults: UserDefaults = .standard,
        fileManager: FileManager = .default,
        storeURL: URL? = nil,
        changeSourceIdentifier: String = UUID().uuidString
    ) {
        self.defaults = defaults
        self.fileManager = fileManager
        self.storeURL = storeURL ?? Self.defaultStoreURL(fileManager: fileManager)
        self.changeSourceIdentifier = changeSourceIdentifier
    }

    func loadTasks() throws -> [StartupTask] {
        try migrateLegacyTasksIfNeeded()

        guard fileManager.fileExists(atPath: storeURL.path) else {
            return []
        }

        let data = try Data(contentsOf: storeURL)
        return try decoder.decode([StartupTask].self, from: data)
    }

    func saveTasks(_ tasks: [StartupTask], postChangeNotification: Bool) throws {
        try migrateLegacyTasksIfNeeded()
        try writeTasksToDisk(tasks)

        guard postChangeNotification else { return }
        broadcastTasksDidChange()
    }

    @discardableResult
    func appendTask(title rawTitle: String, postChangeNotification: Bool = true) throws -> StartupTask {
        let title = try TaskStore.validateTitle(rawTitle)
        var tasks = try loadTasks()
        let newTask = StartupTask(title: title)
        tasks.append(newTask)
        try saveTasks(tasks, postChangeNotification: postChangeNotification)
        return newTask
    }

    private func migrateLegacyTasksIfNeeded() throws {
        guard !fileManager.fileExists(atPath: storeURL.path) else {
            return
        }

        guard let legacyData = defaults.data(forKey: TaskStore.legacyTasksStorageKey) else {
            return
        }

        let legacyTasks = try decoder.decode([StartupTask].self, from: legacyData)
        try writeTasksToDisk(legacyTasks)
        defaults.removeObject(forKey: TaskStore.legacyTasksStorageKey)
    }

    private func writeTasksToDisk(_ tasks: [StartupTask]) throws {
        let directoryURL = storeURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)

        let data = try encoder.encode(tasks)
        try data.write(to: storeURL, options: [.atomic])
    }

    private func broadcastTasksDidChange() {
        DistributedNotificationCenter.default().postNotificationName(
            TaskStore.tasksDidChangeNotificationName,
            object: nil,
            userInfo: [TaskStore.changeSourceIdentifierUserInfoKey: changeSourceIdentifier],
            deliverImmediately: true
        )
    }

    private static func defaultStoreURL(fileManager: FileManager) -> URL {
        let baseDirectory = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory

        return baseDirectory
            .appendingPathComponent("KeepingUp", isDirectory: true)
            .appendingPathComponent("tasks.json", isDirectory: false)
    }
}
