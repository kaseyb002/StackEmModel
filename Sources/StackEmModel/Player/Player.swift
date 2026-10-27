import Foundation

public typealias PlayerID = String

public struct Player: Equatable, Codable, Sendable, Identifiable {
    public let id: PlayerID
    public var name: String
    public var imageURL: URL?

    public enum CodingKeys: String, CodingKey {
        case id, name
        case imageURL = "imageUrl"
    }

    public init(id: PlayerID, name: String, imageURL: URL? = nil) {
        self.id = id
        self.name = name
        self.imageURL = imageURL
    }
}
