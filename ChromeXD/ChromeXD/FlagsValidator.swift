import Foundation

/// Result of flags validation
struct FlagsValidationResult {
    let isValid: Bool
    let validFlags: [String]
    let invalidFlags: [String]
    let warnings: [String]

    var summary: String {
        if isValid {
            return "All \(validFlags.count) flag(s) are valid"
        } else {
            return "\(invalidFlags.count) invalid flag(s): \(invalidFlags.joined(separator: ", "))"
        }
    }
}

/// Validates Chrome flags against known flags database
class FlagsValidator {

    static let shared = FlagsValidator()

    /// Set of known valid Chrome flags (loaded from bundled JSON)
    private var knownFlags: Set<String> = []

    /// Map of flag to description (for tooltip/help)
    private var flagDescriptions: [String: String] = [:]

    private init() {
        loadKnownFlags()
    }

    // MARK: - Loading

    private func loadKnownFlags() {
        // Try to load from bundle
        guard let url = Bundle.main.url(forResource: "chrome-flags", withExtension: "json") else {
            print("FlagsValidator: chrome-flags.json not found in bundle")
            loadFallbackFlags()
            return
        }

        do {
            let data = try Data(contentsOf: url)
            let json = try JSONSerialization.jsonObject(with: data) as? [String: String] ?? [:]

            for (flag, description) in json {
                let normalizedFlag = normalizeFlag(flag)
                knownFlags.insert(normalizedFlag)
                if !description.isEmpty {
                    flagDescriptions[normalizedFlag] = description
                }
            }

            print("FlagsValidator: Loaded \(knownFlags.count) known flags")
        } catch {
            print("FlagsValidator: Failed to load chrome-flags.json: \(error)")
            loadFallbackFlags()
        }
    }

    private func loadFallbackFlags() {
        // Fallback: just validate that flags start with -- and have reasonable format
        print("FlagsValidator: Using fallback validation (format-only)")
    }

    /// Normalize a flag for comparison (extract base flag name)
    private func normalizeFlag(_ flag: String) -> String {
        var normalized = flag

        // Ensure it starts with --
        if !normalized.hasPrefix("--") {
            if normalized.hasPrefix("-") {
                normalized = "-" + normalized
            } else {
                normalized = "--" + normalized
            }
        }

        // Extract just the flag name (before = if present)
        if let equalIndex = normalized.firstIndex(of: "=") {
            normalized = String(normalized[..<equalIndex])
        }

        return normalized.lowercased()
    }

    // MARK: - Validation

    /// Validate a list of flags
    func validate(flags: [String]) -> FlagsValidationResult {
        var validFlags: [String] = []
        var invalidFlags: [String] = []
        var warnings: [String] = []

        for flag in flags {
            let trimmed = flag.trimmingCharacters(in: .whitespacesAndNewlines)

            // Skip empty strings
            if trimmed.isEmpty {
                continue
            }

            // Check format
            if !trimmed.hasPrefix("-") {
                invalidFlags.append(trimmed)
                warnings.append("'\(trimmed)' doesn't start with '-'")
                continue
            }

            // Normalize and check against known flags
            let normalizedFlag = normalizeFlag(trimmed)

            // If we have known flags loaded, validate against them
            if !knownFlags.isEmpty {
                if knownFlags.contains(normalizedFlag) {
                    validFlags.append(trimmed)
                } else {
                    // Unknown flag - still allow but warn
                    invalidFlags.append(trimmed)
                    warnings.append("'\(trimmed)' is not a known Chrome flag")
                }
            } else {
                // Fallback: just check format
                if trimmed.hasPrefix("--") && trimmed.count > 2 {
                    validFlags.append(trimmed)
                } else if trimmed.hasPrefix("-") && trimmed.count > 1 {
                    validFlags.append(trimmed)
                } else {
                    invalidFlags.append(trimmed)
                }
            }
        }

        return FlagsValidationResult(
            isValid: invalidFlags.isEmpty,
            validFlags: validFlags,
            invalidFlags: invalidFlags,
            warnings: warnings
        )
    }

    /// Get description for a flag (if available)
    func description(for flag: String) -> String? {
        let normalized = normalizeFlag(flag)
        return flagDescriptions[normalized]
    }

    /// Check if a single flag is known
    func isKnownFlag(_ flag: String) -> Bool {
        if knownFlags.isEmpty { return true } // Fallback mode
        return knownFlags.contains(normalizeFlag(flag))
    }

    /// Get suggestions for a partial flag name
    func suggestions(for partial: String, limit: Int = 5) -> [String] {
        let normalized = normalizeFlag(partial)
        return knownFlags
            .filter { $0.contains(normalized) }
            .sorted()
            .prefix(limit)
            .map { $0 }
    }
}
