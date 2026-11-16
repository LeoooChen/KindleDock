import Foundation
import Darwin

/// getmntinfo(MNT_NOWAIT) only reads the mount table; it never touches a stale
/// FUSE volume and never spawns /sbin/mount on the UI thread.
func isMounted() -> Bool {
    var entries: UnsafeMutablePointer<statfs>?
    let count = getmntinfo(&entries, MNT_NOWAIT)
    guard count > 0, let entries else { return false }
    for index in 0..<Int(count) {
        var entry = entries[index]
        let path = withUnsafePointer(to: &entry.f_mntonname) {
            $0.withMemoryRebound(to: CChar.self, capacity: Int(MNAMELEN)) { String(cString: $0) }
        }
        if path == mountPoint { return true }
    }
    return false
}
