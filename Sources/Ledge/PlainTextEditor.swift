import AppKit
import LedgeCore
import SwiftUI

struct PlainTextEditor: NSViewRepresentable {
    static let contentInset = NSSize(width: 16, height: 14)

    @Binding var text: String
    let wantsFocus: Bool
    let placeholder: String

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true

        let textView = PlaceholderTextView(
            frame: scrollView.contentView.bounds
        )
        textView.delegate = context.coordinator
        textView.font = .systemFont(ofSize: 15)
        textView.textColor = .labelColor
        textView.drawsBackground = false
        textView.isRichText = false
        textView.importsGraphics = false
        textView.allowsUndo = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.textContainerInset = Self.contentInset
        textView.textContainer?.lineFragmentPadding = 0
        textView.textContainer?.widthTracksTextView = true
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.minSize = NSSize(
            width: 0,
            height: scrollView.contentSize.height
        )
        textView.maxSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )
        textView.autoresizingMask = [.width]
        textView.string = text
        textView.placeholder = placeholder
        textView.setAccessibilityPlaceholderValue(placeholder)

        scrollView.documentView = textView
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else {
            return
        }
        if textView.string != text {
            textView.string = text
        }
        guard wantsFocus,
              scrollView.window?.firstResponder !== textView
        else { return }
        DispatchQueue.main.async {
            scrollView.window?.makeFirstResponder(textView)
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        private var text: Binding<String>

        init(text: Binding<String>) {
            self.text = text
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else {
                return
            }
            text.wrappedValue = textView.string
            textView.needsDisplay = true
        }
    }
}

private final class PlaceholderTextView: NSTextView {
    var placeholder = ""

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if performEditingShortcut(for: event) {
            return true
        }
        return super.performKeyEquivalent(with: event)
    }

    override func keyDown(with event: NSEvent) {
        if performEditingShortcut(for: event) {
            return
        }
        super.keyDown(with: event)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard string.isEmpty, !placeholder.isEmpty else { return }

        let attributes: [NSAttributedString.Key: Any] = [
            .font: font ?? NSFont.systemFont(ofSize: 15),
            .foregroundColor: NSColor.secondaryLabelColor
                .withAlphaComponent(0.65)
        ]
        (placeholder as NSString).draw(
            at: textContainerOrigin,
            withAttributes: attributes
        )
    }

    private func performEditingShortcut(for event: NSEvent) -> Bool {
        let modifiers = event.modifierFlags.intersection(
            .deviceIndependentFlagsMask
        )
        let isControlOnlyShortcut = modifiers.contains(.control)
            && !modifiers.contains(.command)
        guard !(hasMarkedText() && isControlOnlyShortcut),
              !modifiers.contains(.option),
              let character = event.charactersIgnoringModifiers,
              let action = TextEditingShortcutPolicy.action(
                character: character,
                command: modifiers.contains(.command),
                control: modifiers.contains(.control)
              )
        else { return false }

        switch action {
        case .selectAll:
            selectAll(nil)
        case .copy:
            copy(nil)
        case .paste:
            paste(nil)
        }
        return true
    }
}
