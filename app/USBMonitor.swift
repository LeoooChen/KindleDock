// Native USB arrival/removal notifications. No device claiming, polling shell,
// USB reset, or extra permission is involved.
import Foundation
import IOKit

func kindleMatchingDictionary() -> CFMutableDictionary? {
    guard let matching = IOServiceMatching("IOUSBHostDevice") else { return nil }
    let properties = matching as NSMutableDictionary
    properties["idVendor"] = 0x1949
    properties["idProduct"] = 0x9981
    return matching
}

func kindleConnectionID() -> UInt64? {
    guard let matching = kindleMatchingDictionary() else { return nil }
    let service = IOServiceGetMatchingService(kIOMainPortDefault, matching)
    guard service != 0 else { return nil }
    defer { IOObjectRelease(service) }
    var id: UInt64 = 0
    guard IORegistryEntryGetRegistryEntryID(service, &id) == KERN_SUCCESS else { return nil }
    return id
}

final class USBMonitor {
    private var port: IONotificationPortRef?
    private var arrivals: io_iterator_t = 0
    private var removals: io_iterator_t = 0
    private let onChange: () -> Void

    init(onChange: @escaping () -> Void) { self.onChange = onChange }

    @discardableResult
    func start() -> Bool {
        guard let p = IONotificationPortCreate(kIOMainPortDefault) else { return false }
        port = p
        IONotificationPortSetDispatchQueue(p, DispatchQueue.main)
        let context = Unmanaged.passUnretained(self).toOpaque()
        let callback: IOServiceMatchingCallback = { context, iterator in
            guard let context else { return }
            Unmanaged<USBMonitor>.fromOpaque(context).takeUnretainedValue().consume(iterator)
        }
        guard let added = kindleMatchingDictionary(), let removed = kindleMatchingDictionary() else { return false }
        let a = IOServiceAddMatchingNotification(p, kIOFirstMatchNotification, added,
                                                callback, context, &arrivals)
        let r = IOServiceAddMatchingNotification(p, kIOTerminatedNotification, removed,
                                                callback, context, &removals)
        // Iterators must be drained once to arm subsequent notifications.
        consume(arrivals); consume(removals)
        return a == KERN_SUCCESS && r == KERN_SUCCESS
    }

    private func consume(_ iterator: io_iterator_t) {
        guard iterator != 0 else { return }
        while true {
            let service = IOIteratorNext(iterator)
            guard service != 0 else { break }
            IOObjectRelease(service)
        }
        onChange()
    }

    deinit {
        if let port { IONotificationPortDestroy(port) }
        if arrivals != 0 { IOObjectRelease(arrivals) }
        if removals != 0 { IOObjectRelease(removals) }
    }
}
