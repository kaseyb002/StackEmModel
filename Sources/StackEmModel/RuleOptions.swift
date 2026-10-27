import Foundation

public struct RuleOptions: Equatable, Codable, Sendable {
    public var shortGame: Bool
    public static let classic: RuleOptions = .init()

    public init(shortGame: Bool = false) {
        self.shortGame = shortGame
    }

    public func stockSize(playerCount: Int) -> Int {
        shortGame ? 10 : (playerCount <= 4 ? 30 : 20)
    }
}
