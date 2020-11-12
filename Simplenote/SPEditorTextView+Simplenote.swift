import Foundation

// MARK: - SPEditorTextView
//
extension SPEditorTextView {

    /// Text with attachments converted to markdown
    @objc
    var plainText: String {
        return NSAttributedStringToMarkdownConverter.convert(string: attributedText)
    }

    /// Selected text with attachments converted to markdown
    var plainSelectedText: String? {
        guard selectedRange.location != NSNotFound else {
            return nil
        }

        let selectedAttributedText = attributedText.attributedSubstring(from: selectedRange)
        return NSAttributedStringToMarkdownConverter.convert(string: selectedAttributedText)
    }

    open override func copy(_ sender: Any?) {
        UIPasteboard.general.string = plainSelectedText
    }

    open override func cut(_ sender: Any?) {
        let text = plainSelectedText
        super.cut(sender)
        UIPasteboard.general.string = text
    }
}

extension SPEditorTextView {
    /// Bounding rect for a character range
    ///
    func boundingRectForCharacterRange(_ range: NSRange) -> CGRect {
        let glyphRange = layoutManager.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
        return layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
    }
}
