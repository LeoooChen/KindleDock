# Contributing

Small, reproducible changes are welcome. Please include device model, USB vendor/product ID, firmware, macOS version and the operation that failed. Redact serials and personal paths. Do not upload books or private files.

Read [AGENTS.md](AGENTS.md) and [BUILDING.md](docs/BUILDING.md). Run `scripts/test.sh`; app changes also need a local build. Installer changes need a package build and read-only product/choice validation.

Preserve these invariants:

- One automatic attempt per physical attachment; never steal an occupied device.
- A new USB registry identity gets a new session. Retire old helpers before reuse.
- Manual eject remains ejected. Ready means `documents` is readable, not just a mount-table entry.
- Only force cleanup for already-detached identities; user eject must flush normally.
- Keep the libmtp ABI version check and reset-on-close protection.
- macFUSE authorization is manual; no security workarounds.

Performance reports should include raw elapsed timings and the measurement path, rather than general speed claims. New device identities need hardware evidence before expanding the allowlist.
