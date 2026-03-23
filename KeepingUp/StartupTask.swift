//
//  StartupTask.swift
//  KeepingUp
//
//  Created by EureseB on 3/20/26.
//

import Foundation

enum TaskPriority: String, Codable, CaseIterable, Equatable {
    case low
    case normal
    case high
}

struct TaskParserMetadata: Codable, Equatable {
    var originalInput: String?
    var detectedDueDatePhrase: String?
    var detectedPriorityPhrase: String?

    init(
        originalInput: String? = nil,
        detectedDueDatePhrase: String? = nil,
        detectedPriorityPhrase: String? = nil
    ) {
        self.originalInput = originalInput
        self.detectedDueDatePhrase = detectedDueDatePhrase
        self.detectedPriorityPhrase = detectedPriorityPhrase
    }
}

/// Represents one checklist entry shown in the UI.
/// `Identifiable` lets SwiftUI keep track of each row in the List.
struct StartupTask: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var isComplete: Bool
    var createdAt: Date
    var updatedAt: Date
    var dueDate: Date?
    var priority: TaskPriority
    var parserMetadata: TaskParserMetadata?

    init(
        id: UUID = UUID(),
        title: String,
        isComplete: Bool = false,
        createdAt: Date = .now,
        updatedAt: Date? = nil,
        dueDate: Date? = nil,
        priority: TaskPriority = .normal,
        parserMetadata: TaskParserMetadata? = nil
    ) {
        self.id = id
        self.title = title
        self.isComplete = isComplete
        self.createdAt = createdAt
        self.updatedAt = updatedAt ?? createdAt
        self.dueDate = dueDate
        self.priority = priority
        self.parserMetadata = parserMetadata
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case isComplete
        case createdAt
        case updatedAt
        case dueDate
        case priority
        case parserMetadata
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        isComplete = try container.decode(Bool.self, forKey: .isComplete)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? .now
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? createdAt
        dueDate = try container.decodeIfPresent(Date.self, forKey: .dueDate)
        priority = try container.decodeIfPresent(TaskPriority.self, forKey: .priority) ?? .normal
        parserMetadata = try container.decodeIfPresent(TaskParserMetadata.self, forKey: .parserMetadata)
    }

    /// Populates the list on first launch so the UI isn't empty.
    static let sampleData: [StartupTask] = [
        StartupTask(title: "Review today's priorities"),
        StartupTask(title: "Check calendar and reminders"),
        StartupTask(title: "Run quick system/status checks")
    ]
}
