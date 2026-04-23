import Foundation

/// Mirror of `ChainPipState` that lives in MoraUI — exposed from the engine
/// tier so the UI does not have to own its own computation. The two are
/// structurally identical; the duplication exists so MoraEngines does not
/// have to import SwiftUI.
public enum ChainPipStateOrchestratorValue: Hashable, Sendable {
    case pending
    case active
    case done
}
