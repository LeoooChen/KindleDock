// KindleDock: automatic Finder mounting for supported Kindle MTP devices
// by running the bundled kindle-mtpfs helper (macFUSE FSKit backend + libmtp).
// MIT licensed. See LICENSE.
import SwiftUI
import AppKit
import IOKit
import Darwin

let mountPoint = "/Volumes/Kindle"
let settingsPath = "System Settings > General > Login Items & Extensions > File System Extensions > macFUSE"
let logURL = FileManager.default.homeDirectoryForCurrentUser
    .appendingPathComponent("Library/Logs/KindleDock.log")

/// Mask anything that looks like a Kindle serial (G + 3 or more of [0-9A-Z]).
func redact(_ s: String) -> String {
    s.replacingOccurrences(of: "G[0-9A-Z]{3,}", with: "GR…(redacted)", options: .regularExpression)
}

func appendLog(_ s: String) {
    let line = redact(s.hasSuffix("\n") ? s : s + "\n")
    let df = ISO8601DateFormatter(); df.timeZone = .current
    let stamped = line.split(separator: "\n", omittingEmptySubsequences: false)
        .filter { !$0.isEmpty }.map { "\(df.string(from: Date())) \($0)\n" }.joined()
    try? FileManager.default.createDirectory(at: logURL.deletingLastPathComponent(), withIntermediateDirectories: true)
    if let h = try? FileHandle(forWritingTo: logURL) {
        h.seekToEndOfFile(); h.write(stamped.data(using: .utf8)!); try? h.close()
    } else {
        try? stamped.write(to: logURL, atomically: true, encoding: .utf8)
    }
}

/// Run a short command and return (exit code, combined output).
@discardableResult
func run(_ path: String, _ args: [String]) -> (Int32, String) {
    let p = Process(); p.executableURL = URL(fileURLWithPath: path); p.arguments = args
    let pipe = Pipe(); p.standardOutput = pipe; p.standardError = pipe
    do { try p.run() } catch { return (-1, "\(error)") }
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    p.waitUntilExit()
    return (p.terminationStatus, String(decoding: data, as: UTF8.self))
}

func macFUSEInstalled() -> Bool {
    guard let data = try? Data(contentsOf: URL(fileURLWithPath: "/Library/Filesystems/macfuse.fs/Contents/Info.plist")),
          let info = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
          let version = info["CFBundleShortVersionString"] as? String else { return false }
    return version.compare("5.5.0", options: .numeric) != .orderedAscending
        && FileManager.default.fileExists(atPath: "/usr/local/lib/libfuse3.4.dylib")
}

func calibreRunning() -> Bool {
    if NSWorkspace.shared.runningApplications.contains(where: {
        ($0.bundleIdentifier ?? "").lowercased().contains("kovidgoyal.calibre")
            || ($0.bundleURL?.lastPathComponent ?? "").lowercased() == "calibre.app" }) { return true }
    return NSWorkspace.shared.runningApplications.contains {
        ["io.ganeshrvel.openmtp", "io.github.voantony.mountkindle"].contains($0.bundleIdentifier ?? "")
    }
}

