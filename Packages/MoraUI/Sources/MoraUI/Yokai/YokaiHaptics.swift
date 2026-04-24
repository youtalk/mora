#if canImport(UIKit)
import UIKit
#endif

@MainActor
public enum YokaiHaptics {
    #if canImport(UIKit)
    private static let meterTickGenerator = UIImpactFeedbackGenerator(style: .light)
    private static let fridaySuccessGenerator = UINotificationFeedbackGenerator()
    #endif

    public static func meterTick() {
        #if canImport(UIKit)
        meterTickGenerator.prepare()
        meterTickGenerator.impactOccurred()
        #endif
    }

    public static func fridaySuccess() {
        #if canImport(UIKit)
        fridaySuccessGenerator.prepare()
        fridaySuccessGenerator.notificationOccurred(.success)
        #endif
    }
}
