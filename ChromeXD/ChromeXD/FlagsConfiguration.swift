import Foundation

/// Represents a flags configuration with metadata
struct FlagsConfig: Codable, Equatable {
    var flags: [String]
    var lastModified: Date
    var validationPassed: Bool?

    init(flags: [String], lastModified: Date = Date(), validationPassed: Bool? = nil) {
        self.flags = flags
        self.lastModified = lastModified
        self.validationPassed = validationPassed
    }
}

/// Manages Chrome flags configuration with persistence and recovery support
class FlagsConfigurationManager {

    static let shared = FlagsConfigurationManager()

    private let userDefaultsKey = "ChromeXD.FlagsConfig"
    private let lastWorkingKey = "ChromeXD.LastWorkingConfig"
    private let lastStderrKey = "ChromeXD.LastStderr"

    /// Default flags for MV2 extension compatibility
    static let defaultFlags: [String] = [
        "--disable-features=ExtensionManifestV2Unsupported,ExtensionManifestV2Disabled",
        "--silent-debugger-extension-api"
    ]

    private init() {
        // Ensure we have a config on first run
        if currentConfig == nil {
            let defaultConfig = FlagsConfig(flags: Self.defaultFlags, validationPassed: true)
            save(config: defaultConfig)
            saveAsLastWorking(config: defaultConfig)
        }
    }

    // MARK: - Current Configuration

    /// The current flags configuration
    var currentConfig: FlagsConfig? {
        get {
            guard let data = UserDefaults.standard.data(forKey: userDefaultsKey) else { return nil }
            return try? JSONDecoder().decode(FlagsConfig.self, from: data)
        }
    }

    /// The current flags array (convenience accessor)
    var currentFlags: [String] {
        return currentConfig?.flags ?? Self.defaultFlags
    }

    /// Save a new configuration
    func save(config: FlagsConfig) {
        var configToSave = config
        configToSave.lastModified = Date()

        if let data = try? JSONEncoder().encode(configToSave) {
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
            print("FlagsConfigurationManager: Saved config with \(configToSave.flags.count) flags")
        }
    }

    /// Save current flags with validation status
    func saveFlags(_ flags: [String], validationPassed: Bool?) {
        let config = FlagsConfig(flags: flags, validationPassed: validationPassed)
        save(config: config)
    }

    // MARK: - Last Working Configuration

    /// The last known working configuration
    var lastWorkingConfig: FlagsConfig? {
        get {
            guard let data = UserDefaults.standard.data(forKey: lastWorkingKey) else { return nil }
            return try? JSONDecoder().decode(FlagsConfig.self, from: data)
        }
    }

    /// Mark current config as working (call after successful Chrome launch)
    func markCurrentAsWorking() {
        if let current = currentConfig {
            saveAsLastWorking(config: current)
            print("FlagsConfigurationManager: Marked current config as working")
        }
    }

    /// Save a config as the last working one
    private func saveAsLastWorking(config: FlagsConfig) {
        if let data = try? JSONEncoder().encode(config) {
            UserDefaults.standard.set(data, forKey: lastWorkingKey)
        }
    }

    /// Revert to last known working configuration
    func revertToLastWorking() -> Bool {
        guard let lastWorking = lastWorkingConfig else {
            print("FlagsConfigurationManager: No last working config to revert to")
            return false
        }
        save(config: lastWorking)
        print("FlagsConfigurationManager: Reverted to last working config")
        return true
    }

    /// Check if current config differs from last working
    var hasUnsavedChangesFromWorking: Bool {
        guard let current = currentConfig, let lastWorking = lastWorkingConfig else {
            return false
        }
        return current.flags != lastWorking.flags
    }

    // MARK: - Error Tracking

    /// The stderr output from the last failed Chrome launch
    var lastStderr: String? {
        get { UserDefaults.standard.string(forKey: lastStderrKey) }
        set { UserDefaults.standard.set(newValue, forKey: lastStderrKey) }
    }

    /// Record a launch failure
    func recordLaunchFailure(stderr: String) {
        lastStderr = stderr
        print("FlagsConfigurationManager: Recorded launch failure")
    }

    /// Clear the last error
    func clearLastError() {
        lastStderr = nil
    }

    // MARK: - Reset

    /// Reset to default flags
    func resetToDefaults() {
        let defaultConfig = FlagsConfig(flags: Self.defaultFlags, validationPassed: true)
        save(config: defaultConfig)
        saveAsLastWorking(config: defaultConfig)
        clearLastError()
        print("FlagsConfigurationManager: Reset to defaults")
    }
}
