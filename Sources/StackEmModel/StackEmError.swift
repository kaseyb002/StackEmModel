import Foundation

public enum StackEmError: String, Error, Equatable, Codable, Sendable {
    case notEnoughPlayers, tooManyPlayers, duplicatePlayerID, invalidStartingPlayer
    case invalidDeck, invalidRound, roundNotActive, notCurrentPlayer
    case cardNotAccessible, cardNotPlayable, cannotExchangeWildForWild, cannotPass
    case cardIDExhausted

    public var displayableName: String {
        switch self {
        case .notEnoughPlayers: "Stack 'Em needs at least two players."
        case .tooManyPlayers: "Stack 'Em supports at most six players."
        case .duplicatePlayerID: "Player IDs must be unique."
        case .invalidStartingPlayer: "Choose a starting player in this round."
        case .invalidDeck: "The deck cannot be dealt."
        case .invalidRound: "The round contains invalid card or player data."
        case .roundNotActive: "The round is no longer active."
        case .notCurrentPlayer: "It is another player's turn."
        case .cardNotAccessible: "Choose a card in your hand or on top of your own pile."
        case .cardNotPlayable: "That card cannot be played on this building pile."
        case .cannotExchangeWildForWild: "That card is already wild."
        case .cannotPass: "End your turn by discarding a hand card."
        case .cardIDExhausted: "A new card ID could not be allocated."
        }
    }
}
