//
//  StartupTask.swift
//  KeepingUp
//
//  Created by EureseB on 3/20/26.
//

import Foundation

enum TaskPriority: String, Codable, CaseIterable, Equatable, Identifiable {
    case low
    case medium
    case high

    var id: String { rawValue }

    nonisolated var title: String {
        switch self {
        case .low:
            return "Low"
        case .medium:
            return "Medium"
        case .high:
            return "High"
        }
    }

    nonisolated var sortOrder: Int {
        switch self {
        case .high:
            return 0
        case .medium:
            return 1
        case .low:
            return 2
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)

        switch rawValue {
        case Self.low.rawValue:
            self = .low
        case Self.medium.rawValue, "normal":
            self = .medium
        case Self.high.rawValue:
            self = .high
        default:
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unknown task priority value: \(rawValue)"
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
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
    var isPinned: Bool
    var pinnedOrder: Int?
    var manualOrderGroupID: String?
    var manualOrder: Int?
    var hasExplicitDueTime: Bool
    var parserMetadata: TaskParserMetadata?

    init(
        id: UUID = UUID(),
        title: String,
        isComplete: Bool = false,
        createdAt: Date = .now,
        updatedAt: Date? = nil,
        dueDate: Date? = nil,
        priority: TaskPriority = .medium,
        isPinned: Bool = false,
        pinnedOrder: Int? = nil,
        manualOrderGroupID: String? = nil,
        manualOrder: Int? = nil,
        hasExplicitDueTime: Bool = false,
        parserMetadata: TaskParserMetadata? = nil
    ) {
        self.id = id
        self.title = title
        self.isComplete = isComplete
        self.createdAt = createdAt
        self.updatedAt = updatedAt ?? createdAt
        self.dueDate = dueDate
        self.priority = priority
        self.isPinned = isPinned
        self.pinnedOrder = pinnedOrder
        self.manualOrderGroupID = manualOrderGroupID
        self.manualOrder = manualOrder
        self.hasExplicitDueTime = hasExplicitDueTime
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
        case isPinned
        case pinnedOrder
        case manualOrderGroupID
        case manualOrder
        case hasExplicitDueTime
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
        priority = try container.decodeIfPresent(TaskPriority.self, forKey: .priority) ?? .medium
        isPinned = try container.decodeIfPresent(Bool.self, forKey: .isPinned) ?? false
        pinnedOrder = try container.decodeIfPresent(Int.self, forKey: .pinnedOrder)
        manualOrderGroupID = try container.decodeIfPresent(String.self, forKey: .manualOrderGroupID)
        manualOrder = try container.decodeIfPresent(Int.self, forKey: .manualOrder)
        hasExplicitDueTime = try container.decodeIfPresent(Bool.self, forKey: .hasExplicitDueTime) ?? false
        parserMetadata = try container.decodeIfPresent(TaskParserMetadata.self, forKey: .parserMetadata)
    }

    /// Populates the list on first launch so the UI isn't empty.
    static let sampleData: [StartupTask] = [
        StartupTask(title: "Review today's priorities"),
        StartupTask(title: "Check calendar and reminders"),
        StartupTask(title: "Run quick system/status checks")
    ]
}
