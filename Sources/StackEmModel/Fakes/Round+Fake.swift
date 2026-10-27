import Foundation

extension Round {
    public static func fake(
        id: RoundID = UUID().uuidString,
        started: Date = .now,
        ruleOptions: RuleOptions = .classic,
        players: [Player] = [.fake(name: "Alex"), .fake(name: "Sam")]
    ) throws -> Round {
        try .init(id: id, started: started, ruleOptions: ruleOptions, players: players)
    }
}
extension Round.State {
    public static func fake() -> Round.State { .waitingForPlayerToAct(playerId: "alex") }
}
extension Round.Move {
    public static func fake() -> Round.Move { .play(cardId: 0, from: .hand, on: .first) }
}
extension Round.Log {
    public static func fake() -> Round.Log { .init(actions: [.fake()]) }
}
extension Round.Log.PlayerAction {
    public static func fake(
        playerID: PlayerID = "alex", decision: Decision = .discard(cardId: 0, to: .first), timestamp: Date = .now
    ) -> Round.Log.PlayerAction {
        .init(playerID: playerID, decision: decision, timestamp: timestamp)
    }
}
extension Round.Log.PlayerAction.Decision {
    public static func fake() -> Round.Log.PlayerAction.Decision { .discard(cardId: 0, to: .first) }
}
