//
//  MarkdownNotesEditor.swift
//  Sponge
//
//  A rich text editor for markdown notes with live rendering, formatting toolbar, and keyboard shortcuts.
//

import SwiftUI
import AppKit

struct MarkdownNotesEditor: View {
    @Binding var text: String
    @Binding var noteTitle: String
    @State private var editorHeight: CGFloat = 220
    @State private var isDragging: Bool = false
    @FocusState private var isTitleFocused: Bool
    @FocusState private var isEditorFocused: Bool

    private let minHeight: CGFloat = 150
    private let maxHeight: CGFloat = 500

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with title and word count
            headerSection

            Divider()

            // Formatting toolbar
            formattingToolbar
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.secondary.opacity(0.03))

            Divider()

            // Notes text editor with live markdown rendering
            LiveMarkdownEditor(text: $text)
                .frame(height: editorHeight)

            // Resize handle
            resizeHandle
        }
        .background(Color.secondaryBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
        )
    }

    // MARK: - Header Section

    private var headerSection: some View {
        HStack(spacing: 12) {
            Image(systemName: "note.text")
                .font(.subheadline.weight(.medium))
                .foregroundColor(.secondary)

            // Editable title
            TextField("Note Title (optional)", text: $noteTitle)
                .textFieldStyle(.plain)
                .font(.subheadline.weight(.medium))
                .foregroundColor(.primary)
                .focused($isTitleFocused)

            Spacer()

            Text("\(wordCount) words")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(4)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.secondary.opacity(0.05))
    }

    // MARK: - Formatting Toolbar

    private var formattingToolbar: some View {
        HStack(spacing: 6) {
            // Heading buttons with labels
            FormatButtonWithLabel(label: "H1", tooltip: "Heading 1") {
                insertMarkdown(prefix: "# ", suffix: "")
            }

            FormatButtonWithLabel(label: "H2", tooltip: "Heading 2") {
                insertMarkdown(prefix: "## ", suffix: "")
            }

            FormatButtonWithLabel(label: "H3", tooltip: "Heading 3") {
                insertMarkdown(prefix: "### ", suffix: "")
            }

            Divider()
                .frame(height: 20)
                .padding(.horizontal, 4)

            // Text formatting with icons
            FormatButton(icon: "bold", tooltip: "Bold (Cmd+B)") {
                insertMarkdown(prefix: "**", suffix: "**")
            }

            FormatButton(icon: "italic", tooltip: "Italic (Cmd+I)") {
                insertMarkdown(prefix: "_", suffix: "_")
            }

            Divider()
                .frame(height: 20)
                .padding(.horizontal, 4)

            // List buttons
            FormatButton(icon: "list.bullet", tooltip: "Bullet List") {
                insertMarkdown(prefix: "- ", suffix: "", isLinePrefix: true)
            }

            FormatButton(icon: "list.number", tooltip: "Numbered List") {
                insertMarkdown(prefix: "1. ", suffix: "", isLinePrefix: true)
            }

            Spacer()

            // Keyboard hints
            Text("Cmd+B bold, Cmd+I italic")
                .font(.caption2)
                .foregroundColor(.secondary.opacity(0.6))
        }
    }

    // MARK: - Resize Handle

    private var resizeHandle: some View {
        HStack {
            Spacer()

            Rectangle()
                .fill(Color.secondary.opacity(isDragging ? 0.4 : 0.2))
                .frame(width: 40, height: 4)
                .cornerRadius(2)

            Spacer()
        }
        .frame(height: 16)
        .background(Color.secondary.opacity(0.03))
        .contentShape(Rectangle())
        .gesture(
            DragGesture()
                .onChanged { value in
                    isDragging = true
                    let newHeight = editorHeight + value.translation.height
                    editorHeight = min(max(newHeight, minHeight), maxHeight)
                }
                .onEnded { _ in
                    isDragging = false
                }
        )
        .onHover { hovering in
            if hovering {
                NSCursor.resizeUpDown.push()
            } else {
                NSCursor.pop()
            }
        }
    }

    private var placeholderText: some View {
        Text("Start typing your notes... Use **bold** or _italic_ markdown syntax.")
            .font(.body)
            .foregroundColor(.secondary.opacity(0.5))
            .padding(.horizontal, 16)
            .padding(.vertical, 20)
            .allowsHitTesting(false)
    }

    // MARK: - Computed Properties

    private var wordCount: Int {
        text.split(separator: " ").count
    }

    // MARK: - Formatting Actions

    private func insertMarkdown(prefix: String, suffix: String, isLinePrefix: Bool = false) {
        // Post notification to the text editor
        NotificationCenter.default.post(
            name: .insertMarkdown,
            object: nil,
            userInfo: ["prefix": prefix, "suffix": suffix, "isLinePrefix": isLinePrefix]
        )
    }
}

