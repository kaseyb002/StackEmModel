import Foundation
import Testing
@testable import StackEmModel

@Test func deckCompositionAndDomain() {
    let deck: [Card] = .deck()
    #expect(deck.count == 162)
    #expect(Set(deck.map(\.id)).count == 162)
    #expect(deck.filter(\.isWild).count == 18)
    for number: CardNumber in CardNumber.allCases {
        #expect(deck.filter { $0.cardType == .number(number) }.count == 12)
        #expect(number.displayableName == String(number.rawValue))
    }
    #expect(CardNumber.twelve.next == nil)
    #expect(CardNumber.one < .two)
    #expect(BuildingPosition.allCases.count == 4)
    #expect(DiscardPosition.allCases.count == 4)
}

@Test(arguments: [2, 3, 4, 5, 6], [false, true])
func setup(playerCount: Int, shortGame: Bool) throws {
    let round: Round = try .init(ruleOptions: .init(shortGame: shortGame), players: players(playerCount), startingPlayerID: "p1")
    let expectedStock: Int = shortGame ? 10 : (playerCount <= 4 ? 30 : 20)
    #expect(round.playerHands.allSatisfy { $0.stockPile.count == expectedStock })
    #expect(round.playerHands[1].cards.count == 5)
    #expect(round.playerHands.enumerated().allSatisfy { $0.offset == 1 || $0.element.cards.isEmpty })
    #expect(round.currentPlayerID == "p1")
    #expect(round.deck.count == 162 - expectedStock * playerCount - 5)
    #expect(round.buildingPiles.values.allSatisfy { $0.isEmpty })
    #expect(round.playerHands.allSatisfy { $0.discardPiles.count == 4 && $0.discardPiles.values.allSatisfy { $0.isEmpty } })
    #expect(round.winner == nil)
    assertConserved(round)
}

@Test func setupRejectsInvalidInputs() {
    #expect(throws: StackEmError.notEnoughPlayers) { try Round(players: players(1)) }
    #expect(throws: StackEmError.tooManyPlayers) { try Round(players: players(7)) }
    #expect(throws: StackEmError.duplicatePlayerID) { try Round(players: [players(2)[0], players(2)[0]]) }
    #expect(throws: StackEmError.invalidStartingPlayer) { try Round(players: players(2), startingPlayerID: "missing") }
    #expect(throws: StackEmError.invalidDeck) { try Round(cookedDeck: [], players: players(2)) }
    #expect(throws: StackEmError.invalidDeck) {
        try Round(cookedDeck: Array(repeating: Card.fake(), count: 162), players: players(2))
    }
}

@Test func cookedDealIsRepeatableAndPublicDealShuffles() throws {
    let deck: [Card] = .deck()
    let first: Round = try .init(id: "same", started: testDate, cookedDeck: deck, players: players(2))
    let second: Round = try .init(id: "same", started: testDate, cookedDeck: deck, players: players(2))
    #expect(first.playerHands == second.playerHands)
    #expect(first.deck == second.deck)
    #expect(first.playerHands[0].stockPile == Array(132..<162))
    #expect(first.playerHands[0].cards == [101, 100, 99, 98, 97])
    let random: Round = try .init(players: players(2))
    #expect(random.deck != first.deck)
}

@Test(arguments: [PlaySource.hand, .stock, .discard(.first)])
func eachPlaySource(source: PlaySource) throws {
    var round: Round = try position(stocks: [[.number(.twelve), .number(.one)], [.number(.twelve)]],
                                    hands: [[.number(.one), .number(.eight)], []],
                                    discards: [.first: [.number(.one)]])
    let hand: PlayerHand = round.playerHands[0]
    let cardID: CardID = switch source {
    case .hand: hand.cards[0]
    case .stock: hand.stockTop!
    case .discard(let position): hand.discardPiles[position]!.last!
    }
    try round.playCard(cardID: cardID, from: source, on: .first, playerID: "p0")
    #expect(round.buildingPiles[.first] == [cardID])
    #expect(round.nextNumber(on: .first) == .two)
    #expect(round.currentPlayerID == "p0")
    #expect(round.cardsMap[cardID]?.cardType == .number(.one))
    assertConserved(round)
}

