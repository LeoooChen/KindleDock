KindleDock brings supported MTP Kindles into Finder automatically.

- Native USB events, 350 ms settling and native mount-table checks.
- Automatic mount, reconnect cleanup, verified storage and intentional eject handling.
- Read-only mode, login launch and a menu-bar app.
- One `.pkg` containing the app, MTP/USB libraries and conditional macFUSE runtime installation. No Homebrew for end users.
- Installer preserves macFUSE 5.5+; it does not update NTFS tools or change Recovery/TCC settings.

**Requirements:** Apple Silicon, macOS 15.4+, supported USB identity `1949:9981`. Paperwhite 12 / KPW6 is hardware-tested; Colorsoft inherits upstream protocol support. This is not a universal MTP driver.

**First use:** this free build is unsigned/not notarized; macOS may require a per-installer security confirmation. macFUSE filesystem extension approval is manual and required once. No Recovery Mode security reduction is needed.

Download `KindleDock-arm64.pkg` (or open the `.dmg` and run its installer). `.zip` is the app alone for Macs that already have macFUSE 5.5+. SHA-256 checksums are included.

Based on [Antony Vo's kindle-mtp-mount](https://github.com/voantony/kindle-mtp-mount), with original MIT copyright and history retained. macFUSE and LGPL libraries retain their own licenses.