/// Read the small root directory with a deadline, so a stale FUSE mount cannot
/// be announced as usable just because it still appears in the mount table.
func verifyStorage() -> Bool {
    let p = Process(); p.executableURL = URL(fileURLWithPath: "/bin/ls")
    p.arguments = ["-1", mountPoint]
    let pipe = Pipe(); p.standardOutput = pipe; p.standardError = FileHandle.nullDevice
    do { try p.run() } catch { return false }
    let deadline = Date().addingTimeInterval(8)
    while p.isRunning && Date() < deadline { Thread.sleep(forTimeInterval: 0.05) }
    if p.isRunning {
        p.terminate()
        Thread.sleep(forTimeInterval: 0.2)
        if p.isRunning { kill(p.processIdentifier, SIGKILL) }
        return false
    }
    let out = String(decoding: pipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
    return p.terminationStatus == 0 && out.split(separator: "\n").contains("documents")
}

enum Phase: Equatable { case idle, mounting, mounted, unmounting }

@MainActor
final class Model: ObservableObject {
    @Published var phase: Phase = .idle
    @Published var status = "Not mounted"
    @Published var message: String? = nil
    @Published var readOnly = UserDefaults.standard.bool(forKey: "readOnly") {
        didSet { UserDefaults.standard.set(readOnly, forKey: "readOnly") }
    }
    @Published var autoMount = UserDefaults.standard.object(forKey: "autoMount") as? Bool ?? true {
        didSet {
            UserDefaults.standard.set(autoMount, forKey: "autoMount")
            if autoMount {
                autoPolicy.reenable(now: ProcessInfo.processInfo.systemUptime)
                scheduleAutomaticMount()
            }
        }
    }
    @Published var launchAtLogin = UserDefaults.standard.object(forKey: "launchAtLogin") as? Bool ?? true {
        didSet {
            UserDefaults.standard.set(launchAtLogin, forKey: "launchAtLogin")
            configureLoginLauncher()
        }
    }
    private var autoPolicy = AutoMountPolicy()
    private var usbMonitor: USBMonitor?
    private var automaticWork: DispatchWorkItem?
    private var volumeObserver: NSObjectProtocol?
    private var connectionStarted: Double?
    private var helperStarted: Double?
    private var pendingQuit = false
    private var helper: Process?
    private var sessionConnectionID: UInt64?
    private var helperOutput = ""
    private var timer: Timer?

    init() {
        let monitor = USBMonitor { [weak self] in
            Task { @MainActor in self?.refresh() }
        }
        usbMonitor = monitor
        let nativeNotifications = monitor.start()
        appendLog(nativeNotifications ? "USB event notifications enabled" : "USB events unavailable; using fallback checks")
        volumeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didUnmountNotification, object: nil, queue: .main
        ) { [weak self] _ in Task { @MainActor in self?.refresh() } }
        refresh()
        // Native events handle the fast path. This low-frequency check covers
        // unusual sleep/wake and filesystem notification loss without shelling out.
        timer = Timer.scheduledTimer(withTimeInterval: nativeNotifications ? 15 : 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
        configureLoginLauncher()
    }

    private func configureLoginLauncher() {
        do { try LoginLauncher.configure(enabled: launchAtLogin) }
        catch { appendLog("Could not update login launcher: \(error.localizedDescription)") }
    }

    private func scheduleAutomaticMount() {
        automaticWork?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.refresh() }
        automaticWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + autoPolicy.settleDelay + 0.02, execute: work)
    }

    var helperPath: String {
        Bundle.main.bundleURL.appendingPathComponent("Contents/Helpers/kindle-mtpfs").path
    }

    func setStatus(_ s: String, message m: String? = nil) {
        status = s; message = m
        appendLog("status: \(s)" + (m.map { " | \($0)" } ?? ""))
    }

    func refresh() {
        let now = ProcessInfo.processInfo.systemUptime
        let connection = kindleConnectionID()
        if connection != autoPolicy.connectionID {
            connectionStarted = connection == nil ? nil : now
            automaticWork?.cancel()
            if connection != nil { scheduleAutomaticMount() }
            appendLog(connection != nil ? "USB connected; waiting for device readiness" : "USB disconnected; cleaning up previous mount")
        }
        autoPolicy.updateConnection(connection, now: now)
        if phase != .unmounting && autoPolicy.requiresCleanup(sessionConnectionID: sessionConnectionID,
                                                              hasSession: helper != nil || phase == .mounted) {
            unmount(afterDisconnect: true)
            return
        }
        guard phase == .idle || phase == .mounted else { return }
        guard connection != nil || phase != .idle else { return }
        let m = isMounted()
        if m && phase != .mounted {
            phase = .mounted; sessionConnectionID = connection; status = "Mounted at \(mountPoint)"
        }
        if m { autoPolicy.suppressUntilDisconnect() }
        if !m && phase == .mounted {
            // Let the old helper release USB before a new connection is mounted.
            if helper?.isRunning == true { return }
            phase = .idle; status = "Not mounted"; helper = nil; sessionConnectionID = nil
        }
        if autoPolicy.claimAttempt(enabled: autoMount, idle: phase == .idle && helper == nil, now: now) {
            appendLog("Auto-mounting connected Kindle")
            mount()
        }
    }

    func mount() {
        guard phase == .idle else { return }
        autoPolicy.suppressUntilDisconnect()
        if isMounted() {
            phase = .mounted; sessionConnectionID = kindleConnectionID()
            setStatus("Mounted at \(mountPoint)"); return
        }
        if !macFUSEInstalled() {
            setStatus("macFUSE 5.5+ is required", message: "Run the KindleDock installer or install macFUSE 5.5+ from https://macfuse.github.io/; then approve its filesystem extension."); return
        }
        if calibreRunning() {
            setStatus("Another transfer app is running", message: "Quit Calibre, OpenMTP or the old Mount Kindle app, then choose Mount. Only one app can use the Kindle at a time."); return
        }
        if kindleConnectionID() == nil {
            setStatus("No Kindle found", message: "Plug in the Kindle with a USB data cable and unlock it."); return
        }
        guard FileManager.default.isExecutableFile(atPath: helperPath) else {
            setStatus("App is damaged", message: "The bundled helper is missing. Download the app again."); return
        }
        phase = .mounting; setStatus("Mounting…")
        helperOutput = ""
        let p = Process()
        p.executableURL = URL(fileURLWithPath: helperPath)
        p.arguments = (readOnly ? ["--ro"] : []) + [mountPoint]
        let pipe = Pipe(); p.standardOutput = pipe; p.standardError = pipe
        pipe.fileHandleForReading.readabilityHandler = { h in
            let d = h.availableData
            guard !d.isEmpty else { h.readabilityHandler = nil; return }
            let s = redact(String(decoding: d, as: UTF8.self))
            appendLog(s)
            Task { @MainActor in self.helperOutput += s }
        }
        p.terminationHandler = { proc in
            let code = proc.terminationStatus
            // let the last output chunks land before classifying the exit
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                guard self.helper === proc else { return }
                self.helperExited(code)
            }
        }
        do { try p.run() } catch {
            phase = .idle; setStatus("Couldn't start the helper", message: "\(error)"); return
        }
        helper = p
        helperStarted = ProcessInfo.processInfo.systemUptime
        sessionConnectionID = kindleConnectionID()
        appendLog("started helper pid \(p.processIdentifier) \(readOnly ? "read-only" : "read-write")")
        waitForMount(process: p, deadline: Date().addingTimeInterval(90))
    }

    private func waitForMount(process: Process, deadline: Date) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [self] in
            guard phase == .mounting && helper === process else { return }
            if isMounted() {
                DispatchQueue.global().async {
                    let readable = verifyStorage()
                    DispatchQueue.main.async {
                        guard self.phase == .mounting && self.helper === process else { return }
                        if readable {
                            self.phase = .mounted
                            let now = ProcessInfo.processInfo.systemUptime
                            let total = Int((now - (self.connectionStarted ?? self.helperStarted ?? now)) * 1000)
                            let filesystem = Int((now - (self.helperStarted ?? now)) * 1000)
                            appendLog("Ready in \(total) ms from USB detection; helper + filesystem \(filesystem) ms")
                            self.setStatus("Mounted at \(mountPoint)" + (self.readOnly ? " (read-only)" : "") + "; documents verified")
                        } else {
                            self.unmount {
                                self.setStatus("Storage unavailable", message: "The mounted volume did not expose documents. Reconnect or choose Mount to try again.")
                            }
                        }
                    }
                }
            } else if Date() > deadline {
                setStatus("Still mounting after 90 s", message: "Check ~/Library/Logs/KindleDock.log. Use Unmount to stop.")
                unmount {
                    self.setStatus("Mount timed out", message: "Reconnect the Kindle or choose Mount to try again.")
                }
            } else { waitForMount(process: process, deadline: deadline) }
        }
    }

    private func helperExited(_ code: Int32) {
        appendLog("helper exited (\(code))")
        // The cleanup worker owns state until the old volume and process are gone.
        if phase == .unmounting { return }
        helper = nil
        sessionConnectionID = nil
        let out = helperOutput
        if phase == .mounted || code == 0 {
            phase = .idle; setStatus("Not mounted. Kindle released.", message: message); return
        }
        phase = .idle
        if out.contains("extension not enabled") || out.contains("requires approval") {
            setStatus("File system extension is off",
                      message: "Turn it on once in \(settingsPath) (switch on), then Mount again. Don't enable kernel extensions in Recovery Mode; that isn't needed.")
        } else if out.contains("probably busy") || out.contains("LIBUSB_ERROR_BUSY") || out.contains("LIBUSB_ERROR_ACCESS") {
            setStatus("Kindle is busy", message: "Another app is using the Kindle. Quit Calibre, kpush, Android File Transfer or OpenMTP, then try again.")
        } else if out.contains("no Kindle") {
            setStatus("No Kindle found", message: "Plug in the Kindle and unlock it.")
        } else {
            let tail = out.split(separator: "\n").suffix(3).joined(separator: "\n")
            setStatus("Mount failed", message: tail.isEmpty ? "exit code \(code)" : tail)
        }
    }

    func unmount(afterDisconnect: Bool = false, then done: (() -> Void)? = nil) {
        if !afterDisconnect { autoPolicy.suppressUntilDisconnect() }
        guard phase == .mounted || phase == .mounting else { done?(); return }
        phase = .unmounting
        setStatus(afterDisconnect ? "Cleaning up disconnected Kindle…" : "Unmounting…")
        let p = helper
        DispatchQueue.global().async {
            var r = run("/sbin/umount", afterDisconnect ? ["-f", mountPoint] : [mountPoint])
            if r.0 != 0 && isMounted() {
                r = run("/usr/sbin/diskutil", afterDisconnect ? ["unmount", "force", mountPoint] : ["unmount", mountPoint])
            }
            if let p = p {
                for _ in 0..<(afterDisconnect ? 4 : 30) where p.isRunning { Thread.sleep(forTimeInterval: 0.5) }
                if p.isRunning {
                    p.terminate()
                    for _ in 0..<(afterDisconnect ? 4 : 20) where p.isRunning { Thread.sleep(forTimeInterval: 0.5) }
                }
                // Only a helper for an already detached USB connection can be killed.
                if afterDisconnect && p.isRunning { kill(p.processIdentifier, SIGKILL) }
            }
            let still = isMounted()
            let out = redact(r.1)
            DispatchQueue.main.async {
                if still {
                    self.phase = .mounted
                    self.setStatus("Couldn't unmount", message: "Close any Finder windows or apps using the Kindle and try again. " + out)
                } else {
                    self.phase = .idle; self.helper = nil; self.sessionConnectionID = nil
                    self.setStatus("Not mounted. Kindle released.")
                    if self.pendingQuit { NSApp.terminate(nil) }
                    else { self.refresh() }
                }
                done?()
            }
        }
    }

    func openInFinder() { NSWorkspace.shared.open(URL(fileURLWithPath: mountPoint)) }

    func quit() {
        pendingQuit = true
        automaticWork?.cancel()
        if phase == .unmounting { return }
        if phase == .mounted || phase == .mounting { unmount() }
        else { NSApp.terminate(nil) }
    }
}