@Test(arguments: CardNumber.allCases)
func wildResolvesEveryNumber(number: CardNumber) throws {
    var round: Round = try position(hands: [[.wild, .number(.eight)], []], buildings: [.first: sequence(number.rawValue - 1)])
    let wildID: CardID = round.playerHands[0].cards[0]
    try round.playCard(cardID: wildID, from: .hand, on: .first, playerID: "p0")
    #expect(round.cardsMap[wildID]?.isWild == true)
    if number == .twelve {
        #expect(round.buildingPiles[.first]!.isEmpty)
        #expect(round.recycledCards.contains(wildID))
    } else {
        #expect(round.nextNumber(on: .first) == number.next)
    }
    #expect(round.log.actions.first?.decision == .play(cardId: wildID, from: .hand, on: .first, value: number))
    assertConserved(round)
}

@Test func topOnlyOwnershipAndInvalidPlaysAreAtomic() throws {
    let round: Round = try position(stocks: [[.number(.one), .number(.two)], [.number(.one)]],
                                    hands: [[.number(.one), .number(.two)], [.number(.one)]],
                                    discards: [.first: [.number(.one), .number(.two)]])
    let hand: PlayerHand = round.playerHands[0]
    let cases: [(CardID, PlaySource, StackEmError)] = [
        (hand.stockPile[0], .stock, .cardNotAccessible),
        (hand.discardPiles[.first]![0], .discard(.first), .cardNotAccessible),
        (round.playerHands[1].cards[0], .hand, .cardNotAccessible),
        (round.playerHands[1].stockTop!, .stock, .cardNotAccessible),
        (hand.cards[0], .discard(.second), .cardNotAccessible),
        (9999, .hand, .cardNotAccessible),
        (hand.cards[1], .hand, .cardNotPlayable)
    ]
    for (cardID, source, error) in cases {
        assertRejected(round, error: error) { try $0.playCard(cardID: cardID, from: source, on: .first, playerID: "p0") }
    }
    assertRejected(round, error: .notCurrentPlayer) {
        try $0.playCard(cardID: hand.cards[0], from: .hand, on: .first, playerID: "p1")
    }
    assertRejected(round, error: .notCurrentPlayer) {
        try $0.discard(cardID: hand.cards[0], to: .first, playerID: "p1")
    }
    assertRejected(round, error: .cannotPass) { try $0.passTurn(playerID: "p0") }
    assertRejected(round, error: .cardNotAccessible) {
        try $0.discard(cardID: hand.stockTop!, to: .first, playerID: "p0")
    }
}

@Test func fullBuildingSlotsCannotStartAFifthPile() throws {
    var round: Round = try position(hands: [[.number(.one), .number(.twelve)], []],
                                    buildings: Dictionary(uniqueKeysWithValues: BuildingPosition.allCases.map { ($0, sequence(11)) }))
    let one: CardID = round.playerHands[0].cards[0]
    #expect(round.legalMoves(playerID: "p0").allSatisfy {
        if case .play(let cardID, _, _) = $0 { return cardID != one }
        return true
    })
    try round.playCard(cardID: round.playerHands[0].cards[1], from: .hand, on: .fourth, playerID: "p0")
    #expect(round.buildingPiles[.fourth]!.isEmpty)
    try round.playCard(cardID: one, from: .hand, on: .fourth, playerID: "p0")
    #expect(round.buildingPiles[.fourth]!.count == 1)
    assertConserved(round)
}

