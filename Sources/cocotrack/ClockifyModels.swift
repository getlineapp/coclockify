import Foundation

struct ClockifyUser: Decodable {
    let id: String
    let name: String?
    let email: String?
    let defaultWorkspace: String?
    let activeWorkspace: String?
}

struct ClockifyProject: Decodable, Identifiable {
    let id: String
    let name: String
    let color: String?
    let archived: Bool?
    let clientName: String?
}

struct ClockifyTimeEntry: Decodable, Identifiable {
    let id: String
    let description: String?
    let projectId: String?
    let taskId: String?
    let billable: Bool?
    let tagIds: [String]?
    let userId: String?
    let workspaceId: String?
    let timeInterval: ClockifyTimeInterval
}

struct ClockifyTimeInterval: Decodable {
    let start: Date
    let end: Date?
    let duration: String?
}

struct ClockifyCreateTimeEntryRequest: Encodable {
    let start: String
    let description: String
    let projectId: String?
}

/// `PUT /time-entries/{id}` is a **full replace**, not a patch: any field left out
/// of the body is reset on the server. Sending only start/description/end/projectId
/// therefore silently destroyed the entry's tags and task assignment on every
/// rename or project change. Verified against the live API during the audit —
/// `tagIds: ["…"]` came back `null` after a description-only update.
///
/// Every field the app can carry through must therefore be echoed back explicitly.
/// Nil fields stay omitted, which under full-replace semantics is exactly right:
/// an absent `projectId` is how "remove the project" is expressed, and an absent
/// `end` is how a running entry stays running.
struct ClockifyUpdateTimeEntryRequest: Encodable {
    let start: String
    let description: String
    let end: String?
    let projectId: String?
    let taskId: String?
    let billable: Bool?
    let tagIds: [String]?

    init(
        start: String,
        description: String,
        end: String?,
        projectId: String?,
        taskId: String? = nil,
        billable: Bool? = nil,
        tagIds: [String]? = nil
    ) {
        self.start = start
        self.description = description
        self.end = end
        self.projectId = projectId
        self.taskId = taskId
        self.billable = billable
        self.tagIds = tagIds
    }

    /// Carries every preservable field over from the entry being modified, so a
    /// change to one attribute cannot wipe the others.
    init(
        preserving entry: ClockifyTimeEntry,
        start: Date,
        description: String,
        end: Date?,
        projectId: String?
    ) {
        self.init(
            start: start.clockifyISO8601String,
            description: description,
            end: end?.clockifyISO8601String,
            projectId: projectId,
            taskId: entry.taskId,
            billable: entry.billable,
            tagIds: entry.tagIds
        )
    }
}

struct ClockifyCreateProjectRequest: Encodable {
    let name: String
    let color: String?
    let isPublic: Bool
}

struct ClockifyStopTimeEntryRequest: Encodable {
    let end: String
}

struct ClockifyBulkEditTimeEntryRequest: Encodable {
    let id: String
    let description: String?
    let start: String?
    let end: String?

    enum CodingKeys: String, CodingKey {
        case id
        case description
        case start
        case end
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(description, forKey: .description)
        try container.encodeIfPresent(start, forKey: .start)
        try container.encodeIfPresent(end, forKey: .end)
    }
}

struct ClockifyWorkspace: Decodable {
    let id: String
    let name: String
    let workspaceSettings: ClockifyWorkspaceSettings
}

struct ClockifyWorkspaceSettings: Decodable {
    let forceProjects: Bool

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        forceProjects = try container.decodeIfPresent(Bool.self, forKey: .forceProjects) ?? false
    }

    private enum CodingKeys: String, CodingKey {
        case forceProjects
    }
}

struct ClockifyAPIErrorResponse: Decodable {
    let message: String?
    let error: String?
}
