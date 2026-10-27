import Foundation
import Testing
@testable import StackEmModel

struct SeededGenerator: RandomNumberGenerator {
    var state: UInt64
    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }
}

@Test(arguments: AIEngine.Difficulty.allCases)
func aiDecisionsUseOnlyVisibleData(difficulty: AIEngine.Difficulty) throws {
    let round: Round = try position(stocks: [[.number(.five), .number(.three)], [.number(.one), .number(.two)]],
                                    hands: [[.number(.one), .wild], [.number(.nine)]],
                                    discards: [.first: [.number(.four), .number(.two)]],
                                    deck: [.number(.five), .number(.six)], recycled: [.number(.seven), .number(.eight)])
    var changed: Round = round
    let hidden: [CardID] = [changed.playerHands[0].stockPile[0], changed.playerHands[1].stockPile[0]]
        + changed.playerHands[1].cards + changed.deck + changed.recycledCards
    for cardID: CardID in hidden {
        changed.cardsMap[cardID] = .init(id: cardID, cardType: .wild)
    }
    changed.deck.reverse()
    changed.recycledCards.reverse()
    let original: AIObservation = try #require(round.observation(for: "p0"))
    let altered: AIObservation = try #require(changed.observation(for: "p0"))
    #expect(original == altered)
    let engine: AIEngine = .init(difficulty: difficulty)
    let move: Round.Move = engine.decision(for: original)
    #expect(move == engine.decision(for: altered))
    #expect(original.legalMoves.contains(move))
    #expect(round.observation(for: "p1") == nil)
    #expect(round.legalMoves(playerID: "p1").isEmpty)
    #expect(try roundTrip(original) == original)
}

@Test func mediumPrioritizesStockAndHardFindsAVisibleStockOpening() throws {
    let stockRound: Round = try position(stocks: [[.number(.twelve), .number(.one)], [.number(.twelve)]],
                                         hands: [[.number(.one)], []])
    let stockView: AIObservation = try #require(stockRound.observation(for: "p0"))
    #expect(AIEngine(difficulty: .medium).decision(for: stockView) == .play(cardId: stockView.stockTop!.id, from: .stock, on: .first))
    // A tempting discard-top play of 1 competes with playing hand 3 then 4 to open stock 5.
    let openingRound: Round = try position(stocks: [[.number(.twelve), .number(.five)], [.number(.twelve)]],
                                           hands: [[.number(.three), .number(.four)], []],
                                           discards: [.first: [.number(.one)]], buildings: [.first: sequence(2)])
    let view: AIObservation = try #require(openingRound.observation(for: "p0"))
    #expect(AIEngine(difficulty: .medium).decision(for: view) == .play(cardId: view.discardPiles[.first]!.last!.id, from: .discard(.first), on: .second))
    #expect(AIEngine(difficulty: .hard).decision(for: view) == .play(cardId: view.hand[0].id, from: .hand, on: .first))
}

@Test func mediumConservesWildAndOrganizesDiscards() throws {
    let round: Round = try position(hands: [[.wild, .number(.one)], []])
    let view: AIObservation = try #require(round.observation(for: "p0"))
    #expect(AIEngine(difficulty: .medium).decision(for: view) == .play(cardId: view.hand[1].id, from: .hand, on: .first))
    let blocked: Round = try position(hands: [[.wild, .number(.eight)], []],
                                      discards: [.third: [.number(.nine)]],
                                      buildings: Dictionary(uniqueKeysWithValues: BuildingPosition.allCases.map { ($0, sequence(3)) }))
    // Remove the playable wild to isolate the discard decision.
    var discardView: AIObservation = try #require(blocked.observation(for: "p0"))
    discardView.hand.removeAll(where: \.isWild)
    #expect(AIEngine(difficulty: .medium).decision(for: discardView) == .discard(cardId: discardView.hand[0].id, to: .third))
}

