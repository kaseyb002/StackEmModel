import Foundation
import Testing
@testable import StackEmModel

let testDate: Date = Date(timeIntervalSince1970: 1_700_000_000)

func players(_ count: Int) -> [Player] {
    (0..<count).map { .init(id: "p\($0)", name: "Player \($0)") }
}

/// All fixtures are test-only; production actions are never bypassed during playthroughs.
func position(
    stocks: [[Card.CardType]] = [[.number(.twelve)], [.number(.twelve)]],
    hands: [[Card.CardType]] = [[.number(.one)], []],
    discards: [DiscardPosition: [Card.CardType]] = [:],
    buildings: [BuildingPosition: [Card.CardType]] = [:],
    deck: [Card.CardType] = [],
    recycled: [Card.CardType] = []
) throws -> Round {
    let seats: [Player] = players(stocks.count)
    var round: Round = try .init(id: "test", started: testDate, cookedDeck: [Card].deck(), players: seats)
    var map: [CardID: Card] = [:]
    func ids(_ kinds: [Card.CardType]) -> [CardID] {
        kinds.map { kind in
            let card: Card = .init(id: map.count, cardType: kind)
            map[card.id] = card
            return card.id
        }
    }
    round.playerHands = seats.enumerated().map { index, player in
        .init(player: player, cards: ids(hands[index]), stockPile: ids(stocks[index]),
              discardPiles: index == 0 ? discards.mapValues { ids($0) } : [:])
    }
    round.buildingPiles = Dictionary(uniqueKeysWithValues: BuildingPosition.allCases.map { ($0, ids(buildings[$0] ?? [])) })
    round.deck = ids(deck)
    round.recycledCards = ids(recycled)
    round.cardsMap = map
    round.state = .waitingForPlayerToAct(playerId: "p0")
    round.ended = nil
    round.log = .init()
    round.consecutivePasses = 0
    return round
}

func sequence(_ count: Int) -> [Card.CardType] {
    (1...max(1, count)).prefix(count).map { .number(CardNumber(rawValue: $0)!) }
}

func assertConserved(_ round: Round, sourceLocation: SourceLocation = #_sourceLocation) {
    let playerCards: [CardID] = round.playerHands.flatMap {
        $0.cards + $0.stockPile + $0.discardPiles.values.flatMap { $0 }
    }
    let all: [CardID] = playerCards + round.deck + round.recycledCards + round.buildingPiles.values.flatMap { $0 }
    #expect(all.count == round.cardsMap.count, sourceLocation: sourceLocation)
    #expect(Set(all).count == all.count, sourceLocation: sourceLocation)
    #expect(Set(all) == Set(round.cardsMap.keys), sourceLocation: sourceLocation)
}

func assertRejected(
    _ round: Round,
    error: StackEmError,
    action: (inout Round) throws -> Void,
    sourceLocation: SourceLocation = #_sourceLocation
) {
    var updated: Round = round
    #expect(throws: error, sourceLocation: sourceLocation) { try action(&updated) }
    #expect(updated == round, sourceLocation: sourceLocation)
}

func roundTrip<T: Codable & Equatable>(_ value: T) throws -> T {
    let encoder: JSONEncoder = .init()
    encoder.dateEncodingStrategy = .iso8601
    encoder.keyEncodingStrategy = .convertToSnakeCase
    let decoder: JSONDecoder = .init()
    decoder.dateDecodingStrategy = .iso8601
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    return try decoder.decode(T.self, from: encoder.encode(value))
}
