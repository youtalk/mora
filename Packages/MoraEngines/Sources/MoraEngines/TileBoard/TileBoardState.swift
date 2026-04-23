import Foundation

public enum TileBoardState: Hashable, Sendable {
    case preparing
    case listening
    case building
    case completed
    case speaking
    case feedback
    case transitioning

    public var debugTag: String {
        switch self {
        case .preparing: return "preparing"
        case .listening: return "listening"
        case .building: return "building"
        case .completed: return "completed"
        case .speaking: return "speaking"
        case .feedback: return "feedback"
        case .transitioning: return "transitioning"
        }
    }
}