@Test func easySpreadsDiscardsAcrossAllPiles() throws {
    var round = try position(hands: [[.number(.eight), .number(.seven), .number(.six), .number(.five)], []])
    let engine = AIEngine(difficulty: .easy)
    for pile in DiscardPosition.allCases {
        let cardID = try #require(round.playerHands[0].cards.first)
        #expect(try engine.makeMove(round: &round, playerID: "p0") == .discard(cardId: cardID, to: pile))
        assertConserved(round)
        try round.passTurn(playerID: "p1")
    }
    #expect(DiscardPosition.allCases.allSatisfy { round.playerHands[0].discardPiles[$0]?.count == 1 })
}

@Test func easyUsesTheSmallestOccupiedDiscardPile() throws {
    let round = try position(
        hands: [[.number(.eight)], []],
        discards: [.first: [.number(.five), .number(.four)], .second: [.number(.three)],
                   .third: [.number(.nine), .number(.seven)], .fourth: [.number(.six), .number(.two)]]
    )
    let observation = try #require(round.observation(for: "p0"))
    #expect(AIEngine(difficulty: .easy).decision(for: observation)
            == .discard(cardId: observation.hand[0].id, to: .second))
}

@Test(arguments: AIEngine.Difficulty.allCases)
func aiHandlesRefillsAndStopsAtNextPlayer(difficulty: AIEngine.Difficulty) throws {
    var round: Round = try position(hands: [[.number(.one)], []], deck: Array(repeating: .number(.two), count: 7))
    let engine: AIEngine = .init(difficulty: difficulty)
    try engine.takeTurn(round: &round)
    #expect(round.currentPlayerID == "p1")
    #expect(round.buildingPiles[.first]?.count == 2)
    #expect(round.playerHands[0].cards.count == 3)
    assertConserved(round)
    assertRejected(round, error: .notCurrentPlayer) { try engine.makeMove(round: &$0, playerID: "p0") }
}

@Test func aiHandlesExhaustedHandAndCompletedRound() throws {
    var round: Round = try position(hands: [[], []])
    try AIEngine().takeTurn(round: &round)
    #expect(round.currentPlayerID == "p1")
    try AIEngine().takeTurn(round: &round)
    #expect(round.state == .stalemate)
    assertRejected(round, error: .roundNotActive) { try AIEngine().takeTurn(round: &$0) }
}

@Test(arguments: [2, 6], AIEngine.Difficulty.allCases)
func seededStandardRoundAIPlaythrough(playerCount: Int, difficulty: AIEngine.Difficulty) throws {
    var generator: SeededGenerator = .init(state: UInt64(playerCount + 42))
    let deck: [Card] = [Card].deck().shuffled(using: &generator)
    var round: Round = try .init(cookedDeck: deck, players: players(playerCount))
    let engine: AIEngine = .init(difficulty: difficulty)
    var moves: Int = 0
    // Every step uses the real public mutation API and checks inventory conservation.
    while round.isComplete == false, moves < 10_000 {
        let playerID: PlayerID = try #require(round.currentPlayerID)
        try engine.makeMove(round: &round, playerID: playerID)
        assertConserved(round)
        moves += 1
    }
    #expect(moves < 10_000)
    #expect(round.winner != nil)
    let winner: Player = try #require(round.winner)
    #expect(round.playerHands.first { $0.player.id == winner.id }?.stockPile.isEmpty == true)
    #expect(round.ended != nil)
    #expect(round.cardsMap.count == 162)
    #expect(round.log.actions.count <= 100)
}

@Test func seededShortRoundPlaythrough() throws {
    // A cooked order avoids relying on shuffling; use only public actions after setup.
    var generator: SeededGenerator = .init(state: 77)
    var round: Round = try .init(ruleOptions: .init(shortGame: true),
                                  cookedDeck: [Card].deck().shuffled(using: &generator), players: players(2))
    for _ in 0..<1000 {
        if round.isComplete { break }
        try AIEngine(difficulty: .medium).takeTurn(round: &round)
        assertConserved(round)
    }
    #expect(round.winner != nil)
}
