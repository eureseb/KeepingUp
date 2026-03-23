//
//  TaskRepository.swift
//  KeepingUp
//
//  Created by Codex on 3/23/26.
//

import Foundation

protocol TaskRepository {
    var changeSourceIdentifier: String { get }

    func loadTasks() throws -> [StartupTask]
    func saveTasks(_ tasks: [StartupTask], postChangeNotification: Bool) throws

    @discardableResult
    func appendTask(title rawTitle: String, postChangeNotification: Bool) throws -> StartupTask
}
