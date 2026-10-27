import Foundation

extension Round {
    /// The caller authorizes/consumes a reward credit only after this succeeds.
    /// Creates a bonus physical wild, matching Stage 10's single-player reward hook.
    public mutating func exchangeForWild(cardID: CardID, playerID: PlayerID) throws {
        let index: Int = try activePlayerIndex(playerID: playerID)
        guard let cardIndex: Int = playerHands[index].cards.firstIndex(of: cardID),
              let card: Card = cardsMap[cardID]
        else { throw StackEmError.cardNotAccessible }
        guard card.isWild == false else { throw StackEmError.cannotExchangeWildForWild }
        let maximumID: CardID = cardsMap.keys.max() ?? -1
        guard maximumID < CardID.max else { throw StackEmError.cardIDExhausted }
        let wild: Card = .init(id: maximumID + 1, cardType: .wild)
        playerHands[index].cards.remove(at: cardIndex)
        recycledCards.append(cardID)
        cardsMap[wild.id] = wild
        playerHands[index].cards.append(wild.id)
        log.addAction(.init(playerID: playerID, decision: .exchangeForWild(cardId: cardID, wildCardId: wild.id)))
    }
}
