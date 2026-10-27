import Foundation

public struct PlayerHand: Equatable, Codable, Sendable {
    public var player: Player
    public var cards: [CardID]
    /// Piles are bottom-to-top; the last card is the accessible top.
    public var stockPile: [CardID]
    public var discardPiles: [DiscardPosition: [CardID]]

    public var stockTop: CardID? { stockPile.last }

    public init(
        player: Player,
        cards: [CardID] = [],
        stockPile: [CardID],
        discardPiles: [DiscardPosition: [CardID]] = [:]
    ) {
        self.player = player
        self.cards = cards
        self.stockPile = stockPile
        self.discardPiles = Dictionary(uniqueKeysWithValues: DiscardPosition.allCases.map {
            ($0, discardPiles[$0] ?? [])
        })
    }
}
