import Foundation

public enum CardNumber: Int, CaseIterable, Comparable, Codable, Sendable {
    case one = 1
    case two, three, four, five, six, seven, eight, nine, ten, eleven, twelve

    public var displayableName: String { String(rawValue) }
    public var next: CardNumber? { .init(rawValue: rawValue + 1) }

    public static func < (lhs: CardNumber, rhs: CardNumber) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}
