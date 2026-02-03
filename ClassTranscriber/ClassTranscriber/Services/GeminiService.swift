//
//  GeminiService.swift
//  ClassTranscriber
//
//  Created by Claude on 2026-02-03.
//

import Foundation

class GeminiService {

    static let shared = GeminiService()

    private let apiEndpoint = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent"

    private init() {}

    // MARK: - Error Types

    enum GeminiError: LocalizedError {
        case noAPIKey
        case invalidResponse
        case networkError(Error)
        case apiError(String)

        var errorDescription: String? {
            switch self {
            case .noAPIKey:
                return "Gemini API key not found. Please add your API key in Settings."
            case .invalidResponse:
                return "Invalid response from Gemini API."
            case .networkError(let error):
                return "Network error: \(error.localizedDescription)"
            case .apiError(let message):
                return "Gemini API error: \(message)"
            }
        }
    }

    // MARK: - Generate Class Notes

    func generateClassNotes(from transcript: String) async throws -> String {
        // Get API key from Keychain
        guard let apiKey = KeychainHelper.shared.getGeminiAPIKey(), !apiKey.isEmpty else {
            throw GeminiError.noAPIKey
        }

        // Construct the prompt
        let prompt = """
        You are an expert note-taker for college and high school students. Your task is to convert the following lecture transcription into comprehensive, well-organized class notes.

        Requirements:
        - Create clear, hierarchical notes with headers and subheaders
        - Capture ALL important concepts, definitions, and explanations (be thorough and lossless)
        - Include specific examples, numbers, and details mentioned
        - Identify and list any action items, assignments, or deadlines
        - Use bullet points and numbered lists for clarity
        - Highlight key terms and important concepts
        - Maintain the logical flow of the lecture
        - If formulas or equations are mentioned, include them clearly

        Format the notes with clear sections:

        **OVERVIEW**
        (Brief summary of the lecture topic)

        **KEY CONCEPTS**
        (Main ideas and definitions)

        **DETAILED NOTES**
        (Comprehensive notes organized by topic)

        **ACTION ITEMS**
        (Homework, assignments, things to do, or review)

        Here is the lecture transcription:

        \(transcript)
        """

        // Construct request body
        let requestBody: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        ["text": prompt]
                    ]
                ]
            ],
            "generationConfig": [
                "temperature": 0.3,
                "maxOutputTokens": 8192
            ]
        ]

        // Create URL with API key
        guard var urlComponents = URLComponents(string: apiEndpoint) else {
            throw GeminiError.invalidResponse
        }
        urlComponents.queryItems = [URLQueryItem(name: "key", value: apiKey)]

        guard let url = urlComponents.url else {
            throw GeminiError.invalidResponse
        }

        // Create request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        // Make the API call
        let (data, response) = try await URLSession.shared.data(for: request)

        // Check HTTP response
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GeminiError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            // Try to parse error message
            if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let error = errorJson["error"] as? [String: Any],
               let message = error["message"] as? String {
                throw GeminiError.apiError(message)
            }
            throw GeminiError.apiError("HTTP \(httpResponse.statusCode)")
        }

        // Parse response
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = json["candidates"] as? [[String: Any]],
              let firstCandidate = candidates.first,
              let content = firstCandidate["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]],
              let firstPart = parts.first,
              let text = firstPart["text"] as? String else {
            throw GeminiError.invalidResponse
        }

        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
