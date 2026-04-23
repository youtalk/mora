import Foundation

/// Runs `operation` with a deadline. Returns the operation's value if it
/// finishes within `duration`; returns nil on timeout or on a thrown error.
/// On timeout, the operation task is cancelled but its result is discarded
/// regardless of when it eventually completes.
///
/// Internal to MoraEngines — not part of the package's public surface.
func withTimeout<T: Sendable>(
    _ duration: Duration,
    operation: @Sendable @escaping () async throws -> T
) async -> T? {
    await withTaskGroup(of: Optional<T>.self) { group in
        group.addTask { try? await operation() }
        group.addTask {
            try? await Task.sleep(for: duration)
            return nil
        }
        defer { group.cancelAll() }
        return await group.next() ?? nil
    }
}
