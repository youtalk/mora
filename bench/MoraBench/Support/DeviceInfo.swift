import Foundation
import UIKit

struct DeviceInfo: Codable {
    let modelIdentifier: String
    let systemName: String
    let systemVersion: String
    let physicalMemoryBytes: UInt64

    static func current() -> DeviceInfo {
        var sysinfo = utsname()
        uname(&sysinfo)
        let model = withUnsafePointer(to: &sysinfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) { String(validatingCString: $0) ?? "unknown" }
        }
        return DeviceInfo(
            modelIdentifier: model,
            systemName: UIDevice.current.systemName,
            systemVersion: UIDevice.current.systemVersion,
            physicalMemoryBytes: ProcessInfo.processInfo.physicalMemory
        )
    }
}
