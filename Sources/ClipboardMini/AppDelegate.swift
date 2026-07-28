import Cocoa
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var popover: NSPopover!
    let store = ClipboardStore()
    private var hoverCheckTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "doc.on.clipboard.fill", accessibilityDescription: "Clipboard")
            button.action = #selector(togglePopover(_:))
            button.target = self
            // Hover-to-open: tracking area reports mouse enter/exit on the menu bar icon.
            let tracking = NSTrackingArea(
                rect: .zero,
                options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
                owner: self,
                userInfo: nil
            )
            button.addTrackingArea(tracking)
        }

        popover = NSPopover()
        popover.contentSize = NSSize(width: 360, height: 480)
        popover.behavior = .transient // closes automatically on outside click
        popover.contentViewController = NSHostingController(rootView: ContentView().environmentObject(store))
    }

    @objc func togglePopover(_ sender: AnyObject?) {
        if popover.isShown {
            popover.performClose(sender)
        } else {
            showPopover()
        }
    }

    private func showPopover() {
        guard let button = statusItem.button else { return }
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
    }

    // MARK: - Hover open/close

    @objc func mouseEntered(with event: NSEvent) {
        guard store.openOnHover, !popover.isShown else { return }
        showPopover()
        startHoverTracking()
    }

    @objc func mouseExited(with event: NSEvent) {
        // Closing is handled by the tracking timer, which keeps the popover
        // open while the mouse travels from the icon down into the popover.
    }

    /// While the popover was opened by hover, poll the mouse position and
    /// close as soon as it leaves both the status item and the popover.
    private func startHoverTracking() {
        hoverCheckTimer?.invalidate()
        hoverCheckTimer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: true) { [weak self] _ in
            self?.closePopoverIfMouseLeft()
        }
    }

    private func stopHoverTracking() {
        hoverCheckTimer?.invalidate()
        hoverCheckTimer = nil
    }

    private func closePopoverIfMouseLeft() {
        guard popover.isShown else {
            stopHoverTracking()
            return
        }
        guard store.openOnHover else { return } // user turned the option off mid-hover

        let mouse = NSEvent.mouseLocation
        var hoverFrames: [NSRect] = []
        if let buttonWindow = statusItem.button?.window {
            hoverFrames.append(buttonWindow.frame.insetBy(dx: -4, dy: -4))
        }
        if let popoverWindow = popover.contentViewController?.view.window {
            hoverFrames.append(popoverWindow.frame.insetBy(dx: -8, dy: -8))
        }
        if !hoverFrames.contains(where: { $0.contains(mouse) }) {
            popover.performClose(nil)
            stopHoverTracking()
        }
    }
}
