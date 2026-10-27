import Foundation

public typealias CardID = Int

public struct Card: Equatable, Codable, Sendable, Identifiable {
    public let id: CardID
    public let cardType: CardType

    public enum CardType: Equatable, Codable, Sendable {
        case number(CardNumber)
        case wild

        public var numberValue: CardNumber? {
            if case .number(let number) = self { return number }
            return nil
        }
        public var isWild: Bool { self == .wild }
        public var displayableName: String { numberValue?.displayableName ?? "Wild" }
    }

    public var isWild: Bool { cardType.isWild }
    public var displayableName: String { cardType.displayableName }
    public var logValue: String { "ID: \(id) \(displayableName)" }

    public init(id: CardID, cardType: CardType) {
        self.id = id
        self.cardType = cardType
    }
}

extension Array where Element == Card {
    public static func deck() -> [Card] {
        var cards: [Card] = []
        for number: CardNumber in CardNumber.allCases {
            for _ in 0..<12 {
                cards.append(.init(id: cards.count, cardType: .number(number)))
            }
        }
        for _ in 0..<18 {
            cards.append(.init(id: cards.count, cardType: .wild))
        }
        return cards
    }
}