@Test func refillOnlyAfterPlayingTheEntireHand() throws {
    var round: Round = try position(hands: [[.number(.one), .number(.two)], []],
                                    deck: [.number(.three), .number(.four), .number(.five), .number(.six), .number(.seven), .number(.eight)])
    let first: CardID = round.playerHands[0].cards[0]
    let second: CardID = round.playerHands[0].cards[1]
    try round.playCard(cardID: first, from: .hand, on: .first, playerID: "p0")
    #expect(round.playerHands[0].cards == [second])
    #expect(round.deck.count == 6)
    try round.playCard(cardID: second, from: .hand, on: .first, playerID: "p0")
    #expect(round.playerHands[0].cards.count == 5)
    #expect(round.deck.count == 1)
    #expect(round.currentPlayerID == "p0")
    assertConserved(round)
}

@Test func discardingLastHandCardEndsTurnWithoutRefillAndWrapsSeats() throws {
    var round: Round = try position(hands: [[.number(.one)], [.number(.five)]], deck: Array(repeating: .number(.six), count: 12))
    let first: CardID = round.playerHands[0].cards[0]
    // Discarding is allowed even with a legal building play.
    #expect(round.legalMoves(playerID: "p0").contains(.play(cardId: first, from: .hand, on: .first)))
    try round.discard(cardID: first, to: .fourth, playerID: "p0")
    #expect(round.playerHands[0].cards.isEmpty)
    #expect(round.playerHands[0].discardPiles[.fourth] == [first])
    #expect(round.playerHands[1].cards.count == 5)
    #expect(round.currentPlayerID == "p1")
    try round.discard(cardID: round.playerHands[1].cards[0], to: .first, playerID: "p1")
    #expect(round.playerHands[0].cards.count == 5)
    #expect(round.currentPlayerID == "p0")
    assertConserved(round)
}

@Test func discardedCardsNeedNotBeSequential() throws {
    var round: Round = try position(hands: [[.number(.eleven)], [.number(.one)]], discards: [.first: [.number(.two)]])
    let discarded: CardID = round.playerHands[0].cards[0]
    try round.discard(cardID: discarded, to: .first, playerID: "p0")
    #expect(round.playerHands[0].discardPiles[.first]?.last == discarded)
    #expect(round.playerHands[0].discardPiles[.first]?.count == 2)
    assertConserved(round)
}

@Test func completionRecyclesAndWildStaysWild() throws {
    var round: Round = try position(hands: [[.wild], []], buildings: [.first: sequence(11)])
    let wild: CardID = round.playerHands[0].cards[0]
    try round.playCard(cardID: wild, from: .hand, on: .first, playerID: "p0")
    #expect(round.buildingPiles[.first]!.isEmpty)
    #expect(round.playerHands[0].cards.count == 5)
    #expect(round.deck.count == 7)
    #expect(round.recycledCards.isEmpty)
    #expect(round.cardsMap[wild]?.isWild == true)
    assertConserved(round)
}

@Test func partialRefillPreservesAvailableCardsWithoutInventingAny() throws {
    var round: Round = try position(hands: [[.number(.one)], []], deck: [.number(.three)], recycled: [.wild])
    try round.playCard(cardID: round.playerHands[0].cards[0], from: .hand, on: .first, playerID: "p0")
    #expect(round.playerHands[0].cards.count == 2)
    #expect(round.playerHands[0].cards.compactMap { round.cardsMap[$0] }.filter(\.isWild).count == 1)
    #expect(round.deck.isEmpty && round.recycledCards.isEmpty)
    assertConserved(round)
}

