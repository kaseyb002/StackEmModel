import Foundation
import Testing
@testable import StackEmModel

@Test func exchangeCreatesBonusWildWithoutChangingTurnOrStock() throws {
    var round: Round = try position(hands: [[.number(.one), .number(.two)], []], deck: [.number(.five)])
    let before: Round = round
    let replaced: CardID = round.playerHands[0].cards[0]
    try round.exchangeForWild(cardID: replaced, playerID: "p0")
    let wild: CardID = try #require(round.playerHands[0].cards.last)
    #expect(wild > before.cardsMap.keys.max()!)
    #expect(round.cardsMap[wild]?.isWild == true)
    #expect(round.cardsMap[replaced] == before.cardsMap[replaced])
    #expect(round.recycledCards == [replaced])
    #expect(round.playerHands[0].cards.count == before.playerHands[0].cards.count)
    #expect(round.playerHands[0].cards.contains(replaced) == false)
    #expect(round.cardsMap.count == before.cardsMap.count + 1)
    #expect(round.deck == before.deck)
    #expect(round.buildingPiles == before.buildingPiles)
    #expect(round.state == before.state)
    #expect(round.ended == before.ended)
    #expect(round.playerHands[0].stockPile == before.playerHands[0].stockPile)
    #expect(round.playerHands[0].discardPiles == before.playerHands[0].discardPiles)
    #expect(round.playerHands[1] == before.playerHands[1])
    #expect(round.log.actions.last?.decision == .exchangeForWild(cardId: replaced, wildCardId: wild))
    assertConserved(round)
    try round.playCard(cardID: wild, from: .hand, on: .first, playerID: "p0")
    #expect(round.nextNumber(on: .first) == .two)
    assertConserved(round)
}

@Test func repeatedExchangeIDsAndSerialization() throws {
    var round: Round = try position(hands: [[.number(.one), .number(.two)], []])
    let originalCount: Int = round.cardsMap.count
    for cardID: CardID in round.playerHands[0].cards {
        try round.exchangeForWild(cardID: cardID, playerID: "p0")
    }
    #expect(round.cardsMap.count == originalCount + 2)
    #expect(Set(round.playerHands[0].cards).count == 2)
    #expect(round.playerHands[0].cards.allSatisfy { round.cardsMap[$0]?.isWild == true })
    round.log = .init(actions: round.log.actions.map { .init(playerID: $0.playerID, decision: $0.decision, timestamp: testDate) })
    let decoded: Round = try roundTrip(round)
    #expect(decoded == round)
    assertConserved(decoded)
}

@Test func replacedCardIsRecycledNaturally() throws {
    var round: Round = try position(hands: [[.number(.one)], []], buildings: [.first: sequence(11)])
    let replaced: CardID = round.playerHands[0].cards[0]
    try round.exchangeForWild(cardID: replaced, playerID: "p0")
    let wild: CardID = round.playerHands[0].cards[0]
    try round.playCard(cardID: wild, from: .hand, on: .first, playerID: "p0")
    #expect(round.deck.contains(replaced) || round.playerHands[0].cards.contains(replaced))
    #expect(round.recycledCards.isEmpty)
    #expect(round.cardsMap[wild]?.isWild == true)
    #expect(round.cardsMap[replaced]?.cardType == .number(.one))
    assertConserved(round)
}

@Test func exchangeRejectsEveryInvalidSourceWithoutMutation() throws {
    let round: Round = try position(stocks: [[.number(.one), .number(.two)], [.number(.three)]],
                                    hands: [[.number(.four), .wild], [.number(.five)]],
                                    discards: [.first: [.number(.six), .number(.seven)]])
    let hand: PlayerHand = round.playerHands[0]
    assertRejected(round, error: .cannotExchangeWildForWild) {
        try $0.exchangeForWild(cardID: hand.cards[1], playerID: "p0")
    }
    for cardID: CardID in hand.stockPile + hand.discardPiles[.first]! + round.playerHands[1].cards + [999] {
        assertRejected(round, error: .cardNotAccessible) { try $0.exchangeForWild(cardID: cardID, playerID: "p0") }
    }
    assertRejected(round, error: .notCurrentPlayer) { try $0.exchangeForWild(cardID: hand.cards[0], playerID: "p1") }
    assertRejected(round, error: .notCurrentPlayer) { try $0.exchangeForWild(cardID: hand.cards[0], playerID: "unknown") }
    var complete: Round = round
    complete.state = .gameComplete(winner: hand.player)
    assertRejected(complete, error: .roundNotActive) { try $0.exchangeForWild(cardID: hand.cards[0], playerID: "p0") }
    complete.state = .stalemate
    assertRejected(complete, error: .roundNotActive) { try $0.exchangeForWild(cardID: hand.cards[0], playerID: "p0") }
}

@Test func exchangeDoesNotCreateCardWhenIDsExhausted() throws {
    var round: Round = try position()
    // A valid custom physical ID at the integer limit, not a duplicate card.
    let old: CardID = round.playerHands[0].cards[0]
    let card: Card = round.cardsMap.removeValue(forKey: old)!
    round.cardsMap[CardID.max] = .init(id: CardID.max, cardType: card.cardType)
    round.playerHands[0].cards[0] = CardID.max
    assertRejected(round, error: .cardIDExhausted) { try $0.exchangeForWild(cardID: CardID.max, playerID: "p0") }
    assertConserved(round)
}
