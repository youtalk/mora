import Combine
import Foundation

@MainActor
final class ThermalMonitor: ObservableObject {
    struct Sample: Equatable {
        let timestamp: Date
        let state: ProcessInfo.ThermalState
    }

    @Published private(set) var samples: [Sample] = []
    private var timer: Timer?

    func start(interval: TimeInterval = 2.0) {
        stop()
        samples = []
        record() // t=0
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.record() }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        record() // final
    }

    private func record() {
        samples.append(Sample(timestamp: Date(), state: ProcessInfo.processInfo.thermalState))
    }
}

extension ProcessInfo.ThermalState {
    var label: String {
        switch self {
        case .nominal: return "nominal"
        case .fair: return "fair"
        case .serious: return "serious"
        case .critical: return "critical"
        @unknown default: return "unknown"
        }
    }
}