// MARK: - Notification Extension

extension Notification.Name {
    static let insertMarkdown = Notification.Name("insertMarkdown")
}

// MARK: - Format Button with Label

struct FormatButtonWithLabel: View {
    let label: String
    let tooltip: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(.primary.opacity(0.7))
                .frame(width: 28, height: 28)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(6)
        }
        .buttonStyle(.plain)
        .help(tooltip)
    }
}

// MARK: - Format Button with Icon

struct FormatButton: View {
    let icon: String
    let tooltip: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.primary.opacity(0.7))
                .frame(width: 28, height: 28)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(6)
        }
        .buttonStyle(.plain)
        .help(tooltip)
    }
}

// MARK: - Live Markdown Editor

// Custom NSTextView that handles keyboard shortcuts
class MarkdownTextView: NSTextView {
    var onBold: (() -> Void)?
    var onItalic: (() -> Void)?
    var onEnterPressed: ((String) -> String?)?  // Returns prefix to insert, or nil

    override func keyDown(with event: NSEvent) {
        // Check for Cmd+B (bold)
        if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "b" {
            onBold?()
            return
        }

        // Check for Cmd+I (italic)
        if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "i" {
            onItalic?()
            return
        }

        // Check for Enter/Return key
        if event.keyCode == 36 || event.keyCode == 76 { // Return or Enter
            if let currentLine = getCurrentLine(), let prefix = onEnterPressed?(currentLine) {
                // Insert newline + prefix
                insertText("\n\(prefix)", replacementRange: selectedRange())
                return
            }
        }

        super.keyDown(with: event)
    }

    private func getCurrentLine() -> String? {
        let text = string as NSString
        let cursorLocation = selectedRange().location

        // Find start of current line
        var lineStart = cursorLocation
        while lineStart > 0 && text.character(at: lineStart - 1) != 10 { // newline
            lineStart -= 1
        }

        // Find end of current line
        var lineEnd = cursorLocation
        while lineEnd < text.length && text.character(at: lineEnd) != 10 {
            lineEnd += 1
        }

        let lineRange = NSRange(location: lineStart, length: lineEnd - lineStart)
        return text.substring(with: lineRange)
    }
}

struct LiveMarkdownEditor: NSViewRepresentable {
    @Binding var text: String

    func makeNSView(context: Context) -> NSScrollView {
        // Create custom text view
        let textView = MarkdownTextView()
        textView.autoresizingMask = [.width, .height]
        textView.delegate = context.coordinator
        textView.isRichText = true
        textView.allowsUndo = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.backgroundColor = .clear
        textView.drawsBackground = false

        // Set up text container for proper wrapping
        let textContainer = NSTextContainer()
        textContainer.widthTracksTextView = true
        textContainer.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)

        let layoutManager = NSLayoutManager()
        layoutManager.addTextContainer(textContainer)

        let textStorage = NSTextStorage()
        textStorage.addLayoutManager(layoutManager)

        textView.textContainer?.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true

        // Insets
        textView.textContainerInset = NSSize(width: 12, height: 12)

        // Set up keyboard handlers
        let coordinator = context.coordinator
        textView.onBold = { [weak coordinator] in
            coordinator?.toggleBold()
        }
        textView.onItalic = { [weak coordinator] in
            coordinator?.toggleItalic()
        }
        textView.onEnterPressed = { [weak coordinator] currentLine in
            return coordinator?.getListContinuation(for: currentLine)
        }

        // Create scroll view
        let scrollView = NSScrollView()
        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false

