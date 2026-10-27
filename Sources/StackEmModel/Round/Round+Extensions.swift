import Foundation

extension Round {
    public var currentPlayerID: PlayerID? {
        if case .waitingForPlayerToAct(let playerID) = state { return playerID }
        return nil
    }

    public var currentPlayerHand: PlayerHand? {
        playerHands.first { $0.player.id == currentPlayerID }
    }

    public var winner: Player? {
        if case .gameComplete(let player) = state { return player }
        return nil
    }

    public var isComplete: Bool { currentPlayerID == nil }

    /// A building pile's height is its resolved value, including any wilds.
    public func nextNumber(on position: BuildingPosition) -> CardNumber? {
        CardNumber(rawValue: (buildingPiles[position] ?? []).count + 1)
    }

    public func legalMoves(playerID: PlayerID) -> [Move] {
        observation(for: playerID)?.legalMoves ?? []
    }

    func activePlayerIndex(playerID: PlayerID) throws -> Int {
        guard let currentID: PlayerID = currentPlayerID else { throw StackEmError.roundNotActive }
        guard currentID == playerID else { throw StackEmError.notCurrentPlayer }
        guard let index: Int = playerHands.firstIndex(where: { $0.player.id == playerID }) else {
            throw StackEmError.invalidRound
        }
        return index
    }

    func accessibleCardID(from source: PlaySource, at index: Int, requestedID: CardID) -> CardID? {
        switch source {
        case .hand: playerHands[index].cards.contains(requestedID) ? requestedID : nil
        case .stock: playerHands[index].stockTop
        case .discard(let position): playerHands[index].discardPiles[position]?.last
        }
    }

    mutating func refillHand(at index: Int) {
        let originalCount: Int = playerHands[index].cards.count
        while playerHands[index].cards.count < Self.handSize {
            if deck.isEmpty, recycledCards.isEmpty == false {
                deck = recycledCards.shuffled()
                recycledCards.removeAll()
            }
            guard let cardID: CardID = deck.popLast() else { break }
            playerHands[index].cards.append(cardID)
        }
        let drawn: Int = playerHands[index].cards.count - originalCount
        if drawn > 0 {
            log.addAction(.init(playerID: playerHands[index].player.id, decision: .draw(count: drawn)))
        }
    }

    mutating func advancePlayer(from index: Int) {
        let nextIndex: Int = (index + 1) % playerHands.count
        state = .waitingForPlayerToAct(playerId: playerHands[nextIndex].player.id)
        refillHand(at: nextIndex)
    }
}
