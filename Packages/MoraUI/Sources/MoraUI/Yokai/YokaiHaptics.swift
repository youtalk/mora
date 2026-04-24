#if canImport(UIKit)
import UIKit
#endif

public enum YokaiHaptics {
    public static func meterTick() {
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
    }
    public static func fridaySuccess() {
        #if canImport(UIKit)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif
    }
}
