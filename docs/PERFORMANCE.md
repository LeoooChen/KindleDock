# Mount latency

KindleDock reduces controllable overhead; it cannot promise a fixed end-to-end time across Kindle firmware, hubs, cables and macFUSE/macOS versions.

| Stage | Previous local prototype | KindleDock |
| --- | --- | --- |
| USB discovery | 1-second timer | IOKit first-match / terminated notifications |
| Device settling | 2 seconds, plus timer alignment | 350 ms, then one attempt |
| Mount-table checks | spawn `/sbin/mount` | `getmntinfo(MNT_NOWAIT)` |
| Idle monitoring | per-second refresh | native USB/unmount events; 15-second native fallback |
| Readiness check | 500 ms mount-table polling | 100 ms native checks; verify root exposes `documents` |
| Reconnect | initially reused a stale volume | registry entry identity + retire old helper before mounting |

The menu-bar app logs `Ready in N ms from USB detection; helper + filesystem M ms` to `~/Library/Logs/KindleDock.log`. These are actual wall-clock measurements using system uptime; they are not throughput benchmarks. The helper/filesystem portion includes macFUSE's virtual-volume attachment and directory verification.

The previous prototype was physically verified on a Paperwhite 12 / macOS 15.6 / macFUSE 5.5.0: about 6 seconds from replug to verified storage. That measurement belongs to the earlier 2-second-debounce implementation, not this release. Release-specific measurements belong below only after real hardware testing.

## Reproduce

1. Quit competing MTP apps and launch KindleDock.
2. Insert/unlock the supported Kindle; wait for a `documents verified` status.
3. Read the `Ready in` line. Repeat with the same Mac, cable and port.
4. Also test unplug/replug and manual eject. A mount-table entry alone is not success.

A cold app launch can include startup work before USB notification registration. Numbers from different attachment paths should not be treated as a controlled comparison.
