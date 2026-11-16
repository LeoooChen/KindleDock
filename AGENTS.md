# KindleDock contributor instructions

KindleDock forks `voantony/kindle-mtp-mount` (MIT). Preserve Antony Vo's copyright and source provenance. Default release target is Apple Silicon, macOS 15.4+, macFUSE 5.5+, and pinned libmtp 1.1.23.

## User-Mac boundaries

- Do not change System Settings, TCC/privacy settings or Recovery Mode security. A human approves the macFUSE filesystem extension.
- Do not install system/kernel extensions or use sudo on the user's Mac as part of an agent-driven build. `build-package.sh` only prepares an installer; the user runs it.
- The GitHub workflow may install build dependencies with sudo only in its disposable hosted VM. Installer scripts run with the privileges explicitly granted by a human running the package.
- Never reset/unplug the USB device programmatically or repeatedly try to claim an occupied Kindle. One automatic mount attempt per USB attachment.
- Only force-retire a helper/virtual volume for a USB identity that has already detached. Normal user eject/quit must flush and unmount gracefully.
- Never write/delete/rename existing Kindle content. Hardware write tests use a newly created temporary folder under `documents`, then remove only those test files.
- Mask serials in logs. Do not publish user logs, local paths, credentials, certificates or private device content.

## Working on the repo

Read README.md and docs/BUILDING.md. Run `scripts/test.sh` and `app/build-app.sh`; package changes also require `scripts/build-package.sh`, `installer -showChoicesXML` and `scripts/validate-package.py`.

Keep installer runtime downloads pinned and checksum-verified. Preserve a newer existing macFUSE installation, since NTFS/Mounty or other apps may share it. Never copy Homebrew-only paths into a released app.

Tests must cover the real reconnect failure: the old virtual volume can remain mounted after USB removal and while a new identity arrives. Finder presence is insufficient; verify `documents` before declaring readiness.

A public build without Developer ID certificates is unsigned/not notarized. Be candid about the first-use confirmation; never add `spctl`, quarantine removal or automatic extension approval as a workaround.
