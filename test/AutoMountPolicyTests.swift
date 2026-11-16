@main
struct AutoMountPolicyTests {
    static func main() {
        var fast = AutoMountPolicy()
        fast.updateConnection(1, now: 0)
        assert(!fast.claimAttempt(enabled: true, idle: true, now: 0.34))
        assert(fast.claimAttempt(enabled: true, idle: true, now: 0.35))
        var policy = AutoMountPolicy(settleDelay: 2)
        assert(!policy.claimAttempt(enabled: true, idle: true, now: 10))
        policy.updateConnection(1, now: 10)
        assert(!policy.claimAttempt(enabled: true, idle: true, now: 11))
        assert(policy.claimAttempt(enabled: true, idle: true, now: 12))
        assert(!policy.claimAttempt(enabled: true, idle: true, now: 100))
        // A failed automatic attempt or an explicit Finder eject must not loop.
        policy.suppressUntilDisconnect()
        assert(!policy.claimAttempt(enabled: true, idle: true, now: 200))
        policy.updateConnection(nil, now: 201)
        policy.updateConnection(1, now: 202)
        assert(!policy.claimAttempt(enabled: true, idle: false, now: 205))
        assert(policy.claimAttempt(enabled: true, idle: true, now: 206))
        policy.updateConnection(nil, now: 210)
        policy.updateConnection(1, now: 211)
        assert(!policy.claimAttempt(enabled: false, idle: true, now: 214))
        assert(policy.claimAttempt(enabled: true, idle: true, now: 215))
        // Explicitly re-enabling auto-mount permits one new delayed attempt.
        policy.reenable(now: 220)
        assert(!policy.claimAttempt(enabled: true, idle: true, now: 221))
        assert(policy.claimAttempt(enabled: true, idle: true, now: 222))
        // Reproduces a disconnected old volume surviving until after reconnect.
        var reconnect = AutoMountPolicy(settleDelay: 2)
        reconnect.updateConnection(10, now: 0)
        assert(reconnect.claimAttempt(enabled: true, idle: true, now: 2))
        reconnect.updateConnection(nil, now: 3)
        assert(reconnect.requiresCleanup(sessionConnectionID: 10, hasSession: true))
        reconnect.updateConnection(20, now: 4)
        assert(reconnect.requiresCleanup(sessionConnectionID: 10, hasSession: true))
        assert(!reconnect.claimAttempt(enabled: true, idle: false, now: 7))
        assert(!reconnect.requiresCleanup(sessionConnectionID: nil, hasSession: false))
        assert(reconnect.claimAttempt(enabled: true, idle: true, now: 8))
        assert(!reconnect.requiresCleanup(sessionConnectionID: 20, hasSession: true))
        reconnect.suppressUntilDisconnect()
        assert(!reconnect.claimAttempt(enabled: true, idle: true, now: 9))
        // A fast replug that falls between polls still changes the registry ID.
        reconnect.updateConnection(30, now: 10)
        assert(reconnect.requiresCleanup(sessionConnectionID: 20, hasSession: true))
        assert(reconnect.claimAttempt(enabled: true, idle: true, now: 12))
        print("PASS: stale mount cleanup, reconnect during cleanup, fast replug,  startup, debounce, single attempt, eject, reconnect, busy, toggle")
    }
}
