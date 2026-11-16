# Build & release

## Requirements

Apple Silicon, macOS 15.4+, Xcode Command Line Tools, Python 3, Node.js (installer policy tests), Homebrew, official macFUSE **5.5.0+**, and **libmtp 1.1.23**. The MTP helper intentionally pins libmtp because it validates an internal structure before disabling reset-on-close. Do not silently loosen that version check.

Install build tools with `xcode-select --install` and install libmtp with `brew install libmtp`. Install macFUSE from its [official release](https://macfuse.github.io/) yourself. Building an app does not require enabling its filesystem extension; hardware tests do.

```sh
scripts/test.sh          # fake-MTP filesystem tests + Swift + native API + installer policy
app/build-app.sh         # dist/KindleDock.app, with bundled MTP/USB libraries
scripts/build-package.sh # .pkg, .dmg, portable .zip, SHA256SUMS.txt
```

The package builder downloads the official, pinned macFUSE 5.5.0 DMG, verifies its SHA-256 and vendor installer signature, then reuses its original core component. It never installs macFUSE on the build machine. The installer skips that component when a compatible runtime is already installed.

`macos-15` is GitHub's standard Apple Silicon runner. The workflow installs build dependencies only inside that disposable VM. PRs/main builds upload artifacts; `v*` tags publish a Release. Version tags must match `VERSION`.

```sh
# After updating VERSION, app/Info.plist, CHANGELOG.md and release notes:
git tag v0.2.0
git push origin main v0.2.0
```

## Signing

Default builds are ad-hoc signed; the outer installer is unsigned and not notarized. GitHub does not provide Apple Developer ID certificates. The project does not remove quarantine flags or disable Gatekeeper.

For your own paid Developer ID identities already installed in a keychain:

```sh
SIGNING_IDENTITY='Developer ID Application: Your Name (TEAMID)' app/build-app.sh
INSTALLER_SIGNING_IDENTITY='Developer ID Installer: Your Name (TEAMID)' scripts/build-package.sh
```

Use Apple's `notarytool` to notarize and `stapler` to staple the final installer before distribution. The default CI deliberately publishes unsigned packages without pretending they are notarized; add your own signing-secret workflow if you have the necessary certificates. Do not commit certificates or account credentials.

## Hardware validation

Use a supported Kindle and quit other MTP apps first. Read-only checks come before write tests. Write tests belong only in a new temporary directory under `documents`; never modify existing books, firmware or jailbreak files.

- A cold app launch with a connected device must mount and verify `documents`.
- Unplugging must retire the old virtual volume and helper.
- Replugging, including while cleanup runs, must get a fresh session.
- Finder eject must remain ejected until another physical attachment or manual Mount.
- An occupied Kindle must not trigger retry/reset loops.

See [performance notes](PERFORMANCE.md) for measurement boundaries.
