// Packages/MoraEngines/Sources/MoraEngines/Yokai/YokaiProgressionSource.swift
import Foundation

/// Look up the yokai that should follow `currentID` in the weekly
/// rotation. Returns `nil` when the curriculum has no further yokai.
public protocol YokaiProgressionSource: Sendable {
    func nextYokaiID(after currentID: String) -> String?
}

/// Closure-backed default. The v1 bootstrap wires this to
/// `CurriculumEngine.sharedV1.nextSkill(after:).yokaiID`.
public struct ClosureYokaiProgressionSource: YokaiProgressionSource {
    private let resolver: @Sendable (String) -> String?
    public init(_ resolver: @escaping @Sendable (String) -> String?) {
        self.resolver = resolver
    }
    public func nextYokaiID(after currentID: String) -> String? {
        resolver(currentID)
    }
}
