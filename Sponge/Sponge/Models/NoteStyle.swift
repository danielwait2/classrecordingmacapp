//
//  NoteStyle.swift
//  Sponge
//
//  Created by Claude on 2026-02-03.
//

import Foundation

enum NoteStyle: String, CaseIterable, Identifiable {
    case detailed = "Detailed"
    case concise = "Concise"
    case bulletPoints = "Bullet Points"
    case studyGuide = "Study Guide"
    case cornell = "Cornell Notes"
    case outline = "Outline"

    var id: String { rawValue }

    var description: String {
        switch self {
        case .detailed:
            return "Comprehensive notes with full explanations and context"
        case .concise:
            return "Brief summaries focusing on key points only"
        case .bulletPoints:
            return "Organized bullet-point lists of main ideas"
        case .studyGuide:
            return "Study-focused format with questions and key concepts"
        case .cornell:
            return "Cornell note-taking system with cues, notes, and summary"
        case .outline:
            return "Hierarchical outline structure with main topics and subtopics"
        }
    }

    var promptModifier: String {
        switch self {
        case .detailed:
            return """
            Format: Comprehensive and detailed notes
            - Provide thorough explanations for each concept
            - Include context and background information
            - Add examples and elaborations
            - Use full sentences and paragraphs
            """
        case .concise:
            return """
            Format: Brief and concise notes
            - Focus only on essential information
            - Use short, direct statements
            - Eliminate redundant details
            - Keep each point under 2 sentences
            """
        case .bulletPoints:
            return """
            Format: Bullet-point organization
            - Use bullet points for all content
            - Group related ideas under main topics
            - Keep bullets clear and scannable
            - Use sub-bullets for supporting details
            """
        case .studyGuide:
            return """
            Format: Study guide structure
            - Include key concepts with definitions
            - Add practice questions for each topic
            - Highlight must-know information
            - Include memory aids and mnemonics
            - End with a summary of critical points
            """
        case .cornell:
            return """
            Format: Cornell Notes system
            Structure your notes in three sections:

            ## CUE COLUMN (Questions & Keywords)
            [List key questions and terms here]

            ## NOTES COLUMN (Main Ideas & Details)
            [Main lecture content with detailed notes]

            ## SUMMARY SECTION
            [Brief summary of the entire lecture in 3-5 sentences]
            """
        case .outline:
            return """
            Format: Hierarchical outline
            - Use numbered or lettered outline structure (I, A, 1, a)
            - Main topics as top-level items
            - Subtopics indented below
            - Supporting details further indented
            - Maintain clear hierarchy
            """
        }
    }
}

enum SummaryLength: String, CaseIterable, Identifiable {
    case quick = "Quick"
    case medium = "Medium"
    case comprehensive = "Comprehensive"

    var id: String { rawValue }

    var description: String {
        switch self {
        case .quick:
            return "Fast overview (1-2 paragraphs)"
        case .medium:
            return "Balanced detail (3-5 paragraphs)"
        case .comprehensive:
            return "In-depth coverage (full detail)"
        }
    }

    var promptModifier: String {
        switch self {
        case .quick:
            return """
            Length: Quick summary
            - Limit to 1-2 short paragraphs for overview
            - Focus only on the most critical 3-5 points
            - Keep total output under 200 words
            """
        case .medium:
            return """
            Length: Medium detail
            - Provide 3-5 well-developed paragraphs
            - Cover all major topics but keep explanations moderate
            - Target approximately 300-500 words
            """
        case .comprehensive:
            return """
            Length: Comprehensive and thorough
            - Include all important details and context
            - Provide full explanations for each concept
            - Don't limit word count - be as thorough as needed
            - Include examples, context, and supporting information
            """
        }
    }
}
