# Changelog

## 0.2.0 — 2026-11-16

First KindleDock release, based on `voantony/kindle-mtp-mount`.

### Added

- USB-driven automatic mounting and login launch.
- Connection-identity tracking, stale-volume cleanup and bounded storage verification.
- Regression tests for eject, reconnect during cleanup, fast replug and occupied devices.
- Self-contained macOS installer and GitHub Actions Release builds.
- Bilingual documentation and explicit dependency/license/signing boundaries.

### Improved

- Native IOKit discovery and `getmntinfo` checks replace polling shell processes.
- Device settling reduced to 350 ms; successful mounts report actual elapsed time.
- Cold-launch URL commands are queued until the app model is ready.
- Existing macFUSE 5.5+ is preserved by the installer.
