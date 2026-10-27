import Foundation

/// An AI receives only this projection, never a Round or its full card map.
/// Discard piles are public; buried stock cards, opponents' hands and draw order are absent.
public struct AIObservation: Equatable, Codable, Sendable {
    public let playerID: PlayerID
    public internal(set) var hand: [Card]
    public internal(set) var stockTop: Card?
    public let stockCount: Int
    public internal(set) var discardPiles: [DiscardPosition: [Card]]
    public internal(set) var buildingPiles: [BuildingPosition: [Card]]

    public enum CodingKeys: String, CodingKey {
        case playerID = "playerId"
        case hand, stockTop, stockCount, discardPiles, buildingPiles
    }

    public init(
        playerID: PlayerID,
        hand: [Card],
        stockTop: Card?,
        stockCount: Int,
        discardPiles: [DiscardPosition: [Card]],
        buildingPiles: [BuildingPosition: [Card]]
    ) {
        self.playerID = playerID
        self.hand = hand
        self.stockTop = stockTop
        self.stockCount = stockCount
        self.discardPiles = discardPiles
        self.buildingPiles = buildingPiles
    }

    public var legalMoves: [Round.Move] {
        var moves: [Round.Move] = []
        var available: [(Card, PlaySource)] = hand.map { ($0, .hand) }
        if let stockTop: Card { available.append((stockTop, .stock)) }
        for position: DiscardPosition in DiscardPosition.allCases {
            if let card: Card = discardPiles[position]?.last {
                available.append((card, .discard(position)))
            }
        }
        for (card, source) in available {
            for position: BuildingPosition in BuildingPosition.allCases {
                let next: CardNumber? = .init(rawValue: (buildingPiles[position] ?? []).count + 1)
                if let next, card.isWild || card.cardType.numberValue == next {
                    moves.append(.play(cardId: card.id, from: source, on: position))
                }
            }
        }
        for card: Card in hand {
            for position: DiscardPosition in DiscardPosition.allCases {
                moves.append(.discard(cardId: card.id, to: position))
            }
        }
        return moves.isEmpty ? [.pass] : moves
    }

    func card(for move: Round.Move) -> Card? {
        switch move {
        case .play(let cardID, let source, _):
            switch source {
            case .hand: hand.first { $0.id == cardID }
            case .stock: stockTop
            case .discard(let position): discardPiles[position]?.last
            }
        case .discard(let cardID, _): hand.first { $0.id == cardID }
        case .pass: nil
        }
    }

    /// Visible-only lookahead: never guess the next stock card or hand refill.
    func afterVisiblePlay(_ move: Round.Move) -> AIObservation {
        var result: AIObservation = self
        guard case .play(let cardID, let source, let position) = move,
              let card: Card = card(for: move)
        else { return result }
        switch source {
        case .hand: result.hand.removeAll { $0.id == cardID }
        case .stock: result.stockTop = nil
        case .discard(let discardPosition): result.discardPiles[discardPosition]?.removeLast()
        }
        result.buildingPiles[position, default: []].append(card)
        if result.buildingPiles[position]?.count == 12 { result.buildingPiles[position] = [] }
        return result
    }
}

extension Round {
    /// Returns nil for another player's turn or a finished round.
    public func observation(for playerID: PlayerID) -> AIObservation? {
        guard currentPlayerID == playerID, let hand: PlayerHand = currentPlayerHand else { return nil }
        return .init(
            playerID: playerID,
            hand: hand.cards.compactMap { cardsMap[$0] },
            stockTop: hand.stockTop.flatMap { cardsMap[$0] },
            stockCount: hand.stockPile.count,
            discardPiles: hand.discardPiles.mapValues { $0.compactMap { cardsMap[$0] } },
            buildingPiles: buildingPiles.mapValues { $0.compactMap { cardsMap[$0] } }
        )
    }
}