@Test func finalStockCardWinsBeforeRefillOrTurnAdvance() throws {
    var round: Round = try position(stocks: [[.number(.one)], [.number(.twelve)]], hands: [[], []], deck: [.wild])
    try round.playCard(cardID: round.playerHands[0].stockTop!, from: .stock, on: .first, playerID: "p0")
    #expect(round.winner?.id == "p0")
    #expect(round.ended != nil)
    #expect(round.currentPlayerID == nil)
    #expect(round.playerHands[0].cards.isEmpty)
    #expect(round.deck.count == 1)
    #expect(round.legalMoves(playerID: "p0").isEmpty)
    assertRejected(round, error: .roundNotActive) { try $0.passTurn(playerID: "p0") }
    assertRejected(round, error: .roundNotActive) { try $0.discard(cardID: 0, to: .first, playerID: "p0") }
    assertRejected(round, error: .roundNotActive) { try $0.playCard(cardID: 0, from: .stock, on: .first, playerID: "p0") }
    assertConserved(round)
}

@Test func exhaustedUnplayableHandsReachStalemateWithoutWinner() throws {
    var round: Round = try position(hands: [[], []])
    #expect(round.legalMoves(playerID: "p0") == [.pass])
    try round.passTurn(playerID: "p0")
    #expect(round.currentPlayerID == "p1")
    try round.passTurn(playerID: "p1")
    #expect(round.state == .stalemate)
    #expect(round.winner == nil && round.ended != nil)
    assertConserved(round)
    assertRejected(round, error: .roundNotActive) { try $0.passTurn(playerID: "p0") }
}

@Test func emptyHandCannotPassWhenStockCanPlay() throws {
    let round: Round = try position(stocks: [[.number(.one)], [.number(.twelve)]], hands: [[], []])
    assertRejected(round, error: .cannotPass) { try $0.passTurn(playerID: "p0") }
}

@Test func logKeepsLatestHundredActions() {
    var log: Round.Log = .init()
    for index: Int in 0..<150 {
        log.addAction(.init(playerID: "p0", decision: .draw(count: index), timestamp: testDate))
    }
    #expect(log.actions.count == 100)
    #expect(log.actions.first?.decision == .draw(count: 50))
    #expect(log.actions.last?.decision == .draw(count: 149))
    #expect(Round.Log(actions: log.actions + log.actions).actions.count == 100)
}

@Test func activeAndCompletedRoundsRoundTripWithAppJSONStrategies() throws {
    var round: Round = try position(stocks: [[.number(.one)], [.number(.twelve)]], hands: [[.wild], []])
    // Exercise a non-nil imageURL with the app's snake-case decoder.
    round.playerHands[0].player.imageURL = URL(string: "https://example.com/avatar.png")
    #expect(try roundTrip(round) == round)
    try round.playCard(cardID: round.playerHands[0].stockTop!, from: .stock, on: .first, playerID: "p0")
    round.ended = testDate
    round.log = .init(actions: round.log.actions.map { .init(playerID: $0.playerID, decision: $0.decision, timestamp: testDate) })
    #expect(try roundTrip(round) == round)
}

@Test(arguments: [2, 6])
func deterministicFullRoundFromDealThroughVictory(playerCount: Int) throws {
    let stockSize: Int = RuleOptions.classic.stockSize(playerCount: playerCount)
    var remaining: [Card] = .deck()
    var stockInPlayOrder: [Card] = []
    for offset: Int in 0..<stockSize {
        let number: CardNumber = CardNumber(rawValue: offset % 12 + 1)!
        let index: Int = remaining.firstIndex { $0.cardType == .number(number) }!
        stockInPlayOrder.append(remaining.remove(at: index))
    }
    // The first player's stock is dealt from the suffix, then popped from the top.
    let cooked: [Card] = remaining + stockInPlayOrder.reversed()
    var round: Round = try .init(cookedDeck: cooked, players: players(playerCount))
    let initialHand: [CardID] = round.playerHands[0].cards
    let initialDeck: [CardID] = round.deck
    for offset: Int in 0..<stockSize {
        let cardID: CardID = try #require(round.playerHands[0].stockTop)
        #expect(cardID == stockInPlayOrder[offset].id)
        try round.playCard(cardID: cardID, from: .stock, on: .first, playerID: "p0")
        assertConserved(round)
        #expect(round.winner == (offset == stockSize - 1 ? round.playerHands[0].player : nil))
    }
    #expect(round.winner?.id == "p0")
    #expect(round.playerHands[0].cards == initialHand)
    #expect(round.deck == initialDeck)
    #expect(round.recycledCards.count == stockSize / 12 * 12)
}

