import Cocoa
import ServiceManagement

class AppDelegate: NSObject, NSApplicationDelegate {

    private var chromeMonitor: ChromeMonitor!
    private let chromeLauncher = ChromeLauncher()
    private var statusItem: NSStatusItem?
    private var launchAtLoginItem: NSMenuItem?
    private var flagsSettingsController: FlagsSettingsWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Start Chrome monitor
        chromeMonitor = ChromeMonitor(launcher: chromeLauncher)
        chromeMonitor.startMonitoring()

        // Setup menu bar status item
        setupStatusItem()

        // Check if there was a previous launch failure
        checkForPreviousLaunchFailure()

        print("ChromeXD: Started and monitoring for Chrome launches")
    }

    func applicationWillFinishLaunching(_ notification: Notification) {
        // Register for URL events before app finishes launching
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleGetURLEvent(_:withReplyEvent:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )
    }

    // MARK: - URL Handling

    func application(_ application: NSApplication, open urls: [URL]) {
        print("ChromeXD: Received URLs via application delegate: \(urls)")
        
        // Check if any URL uses the chromexd-new scheme (force new window)
        let newWindowURLs = urls.filter { $0.scheme == "chromexd-new" }
        let regularURLs = urls.filter { $0.scheme != "chromexd-new" }
        
        // Convert chromexd-new:// URLs to https://
        if !newWindowURLs.isEmpty {
            let convertedURLs = newWindowURLs.compactMap { url -> URL? in
                // chromexd-new://example.com/path -> https://example.com/path
                var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
                components?.scheme = "https"
                return components?.url
            }
            print("ChromeXD: Opening \(convertedURLs.count) URL(s) in NEW WINDOW")
            chromeLauncher.openURLsInNewWindow(convertedURLs)
        }
        
        // Handle regular URLs normally (may open in existing window/tab)
        if !regularURLs.isEmpty {
            chromeLauncher.openURLs(regularURLs)
        }
    }

    @objc func handleGetURLEvent(_ event: NSAppleEventDescriptor, withReplyEvent replyEvent: NSAppleEventDescriptor) {
        guard let urlString = event.paramDescriptor(forKeyword: AEKeyword(keyDirectObject))?.stringValue,
              let url = URL(string: urlString) else { return }
        print("ChromeXD: Received URL via Apple Event: \(url)")
        
        // Check if using chromexd-new scheme (force new window)
        if url.scheme == "chromexd-new" {
            // Convert chromexd-new://example.com/path -> https://example.com/path
            var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            components?.scheme = "https"
            if let convertedURL = components?.url {
                print("ChromeXD: Opening in NEW WINDOW: \(convertedURL)")
                chromeLauncher.openURLsInNewWindow([convertedURL])
            }
        } else {
            chromeLauncher.openURLs([url])
        }
    }

    // MARK: - Status Item (Menu Bar)

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            // Use custom template icon from Assets
            if let image = NSImage(named: "StatusBarIcon") {
                image.isTemplate = true  // Makes it adapt to menu bar appearance (light/dark mode)
                button.image = image
            } else {
                // Fallback: use SF Symbol
                if let sfImage = NSImage(systemSymbolName: "shield.checkered", accessibilityDescription: "ChromeXD") {
                    sfImage.isTemplate = true
                    button.image = sfImage
                } else {
                    // Ultimate fallback: simple text
                    button.title = "XD"
                }
            }
            button.toolTip = "ChromeXD - Chrome Extension Compatibility Wrapper"
        }

        let menu = NSMenu()

        // Status header
        let statusMenuItem = NSMenuItem(title: "ChromeXD Active", action: nil, keyEquivalent: "")
        statusMenuItem.isEnabled = false
        menu.addItem(statusMenuItem)

        menu.addItem(NSMenuItem.separator())

        // Open Chrome action
        let openChromeItem = NSMenuItem(title: "Open Chrome", action: #selector(openChrome), keyEquivalent: "o")
        openChromeItem.target = self
        menu.addItem(openChromeItem)

        // Check Chrome flags
        let checkFlagsItem = NSMenuItem(title: "Verify Chrome Flags", action: #selector(verifyFlags), keyEquivalent: "v")
        checkFlagsItem.target = self
        menu.addItem(checkFlagsItem)

        menu.addItem(NSMenuItem.separator())

        // Configure Flags
        let configureFlagsItem = NSMenuItem(title: "Configure Flags...", action: #selector(showConfigureFlags), keyEquivalent: ",")
        configureFlagsItem.target = self
        menu.addItem(configureFlagsItem)

        // Kill & Restart Chrome
        let restartChromeItem = NSMenuItem(title: "Kill & Restart Chrome", action: #selector(killAndRestartChrome), keyEquivalent: "r")
        restartChromeItem.target = self
        menu.addItem(restartChromeItem)

        menu.addItem(NSMenuItem.separator())

        // Launch at Login toggle
        launchAtLoginItem = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        launchAtLoginItem?.target = self
        updateLaunchAtLoginState()
        menu.addItem(launchAtLoginItem!)

        menu.addItem(NSMenuItem.separator())

        // About
        let aboutItem = NSMenuItem(title: "About ChromeXD", action: #selector(showAbout), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)

        menu.addItem(NSMenuItem.separator())

        // Quit
        let quitItem = NSMenuItem(title: "Quit ChromeXD", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)

        self.statusItem?.menu = menu
    }

    @objc private func openChrome() {
        chromeLauncher.launchChromeWithFlags()
    }

    @objc private func verifyFlags() {
        // Open chrome://version in Chrome to verify flags
        if let url = URL(string: "chrome://version") {
            chromeLauncher.openURLs([url])
        }
    }

    @objc private func showAbout() {
        let flags = FlagsConfigurationManager.shared.currentFlags
        let flagsList = flags.map { "• \($0)" }.joined(separator: "\n")

        let alert = NSAlert()
        alert.messageText = "ChromeXD"
        alert.informativeText = """
        Chrome Extension Compatibility Wrapper

        This app ensures Chrome always runs with your configured flags:

        \(flagsList)

        Set ChromeXD as your default browser to have all links open in Chrome with these flags.
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    // MARK: - Configure Flags

    @objc private func showConfigureFlags() {
        // Create and show the flags settings window
        flagsSettingsController = FlagsSettingsWindowController()
        flagsSettingsController?.onDismiss = { [weak self] saved in
            if saved {
                self?.handleFlagsConfigSaved()
            }
            self?.flagsSettingsController = nil
        }
        flagsSettingsController?.showModal()
    }

    private func handleFlagsConfigSaved() {
        print("AppDelegate: Flags configuration saved")

        // Offer to restart Chrome if it's running
        if chromeLauncher.isChromeRunning() {
            let alert = NSAlert()
            alert.messageText = "Restart Chrome?"
            alert.informativeText = "The flags have been saved. Chrome needs to be restarted for the new flags to take effect."
            alert.alertStyle = .informational
            alert.addButton(withTitle: "Restart Now")
            alert.addButton(withTitle: "Later")

            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                killAndRestartChrome()
            }
        }
    }

    // MARK: - Kill & Restart Chrome

    @objc private func killAndRestartChrome() {
        let chromeBundleID = "com.google.Chrome"
        let runningChromes = NSRunningApplication.runningApplications(withBundleIdentifier: chromeBundleID)

        if runningChromes.isEmpty {
            // Chrome not running, just launch it
            print("ChromeXD: Chrome not running, launching with flags")
            chromeLauncher.launchChromeWithFlags()
            return
        }

        print("ChromeXD: Killing \(runningChromes.count) Chrome process(es)")

        // Terminate all Chrome processes
        for chrome in runningChromes {
            chrome.terminate()
        }

        // Wait for Chrome to fully terminate, then relaunch
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            // Force kill if still running
            let stillRunning = NSRunningApplication.runningApplications(withBundleIdentifier: chromeBundleID)
            for chrome in stillRunning {
                chrome.forceTerminate()
            }

            // Wait a bit more then launch
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                print("ChromeXD: Relaunching Chrome with flags")
                self?.chromeLauncher.launchChromeWithFlags()
            }
        }
    }

    // MARK: - Launch Failure Recovery

    private func checkForPreviousLaunchFailure() {
        // Check if there's a stored stderr from a previous failed launch
        if let stderr = FlagsConfigurationManager.shared.lastStderr, !stderr.isEmpty {
            // Show recovery dialog
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.showRecoveryDialog(stderr: stderr)
            }
        }
    }

    private func showRecoveryDialog(stderr: String) {
        RecoveryAlert.show(stderr: stderr) { [weak self] option in
            switch option {
            case .revert:
                if FlagsConfigurationManager.shared.revertToLastWorking() {
                    FlagsConfigurationManager.shared.clearLastError()
                    self?.showRevertSuccessAlert()
                    // Optionally restart Chrome
                    if self?.chromeLauncher.isChromeRunning() == false {
                        self?.chromeLauncher.launchChromeWithFlags()
                    }
                } else {
                    self?.showNoWorkingConfigAlert()
                }

            case .edit:
                FlagsConfigurationManager.shared.clearLastError()
                self?.showConfigureFlags()

            case .keep:
                FlagsConfigurationManager.shared.clearLastError()
            }
        }
    }

    private func showRevertSuccessAlert() {
        let alert = NSAlert()
        alert.messageText = "Configuration Reverted"
        alert.informativeText = "Your flags have been reverted to the last known working configuration."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    private func showNoWorkingConfigAlert() {
        let alert = NSAlert()
        alert.messageText = "No Working Configuration"
        alert.informativeText = "There is no previous working configuration to revert to. The flags have been reset to defaults."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")

        FlagsConfigurationManager.shared.resetToDefaults()
        alert.runModal()
    }

    // MARK: - Launch at Login

    private func isLaunchAtLoginEnabled() -> Bool {
        if #available(macOS 13.0, *) {
            return SMAppService.mainApp.status == .enabled
        }
        return false
    }

    private func updateLaunchAtLoginState() {
        launchAtLoginItem?.state = isLaunchAtLoginEnabled() ? .on : .off
    }

    @objc private func toggleLaunchAtLogin() {
        if #available(macOS 13.0, *) {
            do {
                if SMAppService.mainApp.status == .enabled {
                    try SMAppService.mainApp.unregister()
                    print("ChromeXD: Unregistered from login items")
                } else {
                    try SMAppService.mainApp.register()
                    print("ChromeXD: Registered as login item")
                }
                updateLaunchAtLoginState()
            } catch {
                print("ChromeXD: Failed to toggle login item: \(error)")
                showLoginItemError(error)
            }
        } else {
            showUnsupportedAlert()
        }
    }

    private func showLoginItemError(_ error: Error) {
        let alert = NSAlert()
        alert.messageText = "Login Item Error"
        alert.informativeText = "Failed to change login item setting: \(error.localizedDescription)"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    private func showUnsupportedAlert() {
        let alert = NSAlert()
        alert.messageText = "Feature Not Available"
        alert.informativeText = "Launch at Login requires macOS 13.0 (Ventura) or later."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false  // Keep running in background
    }

    func applicationWillTerminate(_ notification: Notification) {
        chromeMonitor.stopMonitoring()
        print("ChromeXD: Shutting down")
    }
}
