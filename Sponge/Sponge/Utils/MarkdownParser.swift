//
//  MarkdownParser.swift
//  Sponge
//
//  Created by Claude on 2026-02-03.
//

import Foundation
import CoreText
import CoreGraphics
#if os(macOS)
import AppKit
#else
import UIKit
#endif

class MarkdownParser {

    static func parseMarkdown(_ markdown: String, baseFont: CTFont, baseColor: CGColor) -> NSAttributedString {
        let result = NSMutableAttributedString()

        let lines = markdown.components(separatedBy: .newlines)

        for line in lines {
            let attributedLine = parseLine(line, baseFont: baseFont, baseColor: baseColor)
            result.append(attributedLine)
            result.append(NSAttributedString(string: "\n"))
        }

        return result
    }

    private static func parseLine(_ line: String, baseFont: CTFont, baseColor: CGColor) -> NSAttributedString {
        let trimmed = line.trimmingCharacters(in: .whitespaces)

        // Check for headers (## Header)
        if trimmed.hasPrefix("##") {
            let headerText = trimmed.replacingOccurrences(of: "^##\\s*", with: "", options: .regularExpression)
            let headerFont = CTFontCreateWithName("Helvetica-Bold" as CFString, 14, nil)
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.paragraphSpacing = 8
            paragraphStyle.paragraphSpacingBefore = 12

            return NSAttributedString(string: headerText, attributes: [
                .font: headerFont,
                .foregroundColor: baseColor,
                .paragraphStyle: paragraphStyle
            ])
        }

        // Check for subheaders (### Header)
        if trimmed.hasPrefix("###") {
            let headerText = trimmed.replacingOccurrences(of: "^###\\s*", with: "", options: .regularExpression)
            let headerFont = CTFontCreateWithName("Helvetica-Bold" as CFString, 12, nil)
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.paragraphSpacing = 6
            paragraphStyle.paragraphSpacingBefore = 8

            return NSAttributedString(string: headerText, attributes: [
                .font: headerFont,
                .foregroundColor: baseColor,
                .paragraphStyle: paragraphStyle
            ])
        }

        // Check for bullet points (- item or * item)
        // Must have space after the marker to be considered a bullet point
        if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") {
            let bulletText = trimmed.replacingOccurrences(of: "^[-*]\\s+", with: "", options: .regularExpression)
            let result = NSMutableAttributedString(string: "• ", attributes: [
                .font: baseFont,
                .foregroundColor: baseColor
            ])
            result.append(parseInlineFormatting(bulletText, baseFont: baseFont, baseColor: baseColor))

            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.firstLineHeadIndent = 0
            paragraphStyle.headIndent = 15
            paragraphStyle.lineSpacing = 3
            result.addAttribute(.paragraphStyle, value: paragraphStyle, range: NSRange(location: 0, length: result.length))

            return result
        }

        // Check for numbered lists (1. item, 2. item, etc.)
        if let match = trimmed.range(of: "^(\\d+)\\.\\s+", options: .regularExpression) {
            let number = String(trimmed[match])
            let itemText = String(trimmed[match.upperBound...])

            let result = NSMutableAttributedString(string: number, attributes: [
                .font: baseFont,
                .foregroundColor: baseColor
            ])
            result.append(parseInlineFormatting(itemText, baseFont: baseFont, baseColor: baseColor))

            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.firstLineHeadIndent = 0
            paragraphStyle.headIndent = 20
            paragraphStyle.lineSpacing = 3
            result.addAttribute(.paragraphStyle, value: paragraphStyle, range: NSRange(location: 0, length: result.length))

            return result
        }

        // Regular paragraph with inline formatting
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 4
        paragraphStyle.paragraphSpacing = 6

        let result = parseInlineFormatting(line, baseFont: baseFont, baseColor: baseColor)
        result.addAttribute(.paragraphStyle, value: paragraphStyle, range: NSRange(location: 0, length: result.length))

        return result
    }

    private static func parseInlineFormatting(_ text: String, baseFont: CTFont, baseColor: CGColor) -> NSMutableAttributedString {
        let result = NSMutableAttributedString()

        // Pattern to match bold text: **text** or __text__
        let boldPattern = "(\\*\\*|__)(.*?)\\1"

        var currentIndex = text.startIndex
        let nsString = text as NSString
        let regex = try? NSRegularExpression(pattern: boldPattern, options: [])

        let matches = regex?.matches(in: text, options: [], range: NSRange(location: 0, length: nsString.length)) ?? []

        for match in matches {
            let matchRange = match.range
            let matchStartIndex = text.index(text.startIndex, offsetBy: matchRange.location)
            let matchEndIndex = text.index(text.startIndex, offsetBy: matchRange.location + matchRange.length)

            // Add text before the match
            if currentIndex < matchStartIndex {
                let beforeText = String(text[currentIndex..<matchStartIndex])
                result.append(NSAttributedString(string: beforeText, attributes: [
                    .font: baseFont,
                    .foregroundColor: baseColor
                ]))
            }

            // Add bold text (extract content from capture group 2)
            if match.numberOfRanges >= 3 {
                let contentRange = match.range(at: 2)
                let content = nsString.substring(with: contentRange)
                let boldFont = CTFontCreateWithName("Helvetica-Bold" as CFString, CTFontGetSize(baseFont), nil)
                result.append(NSAttributedString(string: content, attributes: [
                    .font: boldFont,
                    .foregroundColor: baseColor
                ]))
            }

            currentIndex = matchEndIndex
        }

        // Add remaining text after last match
        if currentIndex < text.endIndex {
            let remainingText = String(text[currentIndex...])
            result.append(NSAttributedString(string: remainingText, attributes: [
                .font: baseFont,
                .foregroundColor: baseColor
            ]))
        }

        return result
    }
}
