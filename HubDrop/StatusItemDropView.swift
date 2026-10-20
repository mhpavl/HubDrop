import AppKit

/// A transparent view laid over the status item button so files can be dropped
/// straight onto the menu bar icon. Clicks are forwarded to the button beneath it.
final class StatusItemDropView: NSView {
    var onDrop: (([URL]) -> Void)?

    private weak var button: NSStatusBarButton?

    private static let readingOptions: [NSPasteboard.ReadingOptionKey: Any] = [.urlReadingFileURLsOnly: true]

    init(covering button: NSStatusBarButton) {
        self.button = button
        super.init(frame: button.bounds)
        autoresizingMask = [.width, .height]
        registerForDraggedTypes([.fileURL])
        button.addSubview(self)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // This view sits on top of the button, so it receives the click. Hand it back.
    override func mouseDown(with event: NSEvent) {
        button?.performClick(nil)
    }

    // MARK: - NSDraggingDestination

    override func draggingEntered(_ sender: any NSDraggingInfo) -> NSDragOperation {
        guard sender.draggingPasteboard.canReadObject(forClasses: [NSURL.self], options: Self.readingOptions) else {
            return []
        }
        button?.highlight(true)
        return .copy
    }

    override func draggingExited(_ sender: (any NSDraggingInfo)?) {
        button?.highlight(false)
    }

    override func draggingEnded(_ sender: any NSDraggingInfo) {
        button?.highlight(false)
    }

    override func performDragOperation(_ sender: any NSDraggingInfo) -> Bool {
        let urls = sender.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: Self.readingOptions) as? [URL] ?? []
        guard !urls.isEmpty else { return false }
        onDrop?(urls)
        return true
    }
}
