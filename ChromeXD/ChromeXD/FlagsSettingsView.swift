import SwiftUI
import AppKit

/// View model for flags settings
class FlagsSettingsViewModel: ObservableObject {
    @Published var flags: [String]
    @Published var validationResult: FlagsValidationResult?
    @Published var isValidating = false
    @Published var showValidationAlert = false

    let originalFlags: [String]

    var hasChanges: Bool {
        flags != originalFlags
    }

    var canSave: Bool {
        !flags.isEmpty && flags.contains(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty })
    }

    init() {
        let current = FlagsConfigurationManager.shared.currentFlags
        self.flags = current
        self.originalFlags = current
    }

    func addFlag() {
        flags.append("")
    }

    func removeFlag(at index: Int) {
        guard flags.indices.contains(index) else { return }
        flags.remove(at: index)
    }

    func validate() {
        isValidating = true
        // Filter out empty flags for validation
        let nonEmptyFlags = flags.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        validationResult = FlagsValidator.shared.validate(flags: nonEmptyFlags)
        isValidating = false
        showValidationAlert = true
    }

    func save() -> Bool {
        // Filter out empty flags
        let cleanedFlags = flags.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        guard !cleanedFlags.isEmpty else { return false }

        FlagsConfigurationManager.shared.saveFlags(cleanedFlags, validationPassed: validationResult?.isValid)
        return true
    }

    func reset() {
        flags = originalFlags
        validationResult = nil
    }

    func resetToDefaults() {
        flags = FlagsConfigurationManager.defaultFlags
        validationResult = nil
    }
}

/// SwiftUI view for editing Chrome flags
struct FlagsSettingsView: View {
    @ObservedObject var viewModel: FlagsSettingsViewModel
    var onSave: (() -> Void)?
    var onCancel: (() -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView

            Divider()

            // Flags list
            flagsListView

            Divider()

            // Validation status
            if let result = viewModel.validationResult {
                validationStatusView(result: result)
                Divider()
            }

            // Buttons
            buttonsView
        }
        .frame(width: 500, height: 450)
        .alert("Validation Result", isPresented: $viewModel.showValidationAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            if let result = viewModel.validationResult {
                Text(validationMessage(result))
            }
        }
    }

    // MARK: - Header

    private var headerView: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Configure Chrome Flags")
                .font(.headline)
            Text("Each flag will be passed to Chrome on launch. Changes take effect on next Chrome restart.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Flags List

    private var flagsListView: some View {
        VStack(spacing: 0) {
            // List header
            HStack {
                Text("Flags")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
                Button(action: viewModel.addFlag) {
                    Label("Add Flag", systemImage: "plus.circle.fill")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)

            // Scrollable list
            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(Array(viewModel.flags.enumerated()), id: \.offset) { index, _ in
                        flagRowView(index: index)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 4)
            }
        }
    }

    private func flagRowView(index: Int) -> some View {
        HStack(spacing: 8) {
            // Flag input
            TextField("--flag-name or --flag=value", text: $viewModel.flags[index])
                .textFieldStyle(.roundedBorder)
                .font(.system(.body, design: .monospaced))

            // Validation indicator
            if let result = viewModel.validationResult {
                let flag = viewModel.flags[index].trimmingCharacters(in: .whitespaces)
                if !flag.isEmpty {
                    if result.invalidFlags.contains(flag) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                            .help("Unknown flag - may not be valid")
                    } else if result.validFlags.contains(flag) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .help("Valid flag")
                    }
                }
            }

            // Delete button
            Button(action: { viewModel.removeFlag(at: index) }) {
                Image(systemName: "minus.circle.fill")
                    .foregroundColor(.red)
            }
            .buttonStyle(.borderless)
            .disabled(viewModel.flags.count <= 1)
        }
    }

    // MARK: - Validation Status

    private func validationStatusView(result: FlagsValidationResult) -> some View {
        HStack {
            if result.isValid {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text("All flags validated successfully")
                    .foregroundColor(.green)
            } else {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                Text("\(result.invalidFlags.count) unknown flag(s) - saving is still allowed")
                    .foregroundColor(.orange)
            }
            Spacer()
        }
        .font(.caption)
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(result.isValid ? Color.green.opacity(0.1) : Color.orange.opacity(0.1))
    }

    // MARK: - Buttons

    private var buttonsView: some View {
        HStack(spacing: 12) {
            // Reset to defaults
            Button("Reset to Defaults") {
                viewModel.resetToDefaults()
            }
            .buttonStyle(.borderless)

            Spacer()

            // Cancel
            Button("Cancel") {
                onCancel?()
            }
            .keyboardShortcut(.cancelAction)

            // Validate
            Button("Validate") {
                viewModel.validate()
            }
            .disabled(viewModel.isValidating || !viewModel.canSave)

            // Save
            Button("Save") {
                if viewModel.save() {
                    onSave?()
                }
            }
            .keyboardShortcut(.defaultAction)
            .disabled(!viewModel.canSave)
        }
        .padding()
    }

    // MARK: - Helpers

    private func validationMessage(_ result: FlagsValidationResult) -> String {
        if result.isValid {
            return "All \(result.validFlags.count) flag(s) are recognized Chrome flags."
        } else {
            var message = "\(result.invalidFlags.count) flag(s) are not recognized:\n"
            for flag in result.invalidFlags.prefix(5) {
                message += "\n• \(flag)"
            }
            if result.invalidFlags.count > 5 {
                message += "\n• ... and \(result.invalidFlags.count - 5) more"
            }
            message += "\n\nYou can still save these flags, but they may not work as expected."
            return message
        }
    }
}

// MARK: - NSPanel Controller

class FlagsSettingsWindowController: NSWindowController {

    private var viewModel: FlagsSettingsViewModel!
    var onDismiss: ((Bool) -> Void)? // true = saved, false = cancelled

    convenience init() {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 450),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        panel.title = "Configure Flags"
        panel.isFloatingPanel = true
        panel.becomesKeyOnlyIfNeeded = false
        panel.level = .floating

        self.init(window: panel)

        viewModel = FlagsSettingsViewModel()

        let settingsView = FlagsSettingsView(
            viewModel: viewModel,
            onSave: { [weak self] in
                self?.handleSave()
            },
            onCancel: { [weak self] in
                self?.handleCancel()
            }
        )

        let hostingView = NSHostingView(rootView: settingsView)
        panel.contentView = hostingView

        panel.center()
    }

    private func handleSave() {
        onDismiss?(true)
        close()
    }

    private func handleCancel() {
        onDismiss?(false)
        close()
    }

    func showModal(relativeTo parentWindow: NSWindow? = nil) {
        if let parent = parentWindow {
            window?.center()
            parent.beginSheet(window!) { _ in }
        } else {
            showWindow(nil)
            window?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}
