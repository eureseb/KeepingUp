//
//  StartupTask.swift
//  KeepingUp
//
//  Created by EureseB on 3/20/26.
//

import Foundation

/// Represents one checklist entry shown in the UI.
/// `Identifiable` lets SwiftUI keep track of each row in the List.
struct StartupTask: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var isComplete: Bool
    var createdAt: Date

    init(id: UUID = UUID(), title: String, isComplete: Bool = false, createdAt: Date = .now) {
        self.id = id
        self.title = title
        self.isComplete = isComplete
        self.createdAt = createdAt
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case isComplete
        case createdAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        isComplete = try container.decode(Bool.self, forKey: .isComplete)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? .now
    }

    /// Populates the list on first launch so the UI isn't empty.
    static let sampleData: [StartupTask] = [
        StartupTask(title: "Review today's priorities"),
        StartupTask(title: "Check calendar and reminders"),
        StartupTask(title: "Run quick system/status checks")
    ]
}
