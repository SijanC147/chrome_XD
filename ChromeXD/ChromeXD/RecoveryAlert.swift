import AppKit
import SwiftUI

/// Recovery options for failed Chrome launch
enum RecoveryOption {
    case revert      // Revert to last working config
    case keep        // Keep current config anyway
    case edit        // Open settings to edit
}

/// Shows a recovery dialog when Chrome fails to launch with current flags
class RecoveryAlert {

    /// Show recovery alert with collapsible stderr output
    /// - Parameters:
    ///   - stderr: The stderr output from the failed Chrome launch
    ///   - completion: Called with the user's choice
    static func show(stderr: String, completion: @escaping (RecoveryOption) -> Void) {
        let alert = NSAlert()
        alert.messageText = "Chrome Launch Failed"
        alert.informativeText = "Chrome failed to start with the current flags configuration. This may indicate invalid or incompatible flags."
        alert.alertStyle = .warning

        // Add buttons (in reverse order for macOS button layout)
        alert.addButton(withTitle: "Revert to Working Config")  // First = default
        alert.addButton(withTitle: "Edit Flags")
        alert.addButton(withTitle: "Keep Current Config")

        // Add accessory view with collapsible stderr
        let accessoryView = createAccessoryView(stderr: stderr)
        alert.accessoryView = accessoryView

        // Show the alert
        let response = alert.runModal()

        switch response {
        case .alertFirstButtonReturn:
            completion(.revert)
        case .alertSecondButtonReturn:
            completion(.edit)
        case .alertThirdButtonReturn:
            completion(.keep)
        default:
            completion(.keep)
        }
    }

    /// Create the accessory view with collapsible error details
    private static func createAccessoryView(stderr: String) -> NSView {
        let container = NSStackView()
        container.orientation = .vertical
        container.alignment = .leading
        container.spacing = 8

        // Disclosure triangle + label
        let disclosureRow = NSStackView()
        disclosureRow.orientation = .horizontal
        disclosureRow.spacing = 4

        let disclosureButton = NSButton()
        disclosureButton.bezelStyle = .disclosure
        disclosureButton.title = ""
        disclosureButton.setButtonType(.onOff)
        disclosureButton.state = .off

        let detailsLabel = NSTextField(labelWithString: "Error Details")
        detailsLabel.font = NSFont.systemFont(ofSize: 11)
        detailsLabel.textColor = .secondaryLabelColor

        disclosureRow.addArrangedSubview(disclosureButton)
        disclosureRow.addArrangedSubview(detailsLabel)

        // Scrollable text view for stderr
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.borderType = .bezelBorder
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        let textView = NSTextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.font = NSFont.monospacedSystemFont(ofSize: 10, weight: .regular)
        textView.backgroundColor = NSColor.textBackgroundColor
        textView.string = stderr.isEmpty ? "(No error output captured)" : stderr

        scrollView.documentView = textView
        scrollView.isHidden = true

        // Constraints for scroll view
        NSLayoutConstraint.activate([
            scrollView.widthAnchor.constraint(equalToConstant: 450),
            scrollView.heightAnchor.constraint(equalToConstant: 150)
        ])

        // Toggle action
        disclosureButton.target = RecoveryAlertHelper.shared
        RecoveryAlertHelper.shared.scrollView = scrollView
        disclosureButton.action = #selector(RecoveryAlertHelper.toggleDisclosure(_:))

        container.addArrangedSubview(disclosureRow)
        container.addArrangedSubview(scrollView)

        return container
    }
}

/// Helper class to handle disclosure button toggle (NSButton target must be NSObject)
private class RecoveryAlertHelper: NSObject {
    static let shared = RecoveryAlertHelper()
    weak var scrollView: NSScrollView?

    @objc func toggleDisclosure(_ sender: NSButton) {
        scrollView?.isHidden = sender.state == .off

        // Resize the alert window to accommodate the change
        if let window = sender.window {
            var frame = window.frame
            if sender.state == .on {
                frame.size.height += 160
                frame.origin.y -= 160
            } else {
                frame.size.height -= 160
                frame.origin.y += 160
            }
            window.setFrame(frame, display: true, animate: true)
        }
    }
}

// MARK: - SwiftUI Alternative (for potential future use)

struct RecoveryAlertView: View {
    let stderr: String
    @State private var showDetails = false
    var onRevert: () -> Void
    var onEdit: () -> Void
    var onKeep: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.yellow)
                    .font(.largeTitle)
                VStack(alignment: .leading) {
                    Text("Chrome Launch Failed")
                        .font(.headline)
                    Text("Chrome failed to start with the current flags configuration.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // Collapsible details
            DisclosureGroup("Error Details", isExpanded: $showDetails) {
                ScrollView {
                    Text(stderr.isEmpty ? "(No error output captured)" : stderr)
                        .font(.system(.caption, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
                .frame(height: 150)
                .background(Color(NSColor.textBackgroundColor))
                .cornerRadius(4)
            }

            Divider()

            // Buttons
            HStack {
                Button("Keep Current Config", action: onKeep)
                    .buttonStyle(.borderless)

                Spacer()

                Button("Edit Flags", action: onEdit)

                Button("Revert to Working Config", action: onRevert)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(width: 450)
    }
}
