# Stack 'Em model

A Foundation-only Swift package for 2–6 players. `Round` is one deal through a winner, with Stage 10-style cards, player hands, action log, fake data, and split round extensions. Rules follow [Mattel's individual-play instruction sheet](https://service.mattel.com/instruction_sheets/42050-Skip-Bo.pdf); partnerships and cumulative match scores are outside this package.

## Using a round

```swift
let players: [Player] = [
    .init(id: "me", name: "Me"),
    .init(id: "bot", name: "Bot")
]
var round: Round = try .init(players: players, startingPlayerID: "me")
let moves: [Round.Move] = round.legalMoves(playerID: "me")
if let move: Round.Move = moves.first {
    try round.apply(move, playerID: "me")
}
```

The caller selects the starting player (youngest under the source rules); the default is the first seat. `RuleOptions(shortGame: true)` uses ten-card stock piles. All piles are bottom-to-top, with the last element accessible. A building pile's count determines its effective top number, so wild card identity never changes when played or recycled.

`playCard`, `discard`, and `apply` validate turn ownership and card accessibility before mutation. Round automatically handles refills, reveals, building completion, recycling, and victory. Discarding ends the turn even if it empties the hand; playing the entire hand refills it immediately. Emptying the stock wins before another refill.

## Single-player wild rewards

`exchangeForWild(cardID:playerID:)` replaces an active player's numbered hand card with a newly created wild, keeping hand size and the current turn. The replaced card goes into the recycling reservoir. Each exchange adds one physical card to the inventory; the base deck remains 162 cards before rewards.

The single-player layer must check reward entitlement and consume a credit only after the mutation succeeds. Level progression, balances, purchases, and authorization are outside this model. Reward exchange is intentionally absent from ordinary legal moves and AI decisions.

## AI and hidden information

`AIEngine` supports easy, medium, and hard. `makeMove` performs one action for paced UI updates; `takeTurn` finishes only the current player's turn. Decisions accept `AIObservation`, which contains the acting player's hand, visible stock top/count, own public discard piles, and shared building piles. It excludes buried stock, other hands, and draw/recycle identities. Hard difficulty searches a small visible tree without assuming unknown stock reveals or refills.

The round itself is authoritative state containing hidden cards. Transport/UI layers must project it appropriately rather than distributing the entire round to untrusted players.

## Exhausted positions

When neither draw nor recycle cards remain, refills take only what exists. A player with an empty hand and no legal play may `passTurn`; this fallback never bypasses an available play or a required hand discard. A full cycle of such passes ends in `.stalemate`, with no winner. This deliberately defined fallback covers exhausted custom/edge-case positions where the source sheet offers no resolution.

## Tests

Run the standalone package's `StackEmModel` test scheme on an available iOS Simulator, with DerivedData at `/tmp/game-night-package-tests/StackEmModel`, following the workspace's `agent-docs/ios-build-and-test.md`. Tests include fully ordered two- and six-player deals through victory, AI rounds at every difficulty, reward exchanges, inventory conservation, invalid-action atomicity, and app-compatible Codable round trips. Cooked dealing support is internal; custom position builders and seeded generators live only in the test target.
