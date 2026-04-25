import Foundation
import MoraEngines

/// Records every play / stop call. `playReturn` lets a test simulate a
/// player that fails to initialize (e.g., missing file).
@MainActor
open class FakeYokaiClipPlayer: YokaiClipPlayer {
    public var playedURLs: [URL] = []
    public var stopCallCount: Int = 0
    public var playReturn: Bool = true

    public init() {}

    open func play(url: URL) -> Bool {
        playedURLs.append(url)
        return playReturn
    }

    open func stop() {
        stopCallCount += 1
    }
}
