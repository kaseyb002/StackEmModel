import Foundation

extension Round {
    public mutating func apply(_ move: Move, playerID: PlayerID) throws {
        switch move {
        case .play(let cardID, let source, let position):
            try playCard(cardID: cardID, from: source, on: position, playerID: playerID)
        case .discard(let cardID, let position):
            try discard(cardID: cardID, to: position, playerID: playerID)
        case .pass:
            try passTurn(playerID: playerID)
        }
    }

    public mutating func playCard(
        cardID: CardID,
        from source: PlaySource,
        on position: BuildingPosition,
        playerID: PlayerID
    ) throws {
        let index: Int = try activePlayerIndex(playerID: playerID)
        guard accessibleCardID(from: source, at: index, requestedID: cardID) == cardID,
              let card: Card = cardsMap[cardID]
        else { throw StackEmError.cardNotAccessible }
        guard let value: CardNumber = nextNumber(on: position),
              card.isWild || card.cardType.numberValue == value
        else { throw StackEmError.cardNotPlayable }

        switch source {
        case .hand: playerHands[index].cards.removeAll { $0 == cardID }
        case .stock: playerHands[index].stockPile.removeLast()
        case .discard(let discardPosition): playerHands[index].discardPiles[discardPosition]?.removeLast()
        }
        buildingPiles[position, default: []].append(cardID)
        consecutivePasses = 0
        log.addAction(.init(playerID: playerID, decision: .play(cardId: cardID, from: source, on: position, value: value)))
        if value == .twelve {
            recycledCards.append(contentsOf: buildingPiles[position] ?? [])
            buildingPiles[position] = []
            log.addAction(.init(playerID: playerID, decision: .buildingCompleted(position)))
        }
        if playerHands[index].stockPile.isEmpty {
            state = .gameComplete(winner: playerHands[index].player)
            ended = .now
            log.addAction(.init(playerID: playerID, decision: .won))
            return
        }
        if playerHands[index].cards.isEmpty { refillHand(at: index) }
    }

    public mutating func discard(cardID: CardID, to position: DiscardPosition, playerID: PlayerID) throws {
        let index: Int = try activePlayerIndex(playerID: playerID)
        guard playerHands[index].cards.contains(cardID), cardsMap[cardID] != nil else {
            throw StackEmError.cardNotAccessible
        }
        playerHands[index].cards.removeAll { $0 == cardID }
        playerHands[index].discardPiles[position, default: []].append(cardID)
        consecutivePasses = 0
        log.addAction(.init(playerID: playerID, decision: .discard(cardId: cardID, to: position)))
        advancePlayer(from: index)
    }

    /// Exhausted-hand fallback only. Normal turns always end by discarding.
    /// If every player passes without a play/discard, the round stalls without a winner.
    public mutating func passTurn(playerID: PlayerID) throws {
        let index: Int = try activePlayerIndex(playerID: playerID)
        guard playerHands[index].cards.isEmpty,
              legalMoves(playerID: playerID) == [.pass]
        else { throw StackEmError.cannotPass }
        consecutivePasses += 1
        log.addAction(.init(playerID: playerID, decision: .pass))
        if consecutivePasses >= playerHands.count {
            state = .stalemate
            ended = .now
            log.addAction(.init(playerID: playerID, decision: .stalemate))
        } else {
            advancePlayer(from: index)
        }
    }
}
