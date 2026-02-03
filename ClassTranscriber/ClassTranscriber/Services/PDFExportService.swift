import Foundation
import CoreGraphics
import CoreText
#if os(macOS)
import AppKit
#else
import UIKit
#endif

class PDFExportService {
    static func generatePDF(
        className: String,
        date: Date,
        duration: TimeInterval,
        transcriptText: String,
        classNotes: String? = nil
    ) -> Data? {
        let pageWidth: CGFloat = 612  // US Letter width in points
        let pageHeight: CGFloat = 792 // US Letter height in points
        let margin: CGFloat = 50

        let pdfMetaData: [CFString: Any] = [
            kCGPDFContextCreator: "Class Transcriber",
            kCGPDFContextAuthor: "Class Transcriber App",
            kCGPDFContextTitle: "\(className) - Transcript"
        ]

        let data = NSMutableData()
        var mediaBox = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)

        guard let consumer = CGDataConsumer(data: data as CFMutableData),
              let context = CGContext(consumer: consumer, mediaBox: &mediaBox, pdfMetaData as CFDictionary) else {
            return nil
        }

        // Helper to begin a new page
        func beginPage() {
            let box = mediaBox
            context.beginPDFPage([kCGPDFContextMediaBox: NSValue(rect: box)] as CFDictionary)
        }

        // Start first page
        beginPage()

        // Draw title
        let titleFont = CTFontCreateWithName("Helvetica-Bold" as CFString, 24, nil)
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: titleFont,
            .foregroundColor: cgColor(black: true)
        ]
        let titleString = NSAttributedString(string: className, attributes: titleAttributes)
        drawText(titleString, in: context, at: CGPoint(x: margin, y: pageHeight - margin - 24), maxWidth: pageWidth - margin * 2)

        // Draw metadata
        let metaFont = CTFontCreateWithName("Helvetica" as CFString, 12, nil)
        let metaAttributes: [NSAttributedString.Key: Any] = [
            .font: metaFont,
            .foregroundColor: cgColor(black: false)
        ]

        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .long
        dateFormatter.timeStyle = .short

        let durationString = formatDuration(duration)
        let metaText = "Date: \(dateFormatter.string(from: date))\nDuration: \(durationString)"
        let metaString = NSAttributedString(string: metaText, attributes: metaAttributes)
        drawText(metaString, in: context, at: CGPoint(x: margin, y: pageHeight - margin - 50), maxWidth: pageWidth - margin * 2)

        // Draw separator line
        let separatorY = pageHeight - margin - 90
        context.setStrokeColor(CGColor(gray: 0.7, alpha: 1.0))
        context.setLineWidth(1)
        context.move(to: CGPoint(x: margin, y: separatorY))
        context.addLine(to: CGPoint(x: pageWidth - margin, y: separatorY))
        context.strokePath()

        // Prepare text attributes
        let bodyFont = CTFontCreateWithName("Helvetica" as CFString, 11, nil)
        let sectionHeaderFont = CTFontCreateWithName("Helvetica-Bold" as CFString, 14, nil)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 4
        paragraphStyle.paragraphSpacing = 8

        let bodyAttributes: [NSAttributedString.Key: Any] = [
            .font: bodyFont,
            .foregroundColor: cgColor(black: true),
            .paragraphStyle: paragraphStyle
        ]

        let headerAttributes: [NSAttributedString.Key: Any] = [
            .font: sectionHeaderFont,
            .foregroundColor: cgColor(black: true)
        ]

        // Build the full content with class notes (if available) and transcript
        let fullContent = NSMutableAttributedString()

        // Add class notes section if available
        if let classNotes = classNotes, !classNotes.isEmpty {
            let notesHeader = NSAttributedString(string: "CLASS NOTES\n\n", attributes: headerAttributes)
            fullContent.append(notesHeader)

            let notesContent = NSAttributedString(string: classNotes + "\n\n\n", attributes: bodyAttributes)
            fullContent.append(notesContent)

            // Add separator before transcript
            let transcriptHeader = NSAttributedString(string: "FULL TRANSCRIPTION\n\n", attributes: headerAttributes)
            fullContent.append(transcriptHeader)
        }

        // Add transcript content
        let transcriptContent = NSAttributedString(string: transcriptText, attributes: bodyAttributes)
        fullContent.append(transcriptContent)

        let framesetter = CTFramesetterCreateWithAttributedString(fullContent)

        var currentY = separatorY - 20
        let contentWidth = pageWidth - margin * 2
        var startIndex = 0
        let textLength = fullContent.length
        var isFirstPage = true

        while startIndex < textLength {
            if !isFirstPage {
                context.endPDFPage()
                beginPage()
                currentY = pageHeight - margin
            }
            isFirstPage = false

            let availableHeight = currentY - margin
            let framePath = CGPath(rect: CGRect(x: margin, y: margin, width: contentWidth, height: availableHeight), transform: nil)

            let frame = CTFramesetterCreateFrame(framesetter, CFRangeMake(startIndex, 0), framePath, nil)
            CTFrameDraw(frame, context)

            let visibleRange = CTFrameGetVisibleStringRange(frame)
            if visibleRange.length == 0 {
                break
            }
            startIndex += visibleRange.length
        }

        context.endPDFPage()
        context.closePDF()

        return data as Data
    }

    private static func drawText(_ attributedString: NSAttributedString, in context: CGContext, at point: CGPoint, maxWidth: CGFloat) {
        let line = CTLineCreateWithAttributedString(attributedString)
        context.textPosition = point
        CTLineDraw(line, context)
    }

    private static func cgColor(black: Bool) -> CGColor {
        return black ? CGColor(gray: 0, alpha: 1) : CGColor(gray: 0.4, alpha: 1)
    }

    static func savePDF(data: Data, to folderURL: URL, fileName: String) -> Bool {
        let accessed = folderURL.startAccessingSecurityScopedResource()
        defer {
            if accessed {
                folderURL.stopAccessingSecurityScopedResource()
            }
        }

        let fileURL = folderURL.appendingPathComponent(fileName).appendingPathExtension("pdf")

        do {
            try data.write(to: fileURL)
            return true
        } catch {
            print("Failed to save PDF: \(error)")
            return false
        }
    }

    private static func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        let seconds = Int(duration) % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
}
