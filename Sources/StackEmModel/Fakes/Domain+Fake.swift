import Foundation

extension CardNumber {
    public static func fake() -> CardNumber { .five }
}
extension Card.CardType {
    public static func fake() -> Card.CardType { .number(.five) }
}
extension Card {
    public static func fake(id: CardID = 0, cardType: CardType = .number(.five)) -> Card {
        .init(id: id, cardType: cardType)
    }
}
extension Player {
    public static func fake(id: PlayerID = UUID().uuidString, name: String = "Alex", imageURL: URL? = nil) -> Player {
        .init(id: id, name: name, imageURL: imageURL)
    }
}
extension PlayerHand {
    public static func fake(
        player: Player = .fake(), cards: [CardID] = [0, 1], stockPile: [CardID] = [2, 3],
        discardPiles: [DiscardPosition: [CardID]] = [:]
    ) -> PlayerHand {
        .init(player: player, cards: cards, stockPile: stockPile, discardPiles: discardPiles)
    }
}
extension BuildingPosition {
    public static func fake() -> BuildingPosition { .first }
}
extension DiscardPosition {
    public static func fake() -> DiscardPosition { .first }
}
extension PlaySource {
    public static func fake() -> PlaySource { .hand }
}
extension RuleOptions {
    public static func fake(shortGame: Bool = false) -> RuleOptions { .init(shortGame: shortGame) }
}
extension StackEmError {
    public static func fake() -> StackEmError { .cardNotPlayable }
}
extension AIEngine.Difficulty {
    public static func fake() -> AIEngine.Difficulty { .medium }
}
extension AIEngine {
    public static func fake(difficulty: Difficulty = .medium) -> AIEngine { .init(difficulty: difficulty) }
}
extension AIObservation {
    public static func fake() -> AIObservation {
        .init(playerID: "alex", hand: [.fake()], stockTop: .fake(id: 1), stockCount: 10,
              discardPiles: [:], buildingPiles: [:])
    }
}
