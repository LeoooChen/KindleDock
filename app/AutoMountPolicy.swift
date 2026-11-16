// One automatic attempt per USB connection; explicit eject stays ejected.
struct AutoMountPolicy {
    let settleDelay: Double
    init(settleDelay: Double = 0.35) { self.settleDelay = settleDelay }
    private(set) var connectionID: UInt64?
    var connected: Bool { connectionID != nil }
    private var readyAt = 0.0
    private var attempted = false

    mutating func updateConnection(_ id: UInt64?, now: Double) {
        guard id != connectionID else { return }
        connectionID = id
        attempted = false
        readyAt = now + settleDelay
    }

    mutating func claimAttempt(enabled: Bool, idle: Bool, now: Double) -> Bool {
        guard connected, enabled, idle, !attempted, now >= readyAt else { return false }
        attempted = true
        return true
    }

    mutating func suppressUntilDisconnect() { attempted = true }

    func requiresCleanup(sessionConnectionID: UInt64?, hasSession: Bool) -> Bool {
        hasSession && sessionConnectionID != connectionID
    }

    mutating func reenable(now: Double) {
        attempted = false
        readyAt = now + settleDelay
    }
}
