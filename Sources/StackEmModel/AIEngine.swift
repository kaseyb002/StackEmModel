import Foundation

public struct AIEngine: Equatable, Codable, Sendable {
    public enum Difficulty: String, CaseIterable, Equatable, Codable, Sendable {
        case easy, medium, hard
        public var displayableName: String { rawValue.capitalized }
    }

    public let difficulty: Difficulty

    public init(difficulty: Difficulty = .medium) {
        self.difficulty = difficulty
    }

    /// Stable tie breaking makes decisions reproducible without inspecting hidden data.
    public func decision(for observation: AIObservation) -> Round.Move {
        let moves: [Round.Move] = observation.legalMoves
        if difficulty == .easy {
            // Even the simplest bot must not repeatedly cover an available stock
            // number with hand cards, which can starve its win condition forever.
            let move = moves.first {
                if case .play(_, .stock, _) = $0 { return true }
                return false
            } ?? moves[0]
            if case .discard(let cardID, _) = move {
                // Spread discards around without evaluating card values or sequences.
                let position = DiscardPosition.allCases.min {
                    (observation.discardPiles[$0]?.count ?? 0) < (observation.discardPiles[$1]?.count ?? 0)
                } ?? .first
                return .discard(cardId: cardID, to: position)
            }
            return move
        }
        var best: Round.Move = moves[0]
        var bestScore: Int = Int.min
        for move: Round.Move in moves {
            var score: Int = immediateScore(move, in: observation)
            if difficulty == .hard, case .play = move {
                score += lookahead(observation.afterVisiblePlay(move), depth: 2)
            }
            if score > bestScore {
                best = move
                bestScore = score
            }
        }
        return best
    }

    /// One paced action for callers that render/animate each model transition.
    @discardableResult
    public func makeMove(round: inout Round, playerID: PlayerID) throws -> Round.Move {
        guard let observation: AIObservation = round.observation(for: playerID) else {
            if round.isComplete { throw StackEmError.roundNotActive }
            throw StackEmError.notCurrentPlayer
        }
        let move: Round.Move = decision(for: observation)
        try round.apply(move, playerID: playerID)
        return move
    }

    /// Completes only the current player's turn. Re-observes after every reveal/refill.
    /// Bound speculative playing so recycling cannot create an unending AI turn.
    public func takeTurn(round: inout Round) throws {
        guard let playerID: PlayerID = round.currentPlayerID else { throw StackEmError.roundNotActive }
        for _ in 0..<256 {
            guard round.currentPlayerID == playerID else { return }
            try makeMove(round: &round, playerID: playerID)
        }
        // A nonempty hand can always end the turn by discarding. In an exhausted
        // empty-hand position, draw/recycling cannot replenish it while playing
        // stock/discard cards, so those finite visible sources guarantee termination.
        while round.currentPlayerID == playerID {
            guard let observation: AIObservation = round.observation(for: playerID) else { return }
            let move: Round.Move = observation.legalMoves.first {
                if case .discard = $0 { return true }
                return false
            } ?? observation.legalMoves[0]
            try round.apply(move, playerID: playerID)
        }
    }

    private func immediateScore(_ move: Round.Move, in observation: AIObservation) -> Int {
        switch move {
        case .play(_, let source, let position):
            let wildCost: Int = observation.card(for: move)?.isWild == true ? 8 : 0
            let completion: Int = observation.buildingPiles[position]?.count == 11 ? 4 : 0
            switch source {
            case .stock: return 100 - wildCost + completion
            case .hand: return 12 - wildCost + completion
            case .discard: return 14 - wildCost + completion
            }
        case .discard(_, let position):
            guard let card: Card = observation.card(for: move) else { return -1000 }
            let number: Int = card.cardType.numberValue?.rawValue ?? 0
            let top: Card? = observation.discardPiles[position]?.last
            // Descending personal piles expose consecutive useful cards later.
            let sequenceBonus: Int = top?.cardType.numberValue?.rawValue == number + 1 ? 8 : 0
            let emptyBonus: Int = top == nil ? 3 : 0
            return -30 + sequenceBonus + emptyBonus + number - (card.isWild ? 30 : 0)
        case .pass: return -100
        }
    }

    private func lookahead(_ observation: AIObservation, depth: Int) -> Int {
        guard depth > 0 else { return 0 }
        let plays: [Round.Move] = observation.legalMoves.filter {
            if case .play = $0 { return true }
            return false
        }
        // Small visible search: at most eight branches at each of two depths.
        let candidates: [Round.Move] = Array(plays.sorted {
            immediateScore($0, in: observation) > immediateScore($1, in: observation)
        }.prefix(8))
        return candidates.map {
            immediateScore($0, in: observation) + lookahead(observation.afterVisiblePlay($0), depth: depth - 1)
        }.max() ?? 0
    }
}
