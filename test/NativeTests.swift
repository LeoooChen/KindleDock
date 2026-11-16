import Foundation
import IOKit

let mountPoint = "/"
@main
struct NativeTests {
    static func main() {
        precondition(isMounted(), "Native mount-table lookup must find the root volume")
        let matching = kindleMatchingDictionary()! as NSDictionary
        precondition(matching["idVendor"] as? Int == 0x1949)
        precondition(matching["idProduct"] as? Int == 0x9981)
        let monitor = USBMonitor(onChange: {})
        precondition(monitor.start(), "IOKit notification registration must succeed without a Kindle")
        _ = kindleConnectionID()
        print("PASS: native mount table, USB filter and notification registration")
        withExtendedLifetime(monitor) {}
    }
}