        // Store reference for notifications
        context.coordinator.textView = textView

        // Apply initial styling
        context.coordinator.applyMarkdownStyling(to: textView)

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }

        // Only update if text changed externally
        let plainText = context.coordinator.getPlainText(from: textView)
        if plainText != text {
            let selectedRanges = textView.selectedRanges
            textView.string = text
            context.coordinator.applyMarkdownStyling(to: textView)

            // Restore selection if valid
            if let firstRange = selectedRanges.first?.rangeValue,
               firstRange.location <= textView.string.count {
                textView.setSelectedRange(firstRange)
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: LiveMarkdownEditor
        weak var textView: NSTextView?
        private var isUpdating = false
        private var notificationObserver: Any?

        init(_ parent: LiveMarkdownEditor) {
            self.parent = parent
            super.init()

            // Listen for markdown insert notifications
            notificationObserver = NotificationCenter.default.addObserver(
                forName: .insertMarkdown,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                self?.handleInsertMarkdown(notification)
            }
        }

        deinit {
            if let observer = notificationObserver {
                NotificationCenter.default.removeObserver(observer)
            }
        }

        private func handleInsertMarkdown(_ notification: Notification) {
            guard let textView = textView,
                  let userInfo = notification.userInfo,
                  let prefix = userInfo["prefix"] as? String,
                  let suffix = userInfo["suffix"] as? String,
                  let isLinePrefix = userInfo["isLinePrefix"] as? Bool else { return }

            let selectedRange = textView.selectedRange()
            let text = textView.string as NSString

            if isLinePrefix {
                // Insert at beginning of line
                var lineStart = selectedRange.location
                while lineStart > 0 && text.character(at: lineStart - 1) != 10 { // newline
                    lineStart -= 1
                }

                // Check if we need a newline first
                if lineStart == selectedRange.location && lineStart > 0 {
                    textView.insertText("\n\(prefix)", replacementRange: selectedRange)
                } else {
                    textView.insertText(prefix, replacementRange: NSRange(location: lineStart, length: 0))
                }
            } else if selectedRange.length > 0 {
                // Wrap selected text
                let selectedText = text.substring(with: selectedRange)
                let replacement = "\(prefix)\(selectedText)\(suffix)"
                textView.insertText(replacement, replacementRange: selectedRange)
            } else {
                // Insert markers at cursor
                textView.insertText("\(prefix)\(suffix)", replacementRange: selectedRange)
                // Move cursor between markers
                let newLocation = selectedRange.location + prefix.count
                textView.setSelectedRange(NSRange(location: newLocation, length: 0))
            }
        }

        // MARK: - Keyboard Shortcut Handlers

        func toggleBold() {
            guard let textView = textView else { return }
            let selectedRange = textView.selectedRange()
            let text = textView.string as NSString

            if selectedRange.length > 0 {
                // Wrap selected text with **
                let selectedText = text.substring(with: selectedRange)
                let replacement = "**\(selectedText)**"
                textView.insertText(replacement, replacementRange: selectedRange)
            } else {
                // Insert ** ** and place cursor in middle
                textView.insertText("****", replacementRange: selectedRange)
                textView.setSelectedRange(NSRange(location: selectedRange.location + 2, length: 0))
            }
        }

        func toggleItalic() {
            guard let textView = textView else { return }
            let selectedRange = textView.selectedRange()
            let text = textView.string as NSString

            if selectedRange.length > 0 {
                // Wrap selected text with _
                let selectedText = text.substring(with: selectedRange)
                let replacement = "_\(selectedText)_"
                textView.insertText(replacement, replacementRange: selectedRange)
            } else {
                // Insert __ and place cursor in middle
                textView.insertText("__", replacementRange: selectedRange)
                textView.setSelectedRange(NSRange(location: selectedRange.location + 1, length: 0))
            }
        }

        func getListContinuation(for line: String) -> String? {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)

            // Check for bullet points (- or *)
            if trimmedLine.hasPrefix("- ") {
                // If line is just "- " (empty bullet), don't continue
                if trimmedLine == "- " || trimmedLine == "-" {
                    return nil
                }
                return "- "
            }
            if trimmedLine.hasPrefix("* ") {
                if trimmedLine == "* " || trimmedLine == "*" {
                    return nil
                }
                return "* "
            }

            // Check for numbered lists
            if let match = trimmedLine.range(of: "^(\\d+)\\. ", options: .regularExpression) {
                let numberStr = String(trimmedLine[trimmedLine.startIndex..<match.upperBound])
                    .trimmingCharacters(in: CharacterSet(charactersIn: ". "))

                // If line is just "1. " (empty numbered item), don't continue
                let content = String(trimmedLine[match.upperBound...])
                if content.isEmpty {
                    return nil
                }

                if let number = Int(numberStr) {
                    return "\(number + 1). "
                }
            }

            return nil
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            guard !isUpdating else { return }

            isUpdating = true

            // Update the plain text binding
            parent.text = textView.string

            // Apply markdown styling
            applyMarkdownStyling(to: textView)

            isUpdating = false
        }

        func getPlainText(from textView: NSTextView) -> String {
            return textView.string
        }

        func applyMarkdownStyling(to textView: NSTextView) {
            guard let textStorage = textView.textStorage else { return }

            let fullRange = NSRange(location: 0, length: textStorage.length)
            let text = textStorage.string

            // Base attributes
            let baseFont = NSFont.systemFont(ofSize: 14)
            let baseColor = NSColor.labelColor

            // Hidden marker attributes - make markers invisible
            let hiddenFont = NSFont.systemFont(ofSize: 0.1)
            let hiddenColor = NSColor.clear

            let baseParagraphStyle = NSMutableParagraphStyle()
            baseParagraphStyle.lineSpacing = 4

            // Reset to base style
            textStorage.beginEditing()
            textStorage.setAttributes([
                .font: baseFont,
                .foregroundColor: baseColor,
                .paragraphStyle: baseParagraphStyle
            ], range: fullRange)

            let lines = text.components(separatedBy: "\n")
            var currentLocation = 0

            for line in lines {
                let lineRange = NSRange(location: currentLocation, length: line.count)

                // Check for headings
                if line.hasPrefix("### ") {
                    // Apply header font to content only (after marker)
                    let headerFont = NSFont.systemFont(ofSize: 15, weight: .semibold)
                    if line.count > 4 {
                        let contentRange = NSRange(location: currentLocation + 4, length: line.count - 4)
                        textStorage.addAttribute(.font, value: headerFont, range: contentRange)
                    }
                    // Hide the ### markers
                    let markerRange = NSRange(location: currentLocation, length: 4)
                    hideMarker(in: textStorage, range: markerRange, hiddenFont: hiddenFont, hiddenColor: hiddenColor)
                } else if line.hasPrefix("## ") {
                    // Apply header font to content only
                    let headerFont = NSFont.systemFont(ofSize: 17, weight: .semibold)
                    if line.count > 3 {
                        let contentRange = NSRange(location: currentLocation + 3, length: line.count - 3)
                        textStorage.addAttribute(.font, value: headerFont, range: contentRange)
                    }
                    // Hide the ## markers
                    let markerRange = NSRange(location: currentLocation, length: 3)
                    hideMarker(in: textStorage, range: markerRange, hiddenFont: hiddenFont, hiddenColor: hiddenColor)
                } else if line.hasPrefix("# ") {
                    // Apply header font to content only
                    let headerFont = NSFont.systemFont(ofSize: 20, weight: .bold)
                    if line.count > 2 {
                        let contentRange = NSRange(location: currentLocation + 2, length: line.count - 2)
                        textStorage.addAttribute(.font, value: headerFont, range: contentRange)
                    }
                    // Hide the # marker
                    let markerRange = NSRange(location: currentLocation, length: 2)
                    hideMarker(in: textStorage, range: markerRange, hiddenFont: hiddenFont, hiddenColor: hiddenColor)
                } else if line.hasPrefix("- ") || line.hasPrefix("* ") {
                    // Replace bullet marker with actual bullet character visually
                    // Keep marker but style it as a bullet
                    let markerRange = NSRange(location: currentLocation, length: 1)
                    textStorage.addAttribute(.foregroundColor, value: NSColor.secondaryLabelColor, range: markerRange)
                } else if let match = line.range(of: "^\\d+\\. ", options: .regularExpression) {
                    // Keep numbered list markers visible but slightly dimmed
                    let markerLength = line.distance(from: line.startIndex, to: match.upperBound)
                    let markerRange = NSRange(location: currentLocation, length: markerLength)
                    textStorage.addAttribute(.foregroundColor, value: NSColor.secondaryLabelColor, range: markerRange)
                }

                // Apply inline formatting (bold and italic)
                applyInlineFormatting(to: textStorage, in: line, startingAt: currentLocation, baseFont: baseFont, hiddenFont: hiddenFont, hiddenColor: hiddenColor)

                currentLocation += line.count + 1 // +1 for newline
            }

            textStorage.endEditing()
        }

        private func hideMarker(in textStorage: NSTextStorage, range: NSRange, hiddenFont: NSFont, hiddenColor: NSColor) {
            textStorage.addAttribute(.font, value: hiddenFont, range: range)
            textStorage.addAttribute(.foregroundColor, value: hiddenColor, range: range)
        }

        private func applyInlineFormatting(to textStorage: NSTextStorage, in line: String, startingAt offset: Int, baseFont: NSFont, hiddenFont: NSFont, hiddenColor: NSColor) {
            // Bold: **text** or __text__
            let boldPattern = "(\\*\\*|__)(.+?)\\1"
            if let boldRegex = try? NSRegularExpression(pattern: boldPattern) {
                let matches = boldRegex.matches(in: line, range: NSRange(location: 0, length: line.count))
                for match in matches {
                    let contentRange = match.range(at: 2)
                    let contentNSRange = NSRange(location: offset + contentRange.location, length: contentRange.length)

                    // Make content bold
                    let boldFont = NSFont.boldSystemFont(ofSize: baseFont.pointSize)
                    textStorage.addAttribute(.font, value: boldFont, range: contentNSRange)

                    // Hide the markers completely
                    let markerLength = 2
                    let startMarker = NSRange(location: offset + match.range.location, length: markerLength)
                    let endMarker = NSRange(location: offset + match.range.location + match.range.length - markerLength, length: markerLength)
                    hideMarker(in: textStorage, range: startMarker, hiddenFont: hiddenFont, hiddenColor: hiddenColor)
                    hideMarker(in: textStorage, range: endMarker, hiddenFont: hiddenFont, hiddenColor: hiddenColor)
                }
            }

            // Italic: *text* or _text_ (but not ** or __)
            let italicPattern = "(?<![\\*_])([\\*_])(?![\\*_])(.+?)(?<![\\*_])\\1(?![\\*_])"
            if let italicRegex = try? NSRegularExpression(pattern: italicPattern) {
                let matches = italicRegex.matches(in: line, range: NSRange(location: 0, length: line.count))
                for match in matches {
                    let contentRange = match.range(at: 2)
                    let contentNSRange = NSRange(location: offset + contentRange.location, length: contentRange.length)

                    // Make content italic
                    let italicFont = NSFontManager.shared.font(
                        withFamily: baseFont.familyName ?? "System Font",
                        traits: .italicFontMask,
                        weight: 5,
                        size: baseFont.pointSize
                    ) ?? NSFont.systemFont(ofSize: baseFont.pointSize)
                    textStorage.addAttribute(.font, value: italicFont, range: contentNSRange)

                    // Hide the markers completely
                    let startMarker = NSRange(location: offset + match.range.location, length: 1)
                    let endMarker = NSRange(location: offset + match.range.location + match.range.length - 1, length: 1)
                    hideMarker(in: textStorage, range: startMarker, hiddenFont: hiddenFont, hiddenColor: hiddenColor)
                    hideMarker(in: textStorage, range: endMarker, hiddenFont: hiddenFont, hiddenColor: hiddenColor)
                }
            }
        }
    }
}

#Preview {
    MarkdownNotesEditor(text: .constant("# Heading 1\n\nSome **bold** and _italic_ text.\n\n## Heading 2\n\n- Bullet point\n- Another point\n\n1. Numbered\n2. List"), noteTitle: .constant("My Notes"))
        .frame(width: 500)
        .padding()
}
