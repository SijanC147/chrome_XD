import Cocoa

class ChromeMonitor {

    private let launcher: ChromeLauncher
    private let chromeBundleID = "com.google.Chrome"
    private var observerToken: NSObjectProtocol?

    /// Get required flags from configuration manager
    private var requiredFlags: [String] {
        return FlagsConfigurationManager.shared.currentFlags
    }

    init(launcher: ChromeLauncher) {
        self.launcher = launcher
    }

    func startMonitoring() {
        observerToken = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didLaunchApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleAppLaunch(notification)
        }
        print("ChromeMonitor: Started watching for Chrome launches")
    }

    func stopMonitoring() {
        if let token = observerToken {
            NSWorkspace.shared.notificationCenter.removeObserver(token)
        }
    }

    private func handleAppLaunch(_ notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
              app.bundleIdentifier == chromeBundleID else {
            return
        }

        let pid = app.processIdentifier
        print("ChromeMonitor: Chrome launched (PID: \(pid))")

        // Give Chrome a moment to fully initialize
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.inspectAndCorrectChrome(app: app, pid: pid)
        }
    }

    private func inspectAndCorrectChrome(app: NSRunningApplication, pid: pid_t) {
        // Get Chrome's command-line arguments
        guard let args = ProcessInspector.getArguments(for: pid) else {
            print("ChromeMonitor: Could not inspect Chrome arguments")
            return
        }

        print("ChromeMonitor: Chrome args = \(args)")

        // Check if required flags are present
        if hasRequiredFlags(args) {
            print("ChromeMonitor: Chrome launched with correct flags ✓")
            // Mark as working since Chrome launched successfully with our flags
            FlagsConfigurationManager.shared.markCurrentAsWorking()
            return
        }

        print("ChromeMonitor: Chrome launched WITHOUT flags - restarting...")

        // Extract any URLs that were passed
        let urls = extractURLs(from: args)

        // Terminate the unwrapped Chrome
        app.terminate()

        // Wait for termination then relaunch with flags
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.launcher.launchChromeWithFlags(urls: urls)
        }
    }

    private func hasRequiredFlags(_ args: [String]) -> Bool {
        let currentFlags = requiredFlags

        for flag in currentFlags {
            // Check if the flag is present in any argument
            let flagFound = args.contains { arg in
                // For the disable-features flag, check if it contains the key parts
                if flag.contains("--disable-features=") {
                    // Extract the features from the flag
                    if let featuresStart = flag.firstIndex(of: "=") {
                        let features = String(flag[flag.index(after: featuresStart)...])
                            .split(separator: ",")
                            .map { String($0) }
                        // Check all features are present in the arg
                        return features.allSatisfy { feature in
                            arg.contains(feature)
                        }
                    }
                }
                // For other flags, check exact or prefix match
                return arg == flag || arg.hasPrefix(flag.split(separator: "=").first.map(String.init) ?? flag)
            }
            if !flagFound {
                return false
            }
        }
        return true
    }

    private func extractURLs(from args: [String]) -> [URL] {
        return args.compactMap { arg in
            if arg.hasPrefix("http://") || arg.hasPrefix("https://") {
                return URL(string: arg)
            }
            return nil
        }
    }
}
