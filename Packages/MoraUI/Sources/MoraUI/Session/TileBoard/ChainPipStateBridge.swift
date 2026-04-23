import MoraEngines

extension ChainPipState {
    init(_ value: ChainPipStateOrchestratorValue) {
        switch value {
        case .pending: self = .pending
        case .active: self = .active
        case .done: self = .done
        }
    }
}
