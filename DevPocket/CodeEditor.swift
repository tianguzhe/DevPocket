import AppKit
import SwiftUI

// AppKit provides proper undo, selection, native shortcuts and efficient large text.
struct CodeEditor: NSViewRepresentable {
    @Binding var text: String
    var editable = true
    var label: String
    var json = false

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.hasHorizontalScroller = false
        scroll.drawsBackground = false
        scroll.borderType = .noBorder
        scroll.autohidesScrollers = true
        let editor = PlainTextView(frame: NSRect(x: 0, y: 0, width: 400, height: 400))
        editor.isRichText = false
        editor.isAutomaticQuoteSubstitutionEnabled = false
        editor.isAutomaticDashSubstitutionEnabled = false
        editor.isAutomaticTextReplacementEnabled = false
        editor.isAutomaticSpellingCorrectionEnabled = false
        editor.isContinuousSpellCheckingEnabled = false
        editor.allowsUndo = editable
        editor.isEditable = editable
        editor.isSelectable = true
        editor.drawsBackground = false
        editor.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        editor.textColor = .labelColor
        editor.insertionPointColor = .controlAccentColor
        editor.textContainerInset = NSSize(width: 14, height: 16)
        editor.isVerticallyResizable = true
        editor.isHorizontallyResizable = false
        editor.autoresizingMask = [.width]
        editor.textContainer?.widthTracksTextView = true
        editor.textContainer?.containerSize = NSSize(width: 400, height: CGFloat.greatestFiniteMagnitude)
        editor.delegate = context.coordinator
        editor.setAccessibilityLabel(label)
        scroll.documentView = editor
        editor.string = text
        editor.syntaxJSON = json
        editor.highlight()
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        context.coordinator.parent = self
        guard let editor = scroll.documentView as? NSTextView else { return }
        let textChanged = editor.string != text
        let syntaxChanged = (editor as? PlainTextView)?.syntaxJSON != json
        if textChanged {
            let selection = editor.selectedRange()
            editor.string = text
            editor.undoManager?.removeAllActions()
            let location = min(selection.location, (text as NSString).length)
            editor.setSelectedRange(NSRange(location: location, length: 0))
        }
        if let editor = editor as? PlainTextView, textChanged || syntaxChanged {
            editor.syntaxJSON = json
            editor.highlight()
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: CodeEditor
        init(_ parent: CodeEditor) { self.parent = parent }
        func textDidChange(_ notification: Notification) {
            guard let editor = notification.object as? NSTextView else { return }
            (editor as? PlainTextView)?.highlight()
            parent.text = editor.string
        }
    }
}

private final class PlainTextView: NSTextView {
    var syntaxJSON = false
    private static let tokens = try! NSRegularExpression(pattern:
        #""(?:\\.|[^"\\])*"|-?\b\d+(?:\.\d+)?(?:[eE][+-]?\d+)?|\b(?:true|false|null)\b"#)

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        highlight()
    }

    func highlight() {
        guard !hasMarkedText(), let storage = textStorage else { return }
        let source = string as NSString
        let full = NSRange(location: 0, length: source.length)
        storage.beginEditing()
        defer { storage.endEditing() }
        storage.addAttribute(.foregroundColor, value: NSColor.labelColor, range: full)
        // Keep editing fast for large documents; conversion still supports 5 MB.
        guard syntaxJSON, source.length <= 200_000 else { return }
        let dark = effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        let keyColor = dark ? NSColor(srgbRed: 0.42, green: 0.80, blue: 0.77, alpha: 1) : NSColor(srgbRed: 0.12, green: 0.43, blue: 0.44, alpha: 1)
        let stringColor = dark ? NSColor(srgbRed: 0.58, green: 0.81, blue: 0.63, alpha: 1) : NSColor(srgbRed: 0.16, green: 0.44, blue: 0.29, alpha: 1)
        let numberColor = dark ? NSColor(srgbRed: 0.96, green: 0.69, blue: 0.42, alpha: 1) : NSColor(srgbRed: 0.63, green: 0.34, blue: 0.12, alpha: 1)
        let literalColor = dark ? NSColor(srgbRed: 0.79, green: 0.64, blue: 0.94, alpha: 1) : NSColor(srgbRed: 0.51, green: 0.29, blue: 0.65, alpha: 1)
        for match in Self.tokens.matches(in: string, range: full) {
            let first = source.character(at: match.range.location)
            let tint: NSColor
            if first == 34 {
                var cursor = NSMaxRange(match.range)
                while cursor < source.length && [9, 10, 13, 32].contains(Int(source.character(at: cursor))) { cursor += 1 }
                tint = cursor < source.length && source.character(at: cursor) == 58 ? keyColor : stringColor
            } else if first == 116 || first == 102 || first == 110 {
                tint = literalColor
            } else {
                tint = numberColor
            }
            storage.addAttribute(.foregroundColor, value: tint, range: match.range)
        }
        typingAttributes = [.font: NSFont.monospacedSystemFont(ofSize: 13, weight: .regular), .foregroundColor: NSColor.labelColor]
    }

    override func insertTab(_ sender: Any?) {
        insertText("  ", replacementRange: selectedRange())
    }
}
