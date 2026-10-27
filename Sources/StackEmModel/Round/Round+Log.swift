import Foundation

extension Round {
    public struct Log: Equatable, Codable, Sendable {
        public private(set) var actions: [PlayerAction]

        public struct PlayerAction: Equatable, Codable, Sendable {
            public let playerID: PlayerID
            public let decision: Decision
            public let timestamp: Date

            public enum CodingKeys: String, CodingKey {
                case playerID = "playerId"
                case decision, timestamp
            }

            public enum Decision: Equatable, Codable, Sendable {
                case draw(count: Int)
                case play(cardId: CardID, from: PlaySource, on: BuildingPosition, value: CardNumber)
                case discard(cardId: CardID, to: DiscardPosition)
                case exchangeForWild(cardId: CardID, wildCardId: CardID)
                case pass
                case buildingCompleted(BuildingPosition)
                case won
                case stalemate
            }

            public init(playerID: PlayerID, decision: Decision, timestamp: Date = .now) {
                self.playerID = playerID
                self.decision = decision
                self.timestamp = timestamp
            }
        }

        public init(actions: [PlayerAction] = []) {
            self.actions = Array(actions.suffix(Round.maxLogActions))
        }

        public mutating func addAction(_ action: PlayerAction) {
            actions.append(action)
            actions = Array(actions.suffix(Round.maxLogActions))
        }
    }
}
