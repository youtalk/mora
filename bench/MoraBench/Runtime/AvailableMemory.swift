import Darwin
import Foundation

enum AvailableMemory {
    /// Bytes the process can allocate before iOS may kill it.
    /// Requires `com.apple.developer.kernel.extended-virtual-addressing`
    /// for honest reporting.
    static func current() -> UInt64? {
        let avail = os_proc_available_memory()
        return avail > 0 ? UInt64(avail) : nil
    }
}