@Test func logAndMovePayloadsUseAppCompatibleCodableKeys() throws {
    let decisions: [Round.Log.PlayerAction.Decision] = [
        .draw(count: 5), .play(cardId: 1, from: .discard(.second), on: .third, value: .five),
        .discard(cardId: 2, to: .fourth), .exchangeForWild(cardId: 3, wildCardId: 200),
        .pass, .buildingCompleted(.first), .won, .stalemate
    ]
    let actions: [Round.Log.PlayerAction] = decisions.map {
        .init(playerID: "p0", decision: $0, timestamp: testDate)
    }
    let log: Round.Log = .init(actions: actions)
    #expect(try roundTrip(log) == log)
    let moves: [Round.Move] = [
        .play(cardId: 1, from: .hand, on: .first), .play(cardId: 2, from: .stock, on: .second),
        .play(cardId: 3, from: .discard(.fourth), on: .third), .discard(cardId: 4, to: .first), .pass
    ]
    #expect(try roundTrip(moves) == moves)
}

@Test func fakeDataCoversDomainTypes() throws {
    #expect(try Round.fake(players: players(2)).playerHands.count == 2)
    #expect(try roundTrip(Card.fake()) == Card.fake())
    #expect(try roundTrip(Card.CardType.fake()) == Card.CardType.fake())
    #expect(try roundTrip(CardNumber.fake()) == CardNumber.fake())
    let player: Player = .fake(id: "fake", imageURL: URL(string: "https://example.com/image.png"))
    #expect(try roundTrip(player) == player)
    let hand: PlayerHand = .fake(player: player)
    #expect(try roundTrip(hand) == hand)
    #expect(try roundTrip(RuleOptions.fake()) == RuleOptions.fake())
    #expect(try roundTrip(BuildingPosition.fake()) == BuildingPosition.fake())
    #expect(try roundTrip(DiscardPosition.fake()) == DiscardPosition.fake())
    #expect(try roundTrip(PlaySource.fake()) == PlaySource.fake())
    #expect(try roundTrip(StackEmError.fake()) == StackEmError.fake())
    #expect(try roundTrip(AIObservation.fake()) == AIObservation.fake())
    #expect(try roundTrip(AIEngine.fake()) == AIEngine.fake())
    #expect(try roundTrip(AIEngine.Difficulty.fake()) == AIEngine.Difficulty.fake())
    #expect(try roundTrip(Round.State.fake()) == Round.State.fake())
    #expect(try roundTrip(Round.Move.fake()) == Round.Move.fake())
    #expect(try roundTrip(Round.Log.PlayerAction.Decision.fake()) == Round.Log.PlayerAction.Decision.fake())
    let action: Round.Log.PlayerAction = .fake(timestamp: testDate)
    #expect(try roundTrip(action) == action)
    let log: Round.Log = .fake()
    // Default JSON encoding preserves subsecond timestamps too.
    #expect(try JSONDecoder().decode(Round.Log.self, from: JSONEncoder().encode(log)) == log)
}

@Test func partialPassCycleResetsAfterRealProgress() throws {
    var round: Round = try position(stocks: [[.number(.twelve)], [.number(.twelve), .number(.one)]], hands: [[], []])
    try round.passTurn(playerID: "p0")
    #expect(round.consecutivePasses == 1)
    try round.playCard(cardID: round.playerHands[1].stockTop!, from: .stock, on: .first, playerID: "p1")
    #expect(round.consecutivePasses == 0)
    try round.passTurn(playerID: "p1")
    #expect(round.currentPlayerID == "p0")
    #expect(round.winner == nil)
    assertConserved(round)
}