/// kindledock://mount, kindledock://unmount, kindledock://quit (for scripts and agents).
final class AppDelegate: NSObject, NSApplicationDelegate {
    var model: Model? {
        didSet { deliverPendingCommand() }
    }
    private var pendingCommand: String?
    private func deliverPendingCommand() {
        guard let command = pendingCommand else { return }
        Task { @MainActor in
            guard let m = self.model else { return }
            self.pendingCommand = nil
            switch command {
            case "mount": m.mount()
            case "unmount": m.unmount()
            case "quit": m.quit()
            default: break
            }
        }
    }
    func applicationDidFinishLaunching(_ n: Notification) {
        NSAppleEventManager.shared().setEventHandler(self, andSelector: #selector(handleURL(_:reply:)),
            forEventClass: AEEventClass(kInternetEventClass), andEventID: AEEventID(kAEGetURL))
        appendLog("KindleDock started")
    }
    @objc func handleURL(_ e: NSAppleEventDescriptor, reply: NSAppleEventDescriptor) {
        guard let s = e.paramDescriptor(forKeyword: keyDirectObject)?.stringValue, let u = URL(string: s) else { return }
        pendingCommand = u.host
        deliverPendingCommand()
    }
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        // Release the Kindle if the app is quit while mounted (for example at logout).
        if isMounted() { _ = run("/sbin/umount", [mountPoint]) }
        return .terminateNow
    }
}

