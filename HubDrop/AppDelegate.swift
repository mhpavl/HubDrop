import AppKit
import SwiftUI

/// Owns the status item and the popover that hosts the SwiftUI panel.
final class AppDelegate: NSObject, NSApplicationDelegate {
    let model = HubDropModel()

    private var statusItem: NSStatusItem?
    private var dropView: StatusItemDropView?
    private var feedbackResetTask: Task<Void, Never>?

    private lazy var popover: NSPopover = {
        let popover = NSPopover()
        popover.behavior = .transient
        let host = NSHostingController(rootView: DropPanel().environment(model))
        host.sizingOptions = .preferredContentSize
        popover.contentViewController = host
        return popover
    }()

    func applicationDidFinishLaunching(_ notification: Notification) {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem = item

        guard let button = item.button else { return }
        button.image = Self.idleImage
        button.target = self
        button.action = #selector(togglePopover(_:))
        button.toolTip = "HubDrop: add media to simulators"

        let dropView = StatusItemDropView(covering: button)
        dropView.onDrop = { [weak self] urls in
            guard let self else { return }
            Task { await self.model.add(urls) }
        }
        self.dropView = dropView

        model.feedback = { [weak self] outcome in
            self?.flashFeedback(for: outcome)
        }
    }

    @objc private func togglePopover(_ sender: Any?) {
        if popover.isShown {
            popover.performClose(sender)
        } else {
            showPopover()
        }
    }

    private func showPopover() {
        guard let button = statusItem?.button else { return }
        NSApp.activate()
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
    }

    // MARK: - Status item feedback

    private static let idleImage = symbol("photo.badge.plus")

    private static func symbol(_ name: String) -> NSImage? {
        NSImage(systemSymbolName: name, accessibilityDescription: "HubDrop")
    }

    /// Swaps the status item image to a result glyph for a moment, and surfaces failures.
    private func flashFeedback(for outcome: HubDropModel.Outcome) {
        let symbolName = switch outcome {
        case .success: "checkmark.circle.fill"
        case .failure: "exclamationmark.triangle.fill"
        }
        statusItem?.button?.image = Self.symbol(symbolName)

        if case .failure = outcome, !popover.isShown {
            showPopover()
        }

        feedbackResetTask?.cancel()
        feedbackResetTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            self?.statusItem?.button?.image = Self.idleImage
        }
    }
}
