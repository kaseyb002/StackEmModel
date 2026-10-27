import Foundation

public enum BuildingPosition: String, CaseIterable, Hashable, Codable, Sendable {
    case first, second, third, fourth
    public var displayableName: String { rawValue.capitalized + " building pile" }
}

public enum DiscardPosition: String, CaseIterable, Hashable, Codable, Sendable {
    case first, second, third, fourth
    public var displayableName: String { rawValue.capitalized + " discard pile" }
}

public enum PlaySource: Equatable, Hashable, Codable, Sendable {
    case hand
    case stock
    case discard(DiscardPosition)

    public var displayableName: String {
        switch self {
        case .hand: "Hand"
        case .stock: "Stock pile"
        case .discard(let position): position.displayableName
        }
    }
}