@main
struct KindleDockApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var model = Model()

    var body: some Scene {
        MenuBarExtra {
            MenuContent(model: model).onAppear { delegate.model = model }
        } label: {
            Image(systemName: model.phase == .mounted ? "book.fill" : "book")
                .onAppear { delegate.model = model }
        }
        .menuBarExtraStyle(.menu)
    }
}

struct MenuContent: View {
    @ObservedObject var model: Model
    var body: some View {
        Text(model.status)
        if let m = model.message { Text(m) }
        Divider()
        Button("Mount") { model.mount() }.disabled(model.phase != .idle)
        Button("Unmount") { model.unmount() }.disabled(model.phase != .mounted)
        Button("Open in Finder") { model.openInFinder() }.disabled(model.phase != .mounted)
        Toggle("Read-only", isOn: $model.readOnly).disabled(model.phase != .idle)
        Toggle("Auto-mount on connection", isOn: $model.autoMount)
        Toggle("Launch at login", isOn: $model.launchAtLogin)
        Button("Show logs") { NSWorkspace.shared.open(logURL) }
        Button("Help & setup") { NSWorkspace.shared.open(URL(string: "https://github.com/LeoooChen/KindleDock#快速开始")!) }
        Divider()
        Text(model.readOnly ? "Read-only: changes are refused" : "Read-write: deletes on the Kindle are permanent")
        Button("Quit") { model.quit() }.keyboardShortcut("q")
    }
}
