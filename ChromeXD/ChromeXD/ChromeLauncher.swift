import Cocoa

/// Handles launching Chrome with configured flags
class ChromeLauncher {

    private let chromeBundleID = "com.google.Chrome"
    private let chromeAppURL = URL(fileURLWithPath: "/Applications/Google Chrome.app")
    private let chromeBinaryPath = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"

    /// Callback type for launch results
    typealias LaunchCompletion = (Bool, String?) -> Void  // (success, stderr if failed)

    /// Get current flags from configuration manager
    var currentFlags: [String] {
        return FlagsConfigurationManager.shared.currentFlags
    }

    /// Legacy accessor for backward compatibility
    var requiredFlags: [String] {
        return currentFlags
    }

    // MARK: - Standard Launch (NSWorkspace)

    /// Launch Chrome with configured flags using NSWorkspace
    /// This method doesn't capture stderr but is more reliable for general use
    func launchChromeWithFlags(urls: [URL] = []) {
        let config = NSWorkspace.OpenConfiguration()
        config.arguments = currentFlags + urls.map { $0.absoluteString }
        config.activates = true

        NSWorkspace.shared.openApplication(at: chromeAppURL, configuration: config) { [weak self] app, error in
            if let error = error {
                print("ChromeLauncher: Failed to launch Chrome - \(error.localizedDescription)")
                FlagsConfigurationManager.shared.recordLaunchFailure(stderr: error.localizedDescription)
            } else {
                print("ChromeLauncher: Chrome launched with \(self?.currentFlags.count ?? 0) flags ✓")
                // Mark config as working after successful launch
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    // Wait a bit to ensure Chrome actually started properly
                    if self?.isChromeRunning() == true {
                        FlagsConfigurationManager.shared.markCurrentAsWorking()
                    }
                }
            }
        }
    }

    // MARK: - Launch with Stderr Capture (Process)

    /// Launch Chrome with stderr capture using Process
    /// Use this for testing flag configurations
    func launchChromeWithStderrCapture(urls: [URL] = [], timeout: TimeInterval = 5.0, completion: @escaping LaunchCompletion) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else {
                DispatchQueue.main.async { completion(false, "Launcher deallocated") }
                return
            }

            let process = Process()
            process.executableURL = URL(fileURLWithPath: self.chromeBinaryPath)

            // Build arguments
            var arguments = self.currentFlags
            for url in urls {
                arguments.append(url.absoluteString)
            }
            process.arguments = arguments

            // Capture stderr
            let stderrPipe = Pipe()
            process.standardError = stderrPipe

            // Also capture stdout to prevent blocking
            let stdoutPipe = Pipe()
            process.standardOutput = stdoutPipe

            do {
                try process.run()
                print("ChromeLauncher: Started Chrome process with PID \(process.processIdentifier)")

                // Wait for a short time to see if Chrome crashes immediately
                let deadline = Date().addingTimeInterval(timeout)
                var stderrData = Data()

                // Read stderr in background
                let stderrHandle = stderrPipe.fileHandleForReading
                stderrData = stderrHandle.availableData

                // Check if process terminated quickly (indicates error)
                while process.isRunning && Date() < deadline {
                    Thread.sleep(forTimeInterval: 0.1)
                    if let additionalData = try? stderrHandle.availableData, !additionalData.isEmpty {
                        stderrData.append(additionalData)
                    }
                }

                let stderrString = String(data: stderrData, encoding: .utf8) ?? ""

                if process.isRunning {
                    // Chrome is still running - success!
                    DispatchQueue.main.async {
                        print("ChromeLauncher: Chrome launched successfully with stderr capture")
                        FlagsConfigurationManager.shared.markCurrentAsWorking()
                        FlagsConfigurationManager.shared.clearLastError()
                        completion(true, nil)
                    }
                } else {
                    // Chrome exited quickly - likely an error
                    let exitCode = process.terminationStatus
                    let errorMessage = stderrString.isEmpty
                        ? "Chrome exited with code \(exitCode)"
                        : stderrString

                    DispatchQueue.main.async {
                        print("ChromeLauncher: Chrome exited quickly with code \(exitCode)")
                        FlagsConfigurationManager.shared.recordLaunchFailure(stderr: errorMessage)
                        completion(false, errorMessage)
                    }
                }

            } catch {
                DispatchQueue.main.async {
                    let errorMessage = "Failed to start Chrome: \(error.localizedDescription)"
                    print("ChromeLauncher: \(errorMessage)")
                    FlagsConfigurationManager.shared.recordLaunchFailure(stderr: errorMessage)
                    completion(false, errorMessage)
                }
            }
        }
    }

    // MARK: - Test Launch

    /// Test the current flag configuration by launching Chrome and monitoring for errors
    func testConfiguration(completion: @escaping LaunchCompletion) {
        // Kill any existing Chrome first
        terminateChrome { [weak self] in
            // Wait for Chrome to fully terminate
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                self?.launchChromeWithStderrCapture(completion: completion)
            }
        }
    }

    // MARK: - URL Handling

    /// Open URLs in Chrome (launching if needed)
    func openURLs(_ urls: [URL]) {
        guard !urls.isEmpty else {
            launchChromeWithFlags()
            return
        }

        if isChromeRunning() {
            // Chrome already running - send URLs via NSWorkspace
            NSWorkspace.shared.open(
                urls,
                withAppBundleIdentifier: chromeBundleID,
                options: [],
                additionalEventParamDescriptor: nil,
                launchIdentifiers: nil
            )
        } else {
            // Launch Chrome with flags + URLs
            launchChromeWithFlags(urls: urls)
        }
    }

    /// Opens URLs in a new Chrome window (always creates new window, even if Chrome is running)
    func openURLsInNewWindow(_ urls: [URL]) {
        // Use Process() to invoke Chrome binary directly - this works even when Chrome is running
        // NSWorkspace.openApplication() with arguments only works for fresh launches
        let process = Process()
        process.executableURL = URL(fileURLWithPath: chromeBinaryPath)
        
        var args = currentFlags + ["--new-window"]
        args += urls.map { $0.absoluteString }
        process.arguments = args
        
        do {
            try process.run()
            print("ChromeLauncher: Opened \(urls.count) URL(s) in new Chrome window via Process() ✓")
        } catch {
            print("ChromeLauncher: Process() failed - \(error.localizedDescription)")
            // Fallback to NSWorkspace for fresh launch
            let config = NSWorkspace.OpenConfiguration()
            config.arguments = currentFlags + ["--new-window"] + urls.map { $0.absoluteString }
            config.activates = true
            NSWorkspace.shared.openApplication(at: chromeAppURL, configuration: config) { _, error in
                if let error = error {
                    print("ChromeLauncher: Fallback also failed - \(error.localizedDescription)")
                }
            }
        }
    }

    // MARK: - Chrome Process Management

    /// Check if Chrome is running
    func isChromeRunning() -> Bool {
        return !NSRunningApplication.runningApplications(withBundleIdentifier: chromeBundleID).isEmpty
    }

    /// Activate (bring to front) running Chrome
    func activateChrome() {
        NSRunningApplication.runningApplications(withBundleIdentifier: chromeBundleID)
            .first?.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
    }

    /// Terminate all Chrome processes
    func terminateChrome(completion: (() -> Void)? = nil) {
        let chromes = NSRunningApplication.runningApplications(withBundleIdentifier: chromeBundleID)

        if chromes.isEmpty {
            completion?()
            return
        }

        for chrome in chromes {
            chrome.terminate()
        }

        // Wait for termination
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            // Force kill if still running
            let stillRunning = NSRunningApplication.runningApplications(withBundleIdentifier: self?.chromeBundleID ?? "")
            for chrome in stillRunning {
                chrome.forceTerminate()
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                completion?()
            }
        }
    }

    /// Kill and restart Chrome with current flags
    func killAndRestartChrome() {
        terminateChrome { [weak self] in
            self?.launchChromeWithFlags()
        }
    }
}
