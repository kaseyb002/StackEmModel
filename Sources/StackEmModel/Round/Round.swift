import Foundation

public typealias RoundID = String

public struct Round: Equatable, Codable, Sendable, Identifiable {
    public static let minPlayers: Int = 2
    public static let maxPlayers: Int = 6
    public static let handSize: Int = 5
    public static let maxLogActions: Int = 100

    public let id: RoundID
    public let started: Date
    public let ruleOptions: RuleOptions
    public internal(set) var state: State
    public internal(set) var cardsMap: [CardID: Card]
    public internal(set) var playerHands: [PlayerHand]
    /// Bottom-to-top, like all other piles. Drawing removes the last card.
    public internal(set) var deck: [CardID]
    public internal(set) var buildingPiles: [BuildingPosition: [CardID]]
    public internal(set) var recycledCards: [CardID]
    public internal(set) var log: Log
    public internal(set) var ended: Date?
    internal var consecutivePasses: Int = 0

    public enum State: Equatable, Codable, Sendable {
        case waitingForPlayerToAct(playerId: PlayerID)
        case gameComplete(winner: Player)
        /// Exhausted edge-case positions have no winner; never choose one arbitrarily.
        case stalemate

        public var displayableName: String {
            switch self {
            case .waitingForPlayerToAct: "Playing"
            case .gameComplete(let winner): "\(winner.name) wins"
            case .stalemate: "No moves remaining"
            }
        }
    }

    /// Only ordinary legal moves appear here; reward exchanges require external entitlement.
    public enum Move: Equatable, Codable, Sendable {
        case play(cardId: CardID, from: PlaySource, on: BuildingPosition)
        case discard(cardId: CardID, to: DiscardPosition)
        case pass
    }
}
