import Foundation

extension Round {
    public init(
        id: RoundID = UUID().uuidString,
        started: Date = .now,
        ruleOptions: RuleOptions = .classic,
        players: [Player],
        startingPlayerID: PlayerID? = nil
    ) throws {
        try self.init(
            id: id, started: started, ruleOptions: ruleOptions, cookedDeck: [Card].deck().shuffled(),
            players: players, startingPlayerID: startingPlayerID
        )
    }

    /// Internal deterministic support: the supplied order is never shuffled during dealing.
    internal init(
        id: RoundID = UUID().uuidString,
        started: Date = .now,
        ruleOptions: RuleOptions = .classic,
        cookedDeck: [Card],
        players: [Player],
        startingPlayerID: PlayerID? = nil
    ) throws {
        try Self.validate(players: players)
        let firstID: PlayerID = startingPlayerID ?? players[0].id
        guard let firstIndex: Int = players.firstIndex(where: { $0.id == firstID }) else {
            throw StackEmError.invalidStartingPlayer
        }
        let stockSize: Int = ruleOptions.stockSize(playerCount: players.count)
        guard Set(cookedDeck.map(\.id)).count == cookedDeck.count,
              cookedDeck.count >= players.count * stockSize + Self.handSize
        else { throw StackEmError.invalidDeck }
        self.id = id
        self.started = started
        self.ruleOptions = ruleOptions
        self.cardsMap = Dictionary(uniqueKeysWithValues: cookedDeck.map { ($0.id, $0) })
        var remaining: [CardID] = cookedDeck.map(\.id)
        self.playerHands = players.map { player in
            let stock: [CardID] = Array(remaining.suffix(stockSize))
            remaining.removeLast(stockSize)
            return .init(player: player, stockPile: stock)
        }
        self.deck = remaining
        self.buildingPiles = Dictionary(uniqueKeysWithValues: BuildingPosition.allCases.map { ($0, []) })
        self.recycledCards = []
        self.log = .init()
        self.ended = nil
        self.state = .waitingForPlayerToAct(playerId: firstID)
        refillHand(at: firstIndex)
    }

    static func validate(players: [Player]) throws {
        guard players.count >= minPlayers else { throw StackEmError.notEnoughPlayers }
        guard players.count <= maxPlayers else { throw StackEmError.tooManyPlayers }
        guard Set(players.map(\.id)).count == players.count else { throw StackEmError.duplicatePlayerID }
    }
}
