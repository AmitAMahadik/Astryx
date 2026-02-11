import Foundation
import SwiftData

@Model
final class ChatMessage {
    enum Role: String, Codable {
        case user
        case assistant
    }

    @Attribute(.unique) var id: UUID
    var roleRawValue: String
    var content: String
    var createdAt: Date

    var role: Role {
        get { Role(rawValue: roleRawValue) ?? .user }
        set { roleRawValue = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        role: Role,
        content: String,
        createdAt: Date = .now
    ) {
        self.id = id
        self.roleRawValue = role.rawValue
        self.content = content
        self.createdAt = createdAt
    }
}
